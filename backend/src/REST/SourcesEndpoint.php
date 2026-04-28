<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\SourceTransformer;

/**
 * Endpoints de medios (fuentes):
 *  GET /sources
 *  GET /sources/{id}
 *
 * Devuelve la ficha editorial completa: quién posee el medio, cómo se
 * financia, línea editorial declarada, territorio e idiomas.
 */
final class SourcesEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/sources', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'listar'],
                'permission_callback' => '__return_true',
                'args'                => [
                    'page'      => ['type' => 'integer', 'default' => 1, 'minimum' => 1],
                    'per_page'  => ['type' => 'integer', 'default' => 50, 'minimum' => 1, 'maximum' => 100],
                    'topic'     => ['type' => 'string'],
                    'territory' => ['type' => 'string'],
                    'language'  => ['type' => 'string'],
                    's'         => ['type' => 'string', 'description' => 'Búsqueda por texto libre.'],
                    'ids'       => ['type' => 'string', 'description' => 'Lista CSV de IDs para fetch batch (evita N+1 desde el cliente).'],
                ],
            ],
        ]);

        register_rest_route(RestController::NAMESPACE_REST, '/sources/(?P<id>\d+)', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'obtener'],
                'permission_callback' => '__return_true',
                'args'                => [
                    'id' => [
                        'type'              => 'integer',
                        'required'          => true,
                        'sanitize_callback' => 'absint',
                    ],
                ],
            ],
        ]);
    }

    public static function listar(\WP_REST_Request $request): \WP_REST_Response
    {
        $pagina = max(1, (int) $request->get_param('page'));
        $porPagina = min(100, max(1, (int) $request->get_param('per_page')));

        // Fetch batch por IDs explícitos: caso de uso típico es la
        // ficha de colectivo, que tiene una lista de sourceIds y
        // antes hacía N peticiones GET /sources/{id} en paralelo.
        // Devolvemos exactamente la selección, saltándonos filtros
        // de territorio/idioma/topic — el cliente ya ha decidido qué
        // quiere ver. Mantenemos el filtro de "activos" por
        // coherencia con la semántica del endpoint singular.
        $csvIds = trim((string) $request->get_param('ids'));
        if ($csvIds !== '') {
            $idsSolicitados = array_values(array_unique(array_filter(array_map(
                static fn(string $token): int => (int) trim($token),
                explode(',', $csvIds)
            ))));
            if ($idsSolicitados === []) {
                $respuesta = new \WP_REST_Response([]);
                $respuesta->header('X-WP-Total', '0');
                $respuesta->header('X-WP-TotalPages', '0');
                return $respuesta;
            }
            // Cap defensivo: el cap natural de la URL impone su propio
            // límite, pero rechazamos peticiones manifiestamente
            // abusivas (un colectivo no debería tener cientos de
            // medios; si los tiene, paginará vía /sources con filtros).
            $idsSolicitados = array_slice($idsSolicitados, 0, 100);
            $consultaPorIds = new \WP_Query([
                'post_type'      => Source::SLUG,
                'post_status'    => 'publish',
                'post__in'       => $idsSolicitados,
                'posts_per_page' => count($idsSolicitados),
                'orderby'        => 'post__in',
                'meta_query'     => [
                    'relation' => 'OR',
                    ['key' => '_fnh_active', 'value' => '1', 'compare' => '='],
                    ['key' => '_fnh_active', 'compare' => 'NOT EXISTS'],
                ],
            ]);
            $coleccionPorIds = [];
            foreach ($consultaPorIds->posts as $postEncontrado) {
                $coleccionPorIds[] = SourceTransformer::transformarCompleto($postEncontrado);
            }
            $respuesta = new \WP_REST_Response($coleccionPorIds);
            $respuesta->header('X-WP-Total', (string) count($coleccionPorIds));
            $respuesta->header('X-WP-TotalPages', '1');
            return $respuesta;
        }

        $argumentosQuery = [
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'paged'          => $pagina,
            'posts_per_page' => $porPagina,
            'orderby'        => 'title',
            'order'          => 'ASC',
            // Sólo fuentes activas (o sin meta, que se interpretan como
            // activas). Importante: el OR de _fnh_active va anidado en
            // un AND raíz — si se dejara como OR a nivel superior,
            // cualquier filtro adicional (territorio/idioma/busqueda)
            // que se añadiese con meta_query[] se uniría al OR y
            // dejaría entrar fuentes inactivas con sólo cumplir uno
            // de los subfiltros.
            'meta_query'     => [
                'relation' => 'AND',
                [
                    'relation' => 'OR',
                    ['key' => '_fnh_active', 'value' => '1', 'compare' => '='],
                    ['key' => '_fnh_active', 'compare' => 'NOT EXISTS'],
                ],
            ],
        ];

        $slugTopic = (string) $request->get_param('topic');
        if ($slugTopic !== '') {
            $argumentosQuery['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', array_filter(array_map('trim', explode(',', $slugTopic)))),
            ]];
        }

        $territorio = (string) $request->get_param('territory');
        if ($territorio !== '') {
            $argumentosQuery['meta_query'][] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field($territorio),
                'compare' => 'LIKE',
            ];
        }

        $idioma = (string) $request->get_param('language');
        if ($idioma !== '') {
            // CSV `es,eu,ca` se traduce a OR de LIKE entre comillas
            // (ver `construirMetaQueryIdiomas`). El `sanitize_key`
            // anterior comía las comas y generaba un único token sin
            // matches.
            $queryIdiomas = \FlavorNewsHub\Shortcodes\Shortcodes::construirMetaQueryIdiomas($idioma);
            if ($queryIdiomas !== []) {
                $argumentosQuery['meta_query'][] = $queryIdiomas;
            }
        }

        $terminoBusqueda = trim((string) $request->get_param('s'));
        if ($terminoBusqueda !== '') {
            $argumentosQuery['s'] = $terminoBusqueda;
            $argumentosQuery['orderby'] = 'relevance';
        }

        $consulta = new \WP_Query($argumentosQuery);

        $coleccion = [];
        foreach ($consulta->posts as $post) {
            $coleccion[] = SourceTransformer::transformarCompleto($post);
        }

        $respuesta = new \WP_REST_Response($coleccion);
        $respuesta->header('X-WP-Total', (string) $consulta->found_posts);
        $respuesta->header('X-WP-TotalPages', (string) $consulta->max_num_pages);
        return $respuesta;
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $idSource = (int) $request['id'];
        $post = get_post($idSource);
        $estructuraValida = $post
            && $post->post_type === Source::SLUG
            && $post->post_status === 'publish';
        // Misma semántica de "activo" que el listado: meta '1' Y/O meta
        // ausente (legacy / fuentes creadas por vías que no persistieron
        // el campo). Si el listado los muestra, el detalle también. La
        // versión anterior exigía exactamente '1' y devolvía 404 sobre
        // fuentes que sí aparecían en /sources.
        $metaExiste = $estructuraValida
            && metadata_exists('post', $post->ID, '_fnh_active');
        $metaEsActiva = !$metaExiste
            || (string) get_post_meta($post->ID, '_fnh_active', true) === '1';
        $esValido = $estructuraValida && $metaEsActiva;
        if (!$esValido) {
            return new \WP_REST_Response([
                'error'   => 'not_found',
                'message' => __('Medio no encontrado.', 'flavor-news-hub'),
            ], 404);
        }
        return new \WP_REST_Response(SourceTransformer::transformarCompleto($post));
    }
}
