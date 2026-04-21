<?php
declare(strict_types=1);

namespace FlavorNewsHub\Meta;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;

/**
 * Registro centralizado de meta fields para los tres CPTs.
 *
 * Convenciones:
 * - Todos los meta usan prefijo `_fnh_` para señalar que son internos del plugin
 *   (el underscore también oculta el meta del UI genérico de "Campos personalizados"
 *   si éste estuviera habilitado).
 * - `show_in_rest` se decide campo a campo: los datos sensibles
 *   (`_fnh_contact_email`, `_fnh_submitted_by_email`) quedan fuera del REST estándar
 *   de WordPress. La API propia `flavor-news/v1` tampoco los expondrá públicamente.
 * - `auth_callback` exige permisos de edición para escribir meta vía REST.
 *   La ingesta (capa 3) escribe vía `update_post_meta()`, no vía REST, así
 *   que el auth_callback no le afecta.
 */
final class MetaRegistrar
{
    public static function registrar(): void
    {
        self::registrarMetaDeSource();
        self::registrarMetaDeItem();
        self::registrarMetaDeCollective();
        self::registrarMetaDeRadio();
    }

    private static function registrarMetaDeSource(): void
    {
        $tipoPostSource = Source::SLUG;

        register_post_meta($tipoPostSource, '_fnh_feed_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_feed_type', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => 'rss',
            'sanitize_callback' => [self::class, 'saneatTipoFeed'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_website_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_languages', [
            'type'              => 'array',
            'single'            => true,
            'default'           => [],
            'show_in_rest'      => [
                'schema' => [
                    'type'  => 'array',
                    'items' => ['type' => 'string'],
                ],
            ],
            'sanitize_callback' => [self::class, 'saneatListaCodigosIdioma'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_territory', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_ownership', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'wp_kses_post',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_editorial_note', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'wp_kses_post',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_active', [
            'type'              => 'boolean',
            'single'            => true,
            'default'           => true,
            'show_in_rest'      => true,
            'sanitize_callback' => 'rest_sanitize_boolean',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);
    }

    private static function registrarMetaDeItem(): void
    {
        $tipoPostItem = Item::SLUG;

        register_post_meta($tipoPostItem, '_fnh_source_id', [
            'type'              => 'integer',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => 0,
            'sanitize_callback' => 'absint',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostItem, '_fnh_original_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostItem, '_fnh_published_at', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => [self::class, 'saneatFechaIso8601'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostItem, '_fnh_guid', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostItem, '_fnh_media_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostItem, '_fnh_duration_seconds', [
            'type'              => 'integer',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => 0,
            'sanitize_callback' => 'absint',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);
    }

    private static function registrarMetaDeCollective(): void
    {
        $tipoPostCollective = Collective::SLUG;

        register_post_meta($tipoPostCollective, '_fnh_website_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Email de contacto: nunca expuesto vía REST público.
        register_post_meta($tipoPostCollective, '_fnh_contact_email', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => false,
            'default'           => '',
            'sanitize_callback' => 'sanitize_email',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostCollective, '_fnh_territory', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostCollective, '_fnh_flavor_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostCollective, '_fnh_verified', [
            'type'              => 'boolean',
            'single'            => true,
            'default'           => false,
            'show_in_rest'      => true,
            'sanitize_callback' => 'rest_sanitize_boolean',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Email del remitente de un alta pública: auditoría interna únicamente.
        register_post_meta($tipoPostCollective, '_fnh_submitted_by_email', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => false,
            'default'           => '',
            'sanitize_callback' => 'sanitize_email',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);
    }

    private static function registrarMetaDeRadio(): void
    {
        $tipoPost = Radio::SLUG;

        register_post_meta($tipoPost, '_fnh_stream_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_website_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // RSS opcional: si la emisora publica un feed de programas/podcast
        // propio, se usa para listar episodios junto al stream en directo.
        register_post_meta($tipoPost, '_fnh_rss_url', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'esc_url_raw',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_territory', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_languages', [
            'type'              => 'array',
            'single'            => true,
            'default'           => [],
            'show_in_rest'      => [
                'schema' => [
                    'type'  => 'array',
                    'items' => ['type' => 'string'],
                ],
            ],
            'sanitize_callback' => [self::class, 'saneatListaCodigosIdioma'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_ownership', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'wp_kses_post',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_active', [
            'type'              => 'boolean',
            'single'            => true,
            'default'           => true,
            'show_in_rest'      => true,
            'sanitize_callback' => 'rest_sanitize_boolean',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);
    }

    /**
     * Permiso requerido para escribir meta vía REST estándar.
     *
     * No afecta a la ingesta interna (que usa `update_post_meta()` y opera
     * con sus propios permisos) ni a la API propia del plugin, que tendrá
     * sus propios controles por endpoint.
     */
    public static function puedeEditarPosts(): bool
    {
        return current_user_can('edit_posts');
    }

    /**
     * Admite sólo los tipos de feed declarados en la especificación.
     * Valor desconocido cae a 'rss' por defecto.
     */
    public static function saneatTipoFeed($valorEntrada): string
    {
        $tiposPermitidos = ['rss', 'atom', 'youtube', 'mastodon', 'podcast', 'video', 'flavor_platform'];
        $valorLimpio = sanitize_key((string) $valorEntrada);
        return in_array($valorLimpio, $tiposPermitidos, true) ? $valorLimpio : 'rss';
    }

    /**
     * Lista de códigos de idioma (ISO 639-1, opcionalmente con región:
     * "es", "ca", "eu", "gl", "pt-br", etc.). Deduplica y descarta valores
     * no plausibles.
     *
     * @param mixed $valorEntrada
     * @return list<string>
     */
    public static function saneatListaCodigosIdioma($valorEntrada): array
    {
        if (!is_array($valorEntrada)) {
            return [];
        }
        $codigosSaneados = [];
        foreach ($valorEntrada as $codigoBruto) {
            $codigoLimpio = sanitize_key((string) $codigoBruto);
            if ($codigoLimpio !== '' && strlen($codigoLimpio) <= 10) {
                $codigosSaneados[] = $codigoLimpio;
            }
        }
        return array_values(array_unique($codigosSaneados));
    }

    /**
     * Normaliza una fecha a formato ISO 8601 UTC. Si la entrada no es
     * parseable, devuelve cadena vacía (el campo se entiende como "sin fecha").
     *
     * @param mixed $valorEntrada
     */
    public static function saneatFechaIso8601($valorEntrada): string
    {
        if (!is_string($valorEntrada) || $valorEntrada === '') {
            return '';
        }
        $timestampUnix = strtotime($valorEntrada);
        if ($timestampUnix === false) {
            return '';
        }
        return gmdate('c', $timestampUnix);
    }
}
