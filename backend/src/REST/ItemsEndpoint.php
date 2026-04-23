<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\ItemTransformer;
use FlavorNewsHub\Support\InterleaveSources;

/**
 * Endpoints de noticias:
 *  GET /items
 *  GET /items/{id}
 *
 * Orden canónico: `_fnh_published_at` descendente. Filtros por topic (slug),
 * source (ID), territory (texto LIKE sobre el source), language (código
 * contenido en el meta serializado del source) y since (ISO 8601).
 */
final class ItemsEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/items', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'listar'],
                'permission_callback' => '__return_true',
                'args'                => self::esquemaArgsListado(),
            ],
        ]);

        register_rest_route(RestController::NAMESPACE_REST, '/items/(?P<id>\d+)', [
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

    /** @return array<string,array<string,mixed>> */
    private static function esquemaArgsListado(): array
    {
        return [
            'page'      => ['type' => 'integer', 'default' => 1, 'minimum' => 1],
            'per_page'  => ['type' => 'integer', 'default' => 20, 'minimum' => 1, 'maximum' => 50],
            'topic'     => ['type' => 'string', 'description' => 'Slug o lista coma-separada de slugs de temática.'],
            'source'    => ['type' => 'integer', 'minimum' => 1],
            'territory'    => ['type' => 'string'],
            'language'     => ['type' => 'string'],
            'since'        => ['type' => 'string', 'description' => 'Fecha ISO 8601 mínima.'],
            'source_type'         => ['type' => 'string', 'description' => 'Incluye sólo items de sources con estos feed_types (coma-separado).'],
            'exclude_source_type' => ['type' => 'string', 'description' => 'Excluye items de sources con estos feed_types (coma-separado). Útil para "solo texto" sin arrastrar vídeos o podcasts.'],
            's'                   => ['type' => 'string', 'description' => 'Búsqueda por texto libre en título y cuerpo.'],
        ];
    }

    public static function listar(\WP_REST_Request $request): \WP_REST_Response
    {
        $pagina = max(1, (int) $request->get_param('page'));
        $porPagina = min(50, max(1, (int) $request->get_param('per_page')));

        $argumentosQuery = [
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'paged'          => $pagina,
            'posts_per_page' => $porPagina,
            // Usamos el `post_date_gmt` que ya guardamos normalizado a
            // UTC en el ingester (ver FeedIngester). Es columna nativa
            // de WP → no hace falta JOIN a postmeta ni un meta aparte.
            'orderby'        => 'date',
            'order'          => 'DESC',
        ];

        // Búsqueda por texto libre. WP usa `s` nativamente sobre título y
        // contenido; con buscador activo priorizamos relevancia sobre fecha.
        $terminoBusqueda = trim((string) $request->get_param('s'));
        if ($terminoBusqueda !== '') {
            $argumentosQuery['s'] = $terminoBusqueda;
            unset($argumentosQuery['meta_key']);
            $argumentosQuery['orderby'] = 'relevance';
        }

        $slugsTopic = self::parsearSlugsTopic((string) $request->get_param('topic'));
        if (!empty($slugsTopic)) {
            $argumentosQuery['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => $slugsTopic,
            ]];
        }

        $metaQueryExtra = [];
        $idSourceDirecto = (int) $request->get_param('source');
        $idsActivos = self::idsDeSourcesActivos();
        if ($idSourceDirecto > 0) {
            // Si el consumidor pide un source concreto pero está
            // desactivado, devolvemos lista vacía — evita que un id
            // recordado de un medio retirado siga devolviendo items.
            if (!in_array($idSourceDirecto, $idsActivos, true)) {
                return self::respuestaListaVacia();
            }
            $metaQueryExtra[] = [
                'key'   => '_fnh_source_id',
                'value' => (string) $idSourceDirecto,
            ];
        }

        $fechaDesde = (string) $request->get_param('since');
        if ($fechaDesde !== '') {
            $timestampDesde = strtotime($fechaDesde);
            if ($timestampDesde !== false) {
                // `date_query` contra `post_date_gmt` — comparación
                // nativa por fecha en UTC, sin las ambigüedades del
                // ISO con offsets variables que tenía el ISO string.
                $argumentosQuery['date_query'] = [[
                    'after'     => gmdate('c', $timestampDesde),
                    'column'    => 'post_date_gmt',
                    'inclusive' => true,
                ]];
            }
        }

        $territorio = (string) $request->get_param('territory');
        $idioma = (string) $request->get_param('language');
        $tiposSource = (string) $request->get_param('source_type');
        $tiposSourceExcluidos = (string) $request->get_param('exclude_source_type');
        if ($territorio !== '' || $idioma !== '' || $tiposSource !== '' || $tiposSourceExcluidos !== '') {
            $idsSourceFiltrados = self::resolverSourcesPorFiltros($territorio, $idioma, $tiposSource, $tiposSourceExcluidos);
            if ($idSourceDirecto > 0) {
                $idsSourceFiltrados = in_array($idSourceDirecto, $idsSourceFiltrados, true)
                    ? [$idSourceDirecto]
                    : [];
            }
            if (empty($idsSourceFiltrados)) {
                return self::respuestaListaVacia();
            }
            $metaQueryExtra[] = [
                'key'     => '_fnh_source_id',
                'value'   => array_map('strval', $idsSourceFiltrados),
                'compare' => 'IN',
            ];
        } elseif ($idSourceDirecto === 0) {
            // Sin filtros de metadatos NI source directo: limitamos los
            // items a sources actualmente activos. Evita que items
            // huérfanos de medios desactivados sigan saliendo por
            // `/items` simple.
            if (empty($idsActivos)) {
                return self::respuestaListaVacia();
            }
            $metaQueryExtra[] = [
                'key'     => '_fnh_source_id',
                'value'   => array_map('strval', $idsActivos),
                'compare' => 'IN',
            ];
        }

        if (!empty($metaQueryExtra)) {
            $argumentosQuery['meta_query'] = $metaQueryExtra;
        }

        $consulta = new \WP_Query($argumentosQuery);

        // Si el consumidor pide un source concreto no tocamos el orden:
        // todos los items son del mismo medio y el interleave no aplica.
        $posts = $idSourceDirecto > 0 ? $consulta->posts : InterleaveSources::aplicar($consulta->posts);

        $coleccion = [];
        foreach ($posts as $post) {
            $coleccion[] = ItemTransformer::transformar($post);
        }

        $respuesta = new \WP_REST_Response($coleccion);
        $respuesta->header('X-WP-Total', (string) $consulta->found_posts);
        $respuesta->header('X-WP-TotalPages', (string) $consulta->max_num_pages);
        return $respuesta;
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $idItem = (int) $request['id'];
        $post = get_post($idItem);
        if (!$post || $post->post_type !== Item::SLUG || $post->post_status !== 'publish') {
            return new \WP_REST_Response([
                'error'   => 'not_found',
                'message' => __('Item no encontrado.', 'flavor-news-hub'),
            ], 404);
        }
        return new \WP_REST_Response(ItemTransformer::transformar($post));
    }

    /** @return list<string> */
    private static function parsearSlugsTopic(string $valorBruto): array
    {
        if ($valorBruto === '') {
            return [];
        }
        $piezas = array_map('trim', explode(',', $valorBruto));
        $piezas = array_map('sanitize_title', $piezas);
        $piezas = array_filter($piezas, fn(string $s) => $s !== '');
        return array_values($piezas);
    }

    /**
     * Resuelve los IDs de `fnh_source` que encajan con filtros de
     * territorio, idioma y/o tipo de feed (coma-separado).
     *
     * @return list<int>
     */
    private static function resolverSourcesPorFiltros(
        string $territorio,
        string $idioma,
        string $tiposSource = '',
        string $tiposSourceExcluidos = ''
    ): array {
        $metaQuery = [];
        if ($territorio !== '') {
            $metaQuery[] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field($territorio),
                'compare' => 'LIKE',
            ];
        }
        if ($idioma !== '') {
            // `_fnh_languages` se guarda como array PHP serializado. Admite
            // varios códigos coma-separados: `es,eu` → source coincide si
            // tiene CUALQUIERA de ellos.
            $codigos = array_filter(array_map('sanitize_key', array_map('trim', explode(',', $idioma))));
            if (count($codigos) === 1) {
                $metaQuery[] = [
                    'key'     => '_fnh_languages',
                    'value'   => reset($codigos),
                    'compare' => 'LIKE',
                ];
            } elseif (count($codigos) > 1) {
                $orQuery = ['relation' => 'OR'];
                foreach ($codigos as $codigo) {
                    $orQuery[] = [
                        'key'     => '_fnh_languages',
                        'value'   => $codigo,
                        'compare' => 'LIKE',
                    ];
                }
                $metaQuery[] = $orQuery;
            }
        }
        if ($tiposSource !== '') {
            $piezas = array_map('sanitize_key', array_filter(array_map('trim', explode(',', $tiposSource))));
            if (!empty($piezas)) {
                $metaQuery[] = [
                    'key'     => '_fnh_feed_type',
                    'value'   => array_values($piezas),
                    'compare' => 'IN',
                ];
            }
        }
        if ($tiposSourceExcluidos !== '') {
            $piezas = array_map('sanitize_key', array_filter(array_map('trim', explode(',', $tiposSourceExcluidos))));
            if (!empty($piezas)) {
                // NOT IN excluye los que tengan el meta con ese valor, PERO también
                // "excluye" (no matchea) los que no tengan la key.
                // Para que los sources sin `_fnh_feed_type` no queden fuera del feed,
                // combinamos con OR NOT EXISTS.
                $metaQuery[] = [
                    'relation' => 'OR',
                    [
                        'key'     => '_fnh_feed_type',
                        'value'   => array_values($piezas),
                        'compare' => 'NOT IN',
                    ],
                    [
                        'key'     => '_fnh_feed_type',
                        'compare' => 'NOT EXISTS',
                    ],
                ];
            }
        }
        // Restringimos SIEMPRE a sources activos: un medio desactivado no
        // debe seguir reapareciendo por `/items?territory=…`, etc. Antes
        // se filtraba en `/sources` pero no en `/items` — inconsistencia
        // que rompía la expectativa del consumidor.
        $metaQuery[] = [
            'key'   => '_fnh_active',
            'value' => '1',
        ];
        $consulta = new \WP_Query([
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => $metaQuery,
        ]);
        return array_map('intval', $consulta->posts);
    }

    /**
     * Lista completa de IDs de sources activos. Cacheada en memoria por
     * request para no repetir la query desde los distintos callers.
     *
     * @return list<int>
     */
    private static function idsDeSourcesActivos(): array
    {
        static $cache = null;
        if ($cache !== null) {
            return $cache;
        }
        $consulta = new \WP_Query([
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [[
                'key'   => '_fnh_active',
                'value' => '1',
            ]],
        ]);
        $cache = array_map('intval', $consulta->posts);
        return $cache;
    }

    private static function respuestaListaVacia(): \WP_REST_Response
    {
        $respuesta = new \WP_REST_Response([]);
        $respuesta->header('X-WP-Total', '0');
        $respuesta->header('X-WP-TotalPages', '0');
        return $respuesta;
    }
}
