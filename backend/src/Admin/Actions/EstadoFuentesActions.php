<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\Admin\Pages\EstadoFuentesPage;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Database\IngestLogTable;

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
    public const HOOK_DESACTIVAR_UNA    = 'admin_post_fnh_desactivar_fuente';
    public const HOOK_DESACTIVAR_CAIDAS = 'admin_post_fnh_desactivar_caidas';
    public const HOOK_APLICAR_URLS      = 'admin_post_fnh_aplicar_urls_conocidas';

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
