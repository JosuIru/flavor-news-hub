<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\TopicTransformer;

/**
 * Endpoint de temáticas:
 *  GET /topics
 *
 * Devuelve el árbol de la taxonomía en plano (cada término con su `parent`),
 * incluyendo aquellos sin contenido asociado aún (precargados).
 */
final class TopicsEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/topics', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'listar'],
                'permission_callback' => '__return_true',
            ],
        ]);
    }

    public static function listar(\WP_REST_Request $request): \WP_REST_Response
    {
        $terminos = get_terms([
            'taxonomy'   => Topic::SLUG,
            'hide_empty' => false,
            'orderby'    => 'name',
            'order'      => 'ASC',
        ]);
        if (is_wp_error($terminos)) {
            return new \WP_REST_Response([], 200);
        }

        $coleccion = array_map(
            static fn(\WP_Term $termino): array => TopicTransformer::transformar($termino),
            $terminos
        );
        return new \WP_REST_Response($coleccion);
    }
}
