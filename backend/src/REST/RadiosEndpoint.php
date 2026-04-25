<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\TopicsHelper;
use FlavorNewsHub\Support\TerritoryNormalizer;

/**
 * Endpoints del directorio de radios libres:
 *  GET /radios
 *  GET /radios/{id}
 *
 * Devuelve los `fnh_radio` con stream en directo que la instancia curó.
 */
final class RadiosEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/radios', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'listar'],
                'permission_callback' => '__return_true',
                'args'                => [
                    'page'      => ['type' => 'integer', 'default' => 1, 'minimum' => 1],
                    'per_page'  => ['type' => 'integer', 'default' => 100, 'minimum' => 1, 'maximum' => 200],
                    'territory' => ['type' => 'string'],
                    'language'  => ['type' => 'string'],
                    'topic'     => ['type' => 'string'],
                    's'         => ['type' => 'string', 'description' => 'Búsqueda por texto libre.'],
                ],
            ],
        ]);

        register_rest_route(RestController::NAMESPACE_REST, '/radios/(?P<id>\d+)', [
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
        $porPagina = min(200, max(1, (int) $request->get_param('per_page')));

        $argumentosQuery = [
            'post_type'      => Radio::SLUG,
            'post_status'    => 'publish',
            'paged'          => $pagina,
            'posts_per_page' => $porPagina,
            'orderby'        => 'title',
            'order'          => 'ASC',
            // Ver nota en SourcesEndpoint: anidamos el OR de activo
            // dentro de un AND raíz para que filtros adicionales
            // (territorio/idioma/busqueda) no relajen la restricción.
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
            // Soportamos CSV (`es,eu,ca`). Antes hacíamos `sanitize_key`
            // directo sobre toda la cadena, que comía las comas y
            // generaba `eseuca` — ningún radio matcheaba.
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
            $coleccion[] = self::transformar($post);
        }

        $respuesta = new \WP_REST_Response($coleccion);
        $respuesta->header('X-WP-Total', (string) $consulta->found_posts);
        $respuesta->header('X-WP-TotalPages', (string) $consulta->max_num_pages);
        return $respuesta;
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $idRadio = (int) $request['id'];
        $post = get_post($idRadio);
        if (!$post
            || $post->post_type !== Radio::SLUG
            || $post->post_status !== 'publish'
            || (string) get_post_meta($idRadio, '_fnh_active', true) === '0'
        ) {
            // Misma política que el listado: una radio desactivada no
            // se expone por /radios/{id} aunque el post exista.
            return new \WP_REST_Response([
                'error'   => 'not_found',
                'message' => __('Radio no encontrada.', 'flavor-news-hub'),
            ], 404);
        }
        return new \WP_REST_Response(self::transformar($post));
    }

    /**
     * @return array<string,mixed>
     */
    private static function transformar(\WP_Post $post): array
    {
        $idRadio = (int) $post->ID;
        $idiomas = get_post_meta($idRadio, '_fnh_languages', true);
        if (!is_array($idiomas)) {
            $idiomas = [];
        }
        $territorio = (string) get_post_meta($idRadio, '_fnh_territory', true);
        $ubicacion = self::obtenerUbicacion($idRadio, $territorio);
        return [
            'id'          => $idRadio,
            'slug'        => (string) $post->post_name,
            'name'        => get_the_title($post),
            'description' => (string) apply_filters('the_content', $post->post_content),
            'url'         => (string) get_permalink($post),
            'stream_url'  => (string) get_post_meta($idRadio, '_fnh_stream_url', true),
            'website_url' => (string) get_post_meta($idRadio, '_fnh_website_url', true),
            'rss_url'     => (string) get_post_meta($idRadio, '_fnh_rss_url', true),
            'support_url' => (string) get_post_meta($idRadio, '_fnh_support_url', true),
            'territory'   => $territorio,
            'country'     => $ubicacion['country'],
            'region'      => $ubicacion['region'],
            'city'        => $ubicacion['city'],
            'languages'   => array_values(array_map('strval', $idiomas)),
            'ownership'   => (string) get_post_meta($idRadio, '_fnh_ownership', true),
            'active'      => (bool) get_post_meta($idRadio, '_fnh_active', true),
            'topics'      => TopicsHelper::obtenerTopicsDelPost($idRadio),
        ];
    }

    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    private static function obtenerUbicacion(int $idRadio, string $territorio): array
    {
        $country = (string) get_post_meta($idRadio, '_fnh_country', true);
        $region = (string) get_post_meta($idRadio, '_fnh_region', true);
        $city = (string) get_post_meta($idRadio, '_fnh_city', true);
        if ($country === '' && $region === '' && $city === '') {
            return TerritoryNormalizer::desglosar($territorio);
        }
        return [
            'country' => $country,
            'region' => $region,
            'city' => $city,
            'network' => '',
        ];
    }
}
