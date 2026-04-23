<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Options\OptionsRepository;

/**
 * Endpoint público con los ajustes que los clientes (app móvil, web
 * externa) necesitan conocer sin hacer login. Por ahora sólo expone la
 * URL de donaciones — admin la cambia desde Ajustes y todos los
 * clientes la sincronizan sin necesidad de una release nueva.
 *
 * Queda extensible: si más adelante el admin configura un nombre de
 * proyecto, una URL de manifiesto, etc., se añaden aquí.
 *
 * GET /wp-json/flavor-news/v1/settings
 */
final class PublicSettingsEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/settings', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'obtener'],
                'permission_callback' => '__return_true',
            ],
        ]);
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $ajustes = OptionsRepository::todas();
        return new \WP_REST_Response([
            'donation_url' => (string) ($ajustes['donation_url'] ?? OptionsRepository::DONATION_URL_DEFAULT),
        ], 200);
    }
}
