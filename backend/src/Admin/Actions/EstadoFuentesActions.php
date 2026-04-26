<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\Admin\Pages\EstadoFuentesPage;
use FlavorNewsHub\Catalog\AutodescubrirFeeds;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Support\Transients;

/**
 * Acciones admin ligadas a la pantalla "Estado de fuentes":
 *  - Desactivar una fuente concreta (set `_fnh_active=false`).
 *  - Desactivar en bloque todas las caídas (error + total=0).
 *  - Aplicar correcciones conocidas de URL (CTXT, Cuarto Poder).
 *
 * Todas se enganchan a `admin-post.php` con nonce propio. Tras ejecutar
 * redirigen a la propia pantalla de estado con un query param para
 * renderizar el aviso de éxito.
 */
final class EstadoFuentesActions
{
    public const HOOK_DESACTIVAR_UNA       = 'admin_post_fnh_desactivar_fuente';
    public const HOOK_DESACTIVAR_CAIDAS    = 'admin_post_fnh_desactivar_caidas';
    public const HOOK_APLICAR_URLS         = 'admin_post_fnh_aplicar_urls_conocidas';
    public const HOOK_DETECTAR_FEEDS       = 'admin_post_fnh_detectar_feeds';
    public const HOOK_APLICAR_FEED_UNICO   = 'admin_post_fnh_aplicar_feed_detectado';
    public const HOOK_ELIMINAR_DUPLICADOS  = 'admin_post_fnh_eliminar_duplicados';

    /** Clave del transient donde se guardan las propuestas tras escanear. */
    public const TRANSIENT_PROPUESTAS = 'fnh_feeds_detectados_propuestas';

    /** Tope de fuentes a escanear por click — evita timeout en sitios con cientos de errores. */
    private const MAX_FUENTES_POR_ESCANEO = 60;

    /**
     * Mapa de correcciones de URL conocidas: slug del source → feed_url
     * nuevo. Identificadas manualmente tras el diagnóstico en vivo:
     * las URLs originales devolvían HTML/XML inválido; estas son los
     * feeds canónicos actuales de cada medio.
     */
    private const URLS_CONOCIDAS = [
        'ctxt'          => 'https://ctxt.es/es/rss',
        'cuarto-poder'  => 'https://www.cuartopoder.es/rss',
        // Carne Cruda dejó carnecruda.es y vive ahora dentro de
        // elDiario.es. Su feed está en /rss/carnecruda/ (no /feed/).
        'carne-cruda'   => 'https://www.eldiario.es/rss/carnecruda/',
        // News Minute: la URL del seed (/topic/rss) devuelve HTML; el
        // feed real es /feed (con content-type application/octet-stream
        // pero contenido XML válido).
        'the-news-minute' => 'https://www.thenewsminute.com/feed',
        // El Temps: el feed canónico está en /sindica (declarado en el
        // <link rel="alternate" type="application/rss+xml"> del HTML),
        // no en /feed/ — Cloudflare devolvía 404 con la URL antigua.
        'el-temps'        => 'https://www.eltemps.cat/sindica',
        // HispanTV: dejaron FeedBurner y publican feeds por categoría
        // (sección) en su servicio interno news.asmx. La página de
        // /rss expone una URL distinta por sección. Combinamos las
        // de mayor interés editorial para una audiencia hispana:
        //   1,2,11,12       → portada / titulares destacados
        //   4,5,6,14        → Irán
        //   18              → Asia Occidental
        //   44,53,130,131   → Europa
        //   61,69           → Centroamérica
        //   103-109         → Sudamérica
        //   80              → Opinión
        //   84              → Sociedad
        //   125             → Reportajes
        'hispantv'        => 'https://www.hispantv.com/services/news.asmx/Rss?category=1,2,4,5,6,11,12,14,18,44,53,61,69,80,84,103,104,105,106,107,108,109,125,130,131',
    ];

