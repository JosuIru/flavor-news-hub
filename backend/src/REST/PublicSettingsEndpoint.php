<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Options\OptionsRepository;

/**
 * Endpoint público con los ajustes que los clientes (app móvil, web
 * externa) necesitan conocer sin hacer login. Hoy expone la URL de
 * donaciones (configurable desde wp-admin → Ajustes) y el nombre del
 * sitio (`get_bloginfo('name')`) para que la app pueda etiquetar la
 * instancia con un nombre legible en el selector — sin pedir al
 * usuario que lo escriba a mano.
 *
 * Queda extensible: si más adelante el admin configura una URL de
 * manifiesto, un icono, etc., se añaden aquí.
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
            // `site_name` viene de la opción `blogname` (la del Customizer
            // → "Título del sitio"). El cliente lo usa para prerellenar
            // el campo "Nombre" al guardar una instancia y diferenciar
            // varias en el selector. Sin login, sin auth: es info ya
            // pública en cualquier WordPress.
            'site_name'    => (string) get_bloginfo('name'),
        ], 200);
    }
}
