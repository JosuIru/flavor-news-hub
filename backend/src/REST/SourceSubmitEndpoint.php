<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;

/**
 * Endpoint público para proponer un medio:
 *  POST /flavor-news/v1/sources/submit
 *
 * Análogo al de colectivos. Protecciones idénticas: honeypot, rate-limit
 * por IP (3/hora) y validación server-side.
 *
 * El alta entra en `post_status=pending` con `_fnh_active=false`. Nunca
 * aparece en `GET /sources` (que filtra por publish+activo) hasta que un
 * verificador humano la apruebe desde el admin con la bulk action
 * "Verificar y activar".
 *
 * Mantiene el principio editorial del manifiesto: proponer es abierto;
 * publicar requiere curación humana. Quien no quiera ese filtro puede
 * autohospedar su propia instancia.
 */
final class SourceSubmitEndpoint
{
    public const NOMBRE_ZONA_RATELIMIT = 'source_submit';
    public const MAX_ALTAS_POR_VENTANA = 3;

    private const TIPOS_FEED_PERMITIDOS = ['rss', 'atom', 'youtube', 'mastodon', 'podcast', 'flavor_platform'];

    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/sources/submit', [
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
            'feed_url'      => ['type' => 'string', 'required' => true],
            'contact_email' => ['type' => 'string', 'required' => true, 'format' => 'email'],
            'feed_type'     => ['type' => 'string'],
            'description'   => ['type' => 'string'],
            'website_url'   => ['type' => 'string'],
            'territory'     => ['type' => 'string'],
            'languages'     => ['type' => 'array', 'items' => ['type' => 'string']],
            'topics'        => ['type' => 'array', 'items' => ['type' => 'string']],
            'website'       => ['type' => 'string'], // honeypot
        ];
    }

    public static function crear(\WP_REST_Request $request): \WP_REST_Response
    {
        // 1. Honeypot.
        $campoHoneypot = (string) $request->get_param('website');
        if ($campoHoneypot !== '') {
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
        $nombreMedio = sanitize_text_field((string) $request->get_param('name'));
        $urlFeed = esc_url_raw((string) $request->get_param('feed_url'));
        $emailContacto = sanitize_email((string) $request->get_param('contact_email'));

        if ($nombreMedio === '' || $urlFeed === '' || !is_email($emailContacto)) {
            return new \WP_REST_Response([
                'error'   => 'invalid_fields',
                'message' => __('Faltan campos obligatorios (nombre, feed_url, email válido).', 'flavor-news-hub'),
            ], 400);
        }
        if (!self::pareceUrlValida($urlFeed)) {
            return new \WP_REST_Response([
                'error'   => 'invalid_feed_url',
                'message' => __('La URL del feed no tiene un formato válido (debe empezar por http:// o https://).', 'flavor-news-hub'),
            ], 400);
        }

        $tipoFeed = sanitize_key((string) $request->get_param('feed_type'));
        if (!in_array($tipoFeed, self::TIPOS_FEED_PERMITIDOS, true)) {
            $tipoFeed = 'rss';
        }
        $descripcionMedio = wp_kses_post((string) $request->get_param('description'));
        $urlSitioWeb = esc_url_raw((string) $request->get_param('website_url'));
        $territorio = sanitize_text_field((string) $request->get_param('territory'));

        $idiomasEntrada = (array) $request->get_param('languages');
        $idiomasLimpios = [];
        foreach ($idiomasEntrada as $codigoBruto) {
            $codigoSaneado = sanitize_key((string) $codigoBruto);
            if ($codigoSaneado !== '' && strlen($codigoSaneado) <= 10) {
                $idiomasLimpios[] = $codigoSaneado;
            }
        }
        $idiomasLimpios = array_values(array_unique($idiomasLimpios));

        // 4. Crear como pending.
        $idNuevo = wp_insert_post([
            'post_type'    => Source::SLUG,
            'post_status'  => 'pending',
            'post_title'   => $nombreMedio,
            'post_content' => $descripcionMedio,
        ], true);

        if (is_wp_error($idNuevo) || (int) $idNuevo === 0) {
            return new \WP_REST_Response(['error' => 'server_error'], 500);
        }

        // 5. Meta (incluyendo email del remitente como auditoría interna;
        // reutilizamos la misma key que en colectivos para coherencia admin).
        update_post_meta($idNuevo, '_fnh_feed_url', $urlFeed);
        update_post_meta($idNuevo, '_fnh_feed_type', $tipoFeed);
        update_post_meta($idNuevo, '_fnh_website_url', $urlSitioWeb);
        update_post_meta($idNuevo, '_fnh_territory', $territorio);
        update_post_meta($idNuevo, '_fnh_languages', $idiomasLimpios);
        update_post_meta($idNuevo, '_fnh_active', false);
        update_post_meta($idNuevo, '_fnh_submitted_by_email', $emailContacto);

        // 6. Topics: solo los que existan en la taxonomía.
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
                wp_set_object_terms($idNuevo, $idsTerminoAceptados, Topic::SLUG, false);
            }
        }

        return new \WP_REST_Response([
            'success' => true,
            'id'      => (int) $idNuevo,
            'message' => __('Gracias. Revisaremos tu propuesta y el medio aparecerá cuando esté verificado.', 'flavor-news-hub'),
        ], 202);
    }

    /**
     * Pre-validación ligera de la URL del feed. La verificación real
     * (que realmente devuelva XML parseable) la hace la ingesta en cuanto
     * el admin active la fuente.
     */
    private static function pareceUrlValida(string $url): bool
    {
        if ($url === '') {
            return false;
        }
        $partes = wp_parse_url($url);
        if (!is_array($partes)) {
            return false;
        }
        $esquema = $partes['scheme'] ?? '';
        $anfitrion = $partes['host'] ?? '';
        return in_array($esquema, ['http', 'https'], true) && $anfitrion !== '';
    }
}
