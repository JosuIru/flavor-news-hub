<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Ingest\FeedIngester;

/**
 * Handler del botón "Ingest now" del metabox de sources.
 *
 * Se engancha a `admin_post_fnh_ingest_source`. Verifica nonce y permisos,
 * dispara la ingesta de una fuente concreta, y redirige de vuelta al editor
 * con un aviso en la query string.
 */
final class IngestNowHandler
{
    public const HOOK_ADMIN_POST = 'admin_post_fnh_ingest_source';

    public static function manejar(): void
    {
        if (!current_user_can('edit_posts')) {
            wp_die(esc_html__('Permiso denegado.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        $idSource = isset($_POST['source_id']) ? (int) $_POST['source_id'] : 0;
        if ($idSource <= 0) {
            wp_die(esc_html__('ID de medio inválido.', 'flavor-news-hub'), '', ['response' => 400]);
        }

        $nonceEnviado = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonceEnviado, 'fnh_ingest_source_' . $idSource)) {
            wp_die(esc_html__('Nonce inválido o caducado.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        $postFuente = get_post($idSource);
        if (!$postFuente || $postFuente->post_type !== Source::SLUG) {
            wp_die(esc_html__('Medio no encontrado.', 'flavor-news-hub'), '', ['response' => 404]);
        }

        $resumen = FeedIngester::ingestarFuente($idSource);

        $urlRedireccion = add_query_arg(
            [
                'fnh_ingest_result' => $resumen['error'] !== '' ? 'error' : 'ok',
                'fnh_new'           => (int) $resumen['items_new'],
                'fnh_skipped'       => (int) $resumen['items_skipped'],
            ],
            get_edit_post_link($idSource, 'url')
        );

        wp_safe_redirect($urlRedireccion);
        exit;
    }

    /**
     * Aviso `admin_notices` tras redirect: lee los parámetros de resultado
     * y muestra un banner con el desenlace de la ingesta.
     */
    public static function mostrarAvisoTrasIngesta(): void
    {
        if (!isset($_GET['fnh_ingest_result'])) {
            return;
        }
        $resultado = sanitize_key((string) wp_unslash($_GET['fnh_ingest_result']));
        $nuevos = isset($_GET['fnh_new']) ? (int) $_GET['fnh_new'] : 0;
        $descartados = isset($_GET['fnh_skipped']) ? (int) $_GET['fnh_skipped'] : 0;

        if ($resultado === 'ok') {
            printf(
                '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
                esc_html(sprintf(
                    /* translators: 1 = nuevos, 2 = descartados */
                    __('Ingesta manual OK. Nuevos: %1$d. Descartados por dedupe: %2$d.', 'flavor-news-hub'),
                    $nuevos,
                    $descartados
                ))
            );
        } elseif ($resultado === 'error') {
            printf(
                '<div class="notice notice-error is-dismissible"><p>%s</p></div>',
                esc_html__('La ingesta manual ha fallado. Revisa el log para ver el motivo.', 'flavor-news-hub')
            );
        }
    }
}
