<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\CollectiveTransformer;

/**
 * Endpoints de colectivos:
 *  GET /collectives
 *  GET /collectives/{id}
 *
 * Sólo devuelve colectivos verificados (`post_status = publish` y
 * `_fnh_verified = true`). Los pending viven en el admin y se publican
 * tras revisión manual.
 *
 * Nunca expone emails (`_fnh_contact_email`, `_fnh_submitted_by_email`).
 */
final class CollectivesEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/collectives', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'listar'],
                'permission_callback' => '__return_true',
                'args'                => [
                    'page'      => ['type' => 'integer', 'default' => 1, 'minimum' => 1],
                    'per_page'  => ['type' => 'integer', 'default' => 20, 'minimum' => 1, 'maximum' => 50],
                    'topic'     => ['type' => 'string'],
                    'territory' => ['type' => 'string'],
                    's'         => ['type' => 'string', 'description' => 'Búsqueda por texto libre.'],
                ],
            ],
        ]);

        register_rest_route(RestController::NAMESPACE_REST, '/collectives/(?P<id>\d+)', [
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
        $porPagina = min(50, max(1, (int) $request->get_param('per_page')));

        $argumentosQuery = [
            'post_type'      => Collective::SLUG,
            'post_status'    => 'publish',
            'paged'          => $pagina,
            'posts_per_page' => $porPagina,
            'orderby'        => 'title',
            'order'          => 'ASC',
            'meta_query'     => [
                [
                    'key'   => '_fnh_verified',
                    'value' => '1',
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

        $terminoBusqueda = trim((string) $request->get_param('s'));
        if ($terminoBusqueda !== '') {
            $argumentosQuery['s'] = $terminoBusqueda;
            $argumentosQuery['orderby'] = 'relevance';
        }

        $consulta = new \WP_Query($argumentosQuery);

        $coleccion = [];
        foreach ($consulta->posts as $post) {
            $coleccion[] = CollectiveTransformer::transformar($post);
        }

        $respuesta = new \WP_REST_Response($coleccion);
        $respuesta->header('X-WP-Total', (string) $consulta->found_posts);
        $respuesta->header('X-WP-TotalPages', (string) $consulta->max_num_pages);
        return $respuesta;
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $idColectivo = (int) $request['id'];
        $post = get_post($idColectivo);
        if (
            !$post
            || $post->post_type !== Collective::SLUG
            || $post->post_status !== 'publish'
            || !get_post_meta($idColectivo, '_fnh_verified', true)
        ) {
            return new \WP_REST_Response([
                'error'   => 'not_found',
                'message' => __('Colectivo no encontrado.', 'flavor-news-hub'),
            ], 404);
        }
        return new \WP_REST_Response(CollectiveTransformer::transformar($post));
    }
}
