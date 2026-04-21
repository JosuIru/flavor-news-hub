<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\CPT\Collective;

/**
 * Bulk action "Verify and publish" en la lista de colectivos.
 *
 * Selecciona varios pending desde edit.php y los marca como verified +
 * publish en un solo paso. El número de colectivos procesados se pasa por
 * query string al redirect para mostrar un aviso.
 */
final class VerifyCollectivesBulk
{
    public const ACCION = 'fnh_verify_publish';

    /**
     * @param array<string,string> $acciones
     * @return array<string,string>
     */
    public static function registrarAccion(array $acciones): array
    {
        $acciones[self::ACCION] = __('Verificar y publicar', 'flavor-news-hub');
        return $acciones;
    }

    /**
     * Handler de la bulk action. Recibe la URL de redirect, la acción
     * elegida y los IDs seleccionados. Debe devolver la URL modificada.
     *
     * @param string $urlRedirect
     * @param string $accionElegida
     * @param list<int> $idsSeleccionados
     */
    public static function manejar(string $urlRedirect, string $accionElegida, array $idsSeleccionados): string
    {
        if ($accionElegida !== self::ACCION) {
            return $urlRedirect;
        }
        if (!current_user_can('edit_others_posts')) {
            return $urlRedirect;
        }

        $procesados = 0;
        foreach ($idsSeleccionados as $idPost) {
            $idPost = (int) $idPost;
            $post = get_post($idPost);
            if (!$post || $post->post_type !== Collective::SLUG) {
                continue;
            }
            update_post_meta($idPost, '_fnh_verified', true);
            wp_update_post([
                'ID'          => $idPost,
                'post_status' => 'publish',
            ]);
            $procesados++;
        }

        return add_query_arg('fnh_verified_count', $procesados, $urlRedirect);
    }

    /**
     * Aviso en edit.php tras ejecutar la bulk action.
     */
    public static function mostrarAviso(): void
    {
        if (!isset($_GET['fnh_verified_count'])) {
            return;
        }
        $cuentaProcesados = (int) $_GET['fnh_verified_count'];
        if ($cuentaProcesados <= 0) {
            return;
        }
        printf(
            '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
            esc_html(sprintf(
                /* translators: %d = número de colectivos verificados */
                _n(
                    '%d colectivo verificado y publicado.',
                    '%d colectivos verificados y publicados.',
                    $cuentaProcesados,
                    'flavor-news-hub'
                ),
                $cuentaProcesados
            ))
        );
    }
}