    public static function manejarDesactivarUna(): void
    {
        self::comprobarPermisos();
        $idSource = isset($_POST['source_id']) ? (int) $_POST['source_id'] : 0;
        if ($idSource <= 0) {
            wp_die(esc_html__('ID de medio inválido.', 'flavor-news-hub'), '', ['response' => 400]);
        }
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_desactivar_fuente_' . $idSource)) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }
        $post = get_post($idSource);
        if (!$post || $post->post_type !== Source::SLUG) {
            wp_die(esc_html__('Medio no encontrado.', 'flavor-news-hub'), '', ['response' => 404]);
        }
        update_post_meta($idSource, '_fnh_active', false);
        wp_safe_redirect(self::urlRedireccion(['fnh_desactivadas' => 1]));
        exit;
    }

    public static function manejarDesactivarCaidas(): void
    {
        self::comprobarPermisos();
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_desactivar_caidas')) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();

        // Candidatas: sources activas cuyo último log fue error, sin items
        // en histórico. Si ya han traído algo alguna vez, respetamos la
        // decisión del admin y no tocamos — puede ser flap temporal.
        $candidatasIds = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT p.ID
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pm_a ON pm_a.post_id = p.ID
                AND pm_a.meta_key = '_fnh_active' AND pm_a.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
               AND EXISTS (
                   SELECT 1 FROM {$logsTabla} il
                   WHERE il.source_id = p.ID AND il.status = 'error'
                     AND il.started_at = (
                         SELECT MAX(il2.started_at) FROM {$logsTabla} il2
                         WHERE il2.source_id = p.ID
                     )
               )
               AND NOT EXISTS (
                   SELECT 1 FROM {$wpdb->postmeta} pmi
                   INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                   WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                     AND pi.post_type = %s AND pi.post_status = 'publish'
                   LIMIT 1
               )",
            Source::SLUG,
            \FlavorNewsHub\CPT\Item::SLUG
        ));

        $desactivadas = 0;
        foreach ($candidatasIds as $id) {
            update_post_meta((int) $id, '_fnh_active', false);
            $desactivadas++;
        }

        wp_safe_redirect(self::urlRedireccion(['fnh_desactivadas' => $desactivadas]));
        exit;
    }

    public static function manejarAplicarUrls(): void
    {
        self::comprobarPermisos();
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_aplicar_urls_conocidas')) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        $aplicadas = 0;
        foreach (self::URLS_CONOCIDAS as $slug => $urlNueva) {
            $post = get_page_by_path($slug, OBJECT, Source::SLUG);
            if (!$post) continue;
            $urlActual = (string) get_post_meta($post->ID, '_fnh_feed_url', true);
            if ($urlActual === $urlNueva) continue;
            update_post_meta($post->ID, '_fnh_feed_url', $urlNueva);
            // También reactivamos si estaba desactivada por error previo.
            update_post_meta($post->ID, '_fnh_active', true);
            $aplicadas++;
        }
        wp_safe_redirect(self::urlRedireccion(['fnh_urls_aplicadas' => $aplicadas]));
        exit;
    }

    /**
     * Escanea las fuentes con error en la última ingesta o sin items en 30
     * días, intenta encontrar el feed real desde la URL declarada (vía
     * `<link rel="alternate">`) y guarda las propuestas en un transient
     * para que la pantalla las renderice.
     */
    public static function manejarDetectarFeeds(): void
    {
        self::comprobarPermisos();
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_detectar_feeds')) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        // Reset al re-escanear: si no, propuestas que el admin descartó
        // (CTXT en inglés, Carne Cruda al dominio muerto) seguirían
        // arrastrándose hasta que caduque el transient de 1h.
        delete_transient(self::TRANSIENT_PROPUESTAS);

        global $wpdb;
        $tablaLogs = IngestLogTable::nombreCompleto();

        // Candidatas: sources activas con último log = error, O sin items en
        // los últimos 30 días. No tocamos sanas para no malgastar requests.
        $idsCandidatas = $wpdb->get_col($wpdb->prepare(
            "SELECT p.ID FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
               AND (
                   EXISTS (
                       SELECT 1 FROM {$tablaLogs} il
                       WHERE il.source_id = p.ID AND il.status = 'error'
                         AND il.started_at = (
                             SELECT MAX(il2.started_at) FROM {$tablaLogs} il2
                             WHERE il2.source_id = p.ID
                         )
                   )
                   OR NOT EXISTS (
                       SELECT 1 FROM {$wpdb->postmeta} pmi
                       INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                       WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                         AND pi.post_type = %s AND pi.post_status = 'publish'
                         AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                       LIMIT 1
                   )
               )
             ORDER BY p.ID ASC
             LIMIT %d",
            Source::SLUG,
            \FlavorNewsHub\CPT\Item::SLUG,
            self::MAX_FUENTES_POR_ESCANEO
        ));

        $propuestasDetectadas = [];
        $cuentaEscaneadas = 0;
        foreach ($idsCandidatas as $idCandidata) {
            $idCandidata = (int) $idCandidata;
            $cuentaEscaneadas++;
            $urlFeedActual = (string) get_post_meta($idCandidata, '_fnh_feed_url', true);
            if ($urlFeedActual === '') {
                continue;
            }

            // Sólo proponemos si la nueva URL difiere de la actual.
            $deteccion = AutodescubrirFeeds::detectarDesdeUrl($urlFeedActual);
            if ($deteccion === null) {
                // Si la URL del feed no devuelve link rel=alternate (puede ser
                // que devuelva XML válido pero vacío, o un 404), probamos con
                // la homepage del medio.
                $urlSitioWeb = (string) get_post_meta($idCandidata, '_fnh_website_url', true);
                if ($urlSitioWeb !== '' && $urlSitioWeb !== $urlFeedActual) {
                    $deteccion = AutodescubrirFeeds::detectarDesdeUrl($urlSitioWeb);
                }
            }
            if ($deteccion === null) {
                continue;
            }
            [$urlFeedDetectado, $tipoFeedDetectado, $timestampUltimoItem] = $deteccion;
            if ($urlFeedDetectado === $urlFeedActual) {
                continue;
            }

            $propuestasDetectadas[$idCandidata] = [
                'source_id'         => $idCandidata,
                'nombre'            => get_the_title($idCandidata),
                'url_actual'        => $urlFeedActual,
                'url_detectada'     => $urlFeedDetectado,
                'tipo_detectado'    => $tipoFeedDetectado,
                'ultimo_item_ts'    => $timestampUltimoItem,
            ];
        }

        set_transient(self::TRANSIENT_PROPUESTAS, $propuestasDetectadas, Transients::PROPUESTAS_AUTODESCUBRIR);

        wp_safe_redirect(self::urlRedireccion([
            'fnh_feeds_escaneadas' => $cuentaEscaneadas,
            'fnh_feeds_detectados' => count($propuestasDetectadas),
        ]));
        exit;
    }

    /**
     * Aplica una propuesta concreta: actualiza `_fnh_feed_url` (y
     * opcionalmente `_fnh_feed_type`), reactiva la fuente y limpia esa
     * entrada del transient de propuestas.
     */
    public static function manejarAplicarFeedDetectado(): void
    {
        self::comprobarPermisos();
        $idSource = isset($_POST['source_id']) ? (int) $_POST['source_id'] : 0;
        if ($idSource <= 0) {
            wp_die(esc_html__('ID de medio inválido.', 'flavor-news-hub'), '', ['response' => 400]);
        }
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_aplicar_feed_detectado_' . $idSource)) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        $propuestasGuardadas = get_transient(self::TRANSIENT_PROPUESTAS);
        if (!is_array($propuestasGuardadas) || !isset($propuestasGuardadas[$idSource])) {
            wp_safe_redirect(self::urlRedireccion(['fnh_feed_aplicado' => 0]));
            exit;
        }
        $propuestaSeleccionada = $propuestasGuardadas[$idSource];
        $urlFeedNueva = (string) ($propuestaSeleccionada['url_detectada'] ?? '');
        $tipoFeedNuevo = (string) ($propuestaSeleccionada['tipo_detectado'] ?? '');
        if ($urlFeedNueva === '' || !filter_var($urlFeedNueva, FILTER_VALIDATE_URL)) {
            wp_safe_redirect(self::urlRedireccion(['fnh_feed_aplicado' => 0]));
            exit;
        }

        update_post_meta($idSource, '_fnh_feed_url', $urlFeedNueva);
        if (in_array($tipoFeedNuevo, ['rss', 'atom'], true)) {
            update_post_meta($idSource, '_fnh_feed_type', $tipoFeedNuevo);
        }
        update_post_meta($idSource, '_fnh_active', true);

        // Quitamos la propuesta aplicada del transient — así la lista en
        // pantalla decrece y se ve el progreso.
        unset($propuestasGuardadas[$idSource]);
        set_transient(self::TRANSIENT_PROPUESTAS, $propuestasGuardadas, Transients::PROPUESTAS_AUTODESCUBRIR);

        wp_safe_redirect(self::urlRedireccion(['fnh_feed_aplicado' => 1]));
        exit;
    }

    /**
     * Manda a papelera los duplicados de fuentes detectados —
     * mantiene el ID más bajo de cada par (el original) y manda a
     * papelera los demás. Considera duplicado:
     *   - Mismo `_fnh_feed_url` no vacío.
     * No usamos "mismo título" como criterio de borrado porque puede
     * haber medios homónimos legítimos en territorios distintos. La
     * sección de admin sí los muestra como aviso, pero el botón
     * automático sólo actúa sobre la condición fuerte (feed_url).
     *
     * Movemos a papelera, NO `wp_delete_post(force=true)`: por si la
     * heurística falla y un duplicado era legítimo, el admin puede
     * recuperarlo desde la papelera. SeedExcluidos también detecta el
     * trash y evita que el sync los recree.
     */
    public static function manejarEliminarDuplicados(): void
    {
        self::comprobarPermisos();
        $nonce = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonce, 'fnh_eliminar_duplicados')) {
            wp_die(esc_html__('Nonce inválido.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        global $wpdb;
        $paresDuplicados = $wpdb->get_results($wpdb->prepare(
            "SELECT pm.meta_value AS feed_url, GROUP_CONCAT(p.ID ORDER BY p.ID ASC) AS ids
             FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_fnh_feed_url'
               AND pm.meta_value != ''
               AND p.post_type = %s AND p.post_status = 'publish'
             GROUP BY pm.meta_value
             HAVING COUNT(*) > 1",
            Source::SLUG
        ), ARRAY_A);

        $cuentaPapelera = 0;
        foreach (is_array($paresDuplicados) ? $paresDuplicados : [] as $par) {
            $idsDelPar = array_filter(array_map('intval', explode(',', (string) $par['ids'])));
            if (count($idsDelPar) < 2) continue;
            // Mantenemos el primer ID (el más bajo, el original) y
            // mandamos a papelera el resto.
            array_shift($idsDelPar);
            foreach ($idsDelPar as $idAEliminar) {
                if (wp_trash_post((int) $idAEliminar)) {
                    $cuentaPapelera++;
                }
            }
        }

        wp_safe_redirect(self::urlRedireccion(['fnh_duplicados_papelera' => $cuentaPapelera]));
        exit;
    }

    public static function mostrarAviso(): void
    {
        $pantallaActual = isset($_GET['page']) ? sanitize_key((string) wp_unslash($_GET['page'])) : '';
        if ($pantallaActual !== EstadoFuentesPage::SLUG) {
            return;
        }
        if (isset($_GET['fnh_desactivadas'])) {
            $n = (int) $_GET['fnh_desactivadas'];
            if ($n > 0) {
                printf(
                    '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                    esc_html(sprintf(
                        /* translators: %d cuenta de fuentes desactivadas */
                        _n('%d fuente desactivada.', '%d fuentes desactivadas.', $n, 'flavor-news-hub'),
                        $n
                    ))
                );
            } else {
                printf(
                    '<div class="notice notice-info is-dismissible"><p>%s</p></div>',
                    esc_html__('No había fuentes caídas que desactivar.', 'flavor-news-hub')
                );
            }
        }
        if (isset($_GET['fnh_duplicados_papelera'])) {
            $cuentaPapelera = (int) $_GET['fnh_duplicados_papelera'];
            if ($cuentaPapelera > 0) {
                printf(
                    '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                    esc_html(sprintf(
                        /* translators: %d duplicados enviados a papelera */
                        _n('%d fuente duplicada enviada a la papelera.', '%d fuentes duplicadas enviadas a la papelera.', $cuentaPapelera, 'flavor-news-hub'),
                        $cuentaPapelera
                    ))
                );
            } else {
                printf(
                    '<div class="notice notice-info is-dismissible"><p>%s</p></div>',
                    esc_html__('No había duplicados por feed_url para eliminar.', 'flavor-news-hub')
                );
            }
        }
        if (isset($_GET['fnh_feeds_escaneadas'])) {
            $cuentaEscaneadas = (int) $_GET['fnh_feeds_escaneadas'];
            $cuentaDetectados = isset($_GET['fnh_feeds_detectados']) ? (int) $_GET['fnh_feeds_detectados'] : 0;
            printf(
                '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                esc_html(sprintf(
                    /* translators: %1$d fuentes escaneadas, %2$d feeds detectados */
                    __('Escaneadas %1$d fuentes con error o muertas — detectados %2$d feeds nuevos. Revísalos abajo y aplica los que correspondan.', 'flavor-news-hub'),
                    $cuentaEscaneadas,
                    $cuentaDetectados
                ))
            );
        }
        if (isset($_GET['fnh_feed_aplicado'])) {
            $aplicado = (int) $_GET['fnh_feed_aplicado'];
            if ($aplicado > 0) {
                printf(
                    '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                    esc_html__('Feed actualizado y fuente reactivada. Lánzale ingesta para confirmar que funciona.', 'flavor-news-hub')
                );
            } else {
                printf(
                    '<div class="notice notice-error is-dismissible"><p>%s</p></div>',
                    esc_html__('No se pudo aplicar el feed: la propuesta ha caducado o no es válida.', 'flavor-news-hub')
                );
            }
        }
        if (isset($_GET['fnh_urls_aplicadas'])) {
            $n = (int) $_GET['fnh_urls_aplicadas'];
            if ($n > 0) {
                printf(
                    '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                    esc_html(sprintf(
                        /* translators: %d URLs corregidas */
                        _n('%d URL de feed corregida.', '%d URLs de feed corregidas.', $n, 'flavor-news-hub'),
                        $n
                    ))
                );
            } else {
                printf(
                    '<div class="notice notice-info is-dismissible"><p>%s</p></div>',
                    esc_html__('Las URLs conocidas ya estaban aplicadas.', 'flavor-news-hub')
                );
            }
        }
    }

    private static function comprobarPermisos(): void
    {
        if (!current_user_can('manage_options')) {
            wp_die(esc_html__('Permiso denegado.', 'flavor-news-hub'), '', ['response' => 403]);
        }
    }

    /** @param array<string,int|string> $extra */
    private static function urlRedireccion(array $extra): string
    {
        return add_query_arg(
            array_merge(['page' => EstadoFuentesPage::SLUG], $extra),
            admin_url('admin.php')
        );
    }
}
