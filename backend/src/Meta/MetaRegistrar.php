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

        register_post_meta($tipoPostSource, '_fnh_country', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_region', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_city', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_network', [
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

        // `medium_type` es el tipo de medio (news, video, radio, tv_station),
        // distinto de `feed_type` (rss/youtube/podcast...) que describe el
        // transporte técnico. Una TV comunitaria puede publicar vía YouTube
        // (feed_type=youtube) siendo conceptualmente una tv_station.
        register_post_meta($tipoPostSource, '_fnh_medium_type', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => 'news',
            'sanitize_callback' => [self::class, 'saneatTipoMedio'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Formatos en los que el medio emite/distribuye contenido. Útil
        // para filtrar (p. ej. "TVs con TDT legal" o "solo PeerTube").
        register_post_meta($tipoPostSource, '_fnh_broadcast_format', [
            'type'              => 'array',
            'single'            => true,
            'default'           => [],
            'show_in_rest'      => [
                'schema' => [
                    'type'  => 'array',
                    'items' => ['type' => 'string'],
                ],
            ],
            'sanitize_callback' => [self::class, 'saneatFormatosEmision'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Licencia declarada del contenido. Cadena vacía = no declarada.
        // Sólo las CC explícitas habilitan embed en la pantalla "En directo".
        register_post_meta($tipoPostSource, '_fnh_content_license', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => [self::class, 'saneatLicenciaContenido'],
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Nota breve de contexto legal/editorial. Campo educativo: aquí
        // va, p. ej., "emite sin licencia de TDT porque España no ha
        // convocado el concurso de frecuencias comunitarias desde 2010".
        register_post_meta($tipoPostSource, '_fnh_legal_note', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'wp_kses_post',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostSource, '_fnh_has_live_stream', [
            'type'              => 'boolean',
            'single'            => true,
            'default'           => false,
            'show_in_rest'      => true,
            'sanitize_callback' => 'rest_sanitize_boolean',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        // Permiso para embeber el stream en la app. Sólo `cc-license`
        // habilita el embed por política del proyecto: no pedimos
        // permisos por email; si un medio quiere entrar bajo written-permission
        // es él quien contacta.
        register_post_meta($tipoPostSource, '_fnh_live_stream_permit', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => 'none',
            'sanitize_callback' => [self::class, 'saneatPermisoStream'],
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

        // URL del audio del episodio (enclosure de podcast). La app la
        // pasa directa al reproductor de audio.
        register_post_meta($tipoPostItem, '_fnh_audio_url', [
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

        register_post_meta($tipoPostCollective, '_fnh_country', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostCollective, '_fnh_region', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPostCollective, '_fnh_city', [
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

        // IDs de `fnh_source` que este colectivo edita o mantiene. Un
        // medio puede "pertenecer" a un colectivo en el sentido
        // editorial (ej. Pikara Magazine ↔ una asociación que la
        // edita). No es exclusivo: un item heredará el colectivo vía
        // su source. N:1 por ahora (un colectivo puede tener varios
        // medios; un source sólo a un colectivo como máximo).
        register_post_meta($tipoPostCollective, '_fnh_source_ids', [
            'type'              => 'array',
            'single'            => true,
            'show_in_rest'      => [
                'schema' => [
                    'type'  => 'array',
                    'items' => ['type' => 'integer'],
                ],
            ],
            'default'           => [],
            'sanitize_callback' => [self::class, 'sanearArrayEnteros'],
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

        register_post_meta($tipoPost, '_fnh_country', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_region', [
            'type'              => 'string',
            'single'            => true,
            'show_in_rest'      => true,
            'default'           => '',
            'sanitize_callback' => 'sanitize_text_field',
            'auth_callback'     => [self::class, 'puedeEditarPosts'],
        ]);

        register_post_meta($tipoPost, '_fnh_city', [
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
     * Tipo de medio (ortogonal al transporte del feed). Valor desconocido
     * cae a 'news' para no alterar el comportamiento de las fuentes
     * existentes que aún no tengan este meta poblado.
     */
    public static function saneatTipoMedio($valorEntrada): string
    {
        $tiposPermitidos = ['news', 'video', 'radio', 'tv_station'];
        $valorLimpio = sanitize_key((string) $valorEntrada);
        return in_array($valorLimpio, $tiposPermitidos, true) ? $valorLimpio : 'news';
    }

    /**
     * Lista de formatos de emisión/distribución. Valores desconocidos se
     * descartan silenciosamente.
     *
     * @param mixed $valorEntrada
     * @return list<string>
     */
    public static function saneatFormatosEmision($valorEntrada): array
    {
        if (!is_array($valorEntrada)) {
            return [];
        }
        $permitidos = ['web', 'peertube', 'youtube', 'tdt_legal', 'tdt_sin_licencia', 'cable', 'satelite', 'streaming_propio'];
        $saneados = [];
        foreach ($valorEntrada as $bruto) {
            $limpio = sanitize_key((string) $bruto);
            if (in_array($limpio, $permitidos, true)) {
                $saneados[] = $limpio;
            }
        }
        return array_values(array_unique($saneados));
    }

    /**
     * Licencia de contenido declarada. Admite las CC comunes, dominio
     * público, "all-rights-reserved" y "mixed". Cadena vacía = no declarada.
     */
    public static function saneatLicenciaContenido($valorEntrada): string
    {
        $permitidas = [
            '',
            'cc-by-4.0', 'cc-by-sa-4.0', 'cc-by-nc-4.0', 'cc-by-nc-sa-4.0',
            'cc-by-nd-4.0', 'cc-by-nc-nd-4.0', 'cc-by-nc-nd-3.0', 'cc-by-nc-nd-3.0-us',
            'cc0-1.0', 'public-domain',
            'all-rights-reserved', 'mixed',
        ];
        // No usamos sanitize_key aquí: las licencias contienen puntos y guiones.
        $limpio = strtolower(trim((string) $valorEntrada));
        $limpio = preg_replace('/[^a-z0-9\-.]/', '', $limpio) ?? '';
        return in_array($limpio, $permitidas, true) ? $limpio : '';
    }

    /**
     * Permiso para embeber el stream en "En directo". Por política, sólo
     * `cc-license` habilita el embed en la app.
     */
    public static function saneatPermisoStream($valorEntrada): string
    {
        $permitidos = ['none', 'cc-license', 'written-permission'];
        $limpio = sanitize_key((string) $valorEntrada);
        return in_array($limpio, $permitidos, true) ? $limpio : 'none';
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
     * Lista de IDs enteros positivos (por ejemplo, IDs de `fnh_source`
     * vinculadas a un colectivo). Deduplica, descarta no-enteros y
     * ceros/negativos.
     *
     * @param mixed $valorEntrada
     * @return list<int>
     */
    public static function sanearArrayEnteros($valorEntrada): array
    {
        if (!is_array($valorEntrada)) {
            return [];
        }
        $ids = [];
        foreach ($valorEntrada as $valor) {
            $entero = is_numeric($valor) ? (int) $valor : 0;
            if ($entero > 0) {
                $ids[] = $entero;
            }
        }
        return array_values(array_unique($ids));
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
