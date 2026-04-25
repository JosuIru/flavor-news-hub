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
        $esValido = $post
            && $post->post_type === Source::SLUG
            && $post->post_status === 'publish'
            // Coherencia con el listado: un medio desactivado NO debe
            // seguir accesible por `/sources/{id}` aunque el post siga
            // "publish". El admin puede reactivarlo desde el metabox.
            && (string) get_post_meta($post->ID, '_fnh_active', true) === '1';
        if (!$esValido) {
            return new \WP_REST_Response([
                'error'   => 'not_found',
                'message' => __('Medio no encontrado.', 'flavor-news-hub'),
            ], 404);
        }
        return new \WP_REST_Response(SourceTransformer::transformarCompleto($post));
    }
}
