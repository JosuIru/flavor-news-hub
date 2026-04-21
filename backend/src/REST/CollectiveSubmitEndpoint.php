<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\Taxonomy\Topic;

/**
 * Endpoint público para alta de colectivos:
 *  POST /collectives/submit
 *
 * Protecciones:
 *  - Honeypot: campo `website` que los humanos no rellenan.
 *  - Rate limit por IP: 3 altas por hora (zona `collective_submit`).
 *  - Validación de campos obligatorios (name, description, contact_email).
 *  - El alta entra en `post_status=pending` y nunca queda visible en la API
 *    pública hasta que un verificador humano la publique y la marque como
 *    verified desde el admin.
 *
 * Campos sensibles (email) se guardan en meta y nunca se devuelven al cliente.
 */
final class CollectiveSubmitEndpoint
{
    public const NOMBRE_ZONA_RATELIMIT = 'collective_submit';
    public const MAX_ALTAS_POR_VENTANA = 3;

    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/collectives/submit', [
            [
                'methods'             => \WP_REST_Server::CREATABLE,
                'callback'            => [self::class, 'crear'],
                'permission_callback' => '__return_true',
                'args'                => self::esquemaArgs(),
            ],
        ]);
    }

    /** @return array<string,array<string,mixed>> */
    private static function esquemaArgs(): array
    {
        return [
            'name'          => ['type' => 'string', 'required' => true],
            'description'   => ['type' => 'string', 'required' => true],
            'contact_email' => ['type' => 'string', 'required' => true, 'format' => 'email'],
            'website_url'   => ['type' => 'string'],
            'territory'     => ['type' => 'string'],
            'flavor_url'    => ['type' => 'string'],
            'topics'        => ['type' => 'array', 'items' => ['type' => 'string']],
            'website'       => ['type' => 'string'], // honeypot: debe venir vacío
        ];
    }

    public static function crear(\WP_REST_Request $request): \WP_REST_Response
    {
        // 1. Honeypot — los bots suelen rellenar cualquier campo que vean.
        $campoHoneypot = (string) $request->get_param('website');
        if ($campoHoneypot !== '') {
            // Respuesta genérica para no revelar al bot la razón del rechazo.
            return new \WP_REST_Response(['error' => 'invalid_submission'], 400);
        }

        // 2. Rate limit por IP.
        $ipCliente = RateLimiter::ipDelCliente();
        $permitido = RateLimiter::registrarIntentoOAgotado(
            $ipCliente,
            self::NOMBRE_ZONA_RATELIMIT,
            self::MAX_ALTAS_POR_VENTANA,
            HOUR_IN_SECONDS
        );
        if (!$permitido) {
            return new \WP_REST_Response([
                'error'   => 'rate_limited',
                'message' => __('Demasiadas peticiones desde esta dirección. Inténtalo de nuevo más tarde.', 'flavor-news-hub'),
            ], 429);
        }

        // 3. Validación.
        $nombreColectivo = sanitize_text_field((string) $request->get_param('name'));
        $descripcionColectivo = wp_kses_post((string) $request->get_param('description'));
        $emailContacto = sanitize_email((string) $request->get_param('contact_email'));

        if ($nombreColectivo === '' || $descripcionColectivo === '' || !is_email($emailContacto)) {
            return new \WP_REST_Response([
                'error'   => 'invalid_fields',
                'message' => __('Faltan campos obligatorios o el email de contacto no es válido.', 'flavor-news-hub'),
            ], 400);
        }

        $urlWeb = esc_url_raw((string) $request->get_param('website_url'));
        $urlFlavor = esc_url_raw((string) $request->get_param('flavor_url'));
        $territorioColectivo = sanitize_text_field((string) $request->get_param('territory'));

        // 4. Crear el post en estado `pending`.
        $idColectivoNuevo = wp_insert_post([
            'post_type'    => Collective::SLUG,
            'post_status'  => 'pending',
            'post_title'   => $nombreColectivo,
            'post_content' => $descripcionColectivo,
        ], true);

        if (is_wp_error($idColectivoNuevo) || (int) $idColectivoNuevo === 0) {
            return new \WP_REST_Response(['error' => 'server_error'], 500);
        }

        // 5. Guardar meta, incluyendo email de contacto y remitente (ambos internos).
        update_post_meta($idColectivoNuevo, '_fnh_contact_email', $emailContacto);
        update_post_meta($idColectivoNuevo, '_fnh_submitted_by_email', $emailContacto);
        update_post_meta($idColectivoNuevo, '_fnh_verified', false);
        if ($urlWeb !== '') {
            update_post_meta($idColectivoNuevo, '_fnh_website_url', $urlWeb);
        }
        if ($urlFlavor !== '') {
            update_post_meta($idColectivoNuevo, '_fnh_flavor_url', $urlFlavor);
        }
        if ($territorioColectivo !== '') {
            update_post_meta($idColectivoNuevo, '_fnh_territory', $territorioColectivo);
        }

        // 6. Topics: sólo se aceptan slugs que ya existan; no se crean temáticas nuevas desde esta vía.
        $slugsEntrantes = (array) $request->get_param('topics');
        if (!empty($slugsEntrantes)) {
            $idsTerminoAceptados = [];
            foreach ($slugsEntrantes as $slugBruto) {
                $slugLimpio = sanitize_title((string) $slugBruto);
                if ($slugLimpio === '') {
                    continue;
                }
                $termino = get_term_by('slug', $slugLimpio, Topic::SLUG);
                if ($termino instanceof \WP_Term) {
                    $idsTerminoAceptados[] = (int) $termino->term_id;
                }
            }
            if (!empty($idsTerminoAceptados)) {
                wp_set_object_terms($idColectivoNuevo, $idsTerminoAceptados, Topic::SLUG, false);
            }
        }

        return new \WP_REST_Response([
            'success' => true,
            'id'      => (int) $idColectivoNuevo,
            'message' => __('Gracias. Revisaremos tu alta y aparecerá en el directorio cuando esté verificada.', 'flavor-news-hub'),
        ], 202);
    }
}
