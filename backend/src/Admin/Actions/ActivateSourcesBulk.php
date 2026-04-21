<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\CPT\Source;

/**
 * Bulk action "Verificar y activar" en la lista de medios.
 *
 * Análoga a `VerifyCollectivesBulk`: selecciona varios `fnh_source` en
 * estado `pending` (típicamente altas públicas vía POST /sources/submit)
 * y los publica con `_fnh_active=true` en un solo paso.
 */
final class ActivateSourcesBulk
{
    public const ACCION = 'fnh_activate_publish';

    /**
     * @param array<string,string> $acciones
     * @return array<string,string>
     */
    public static function registrarAccion(array $acciones): array
    {
        $acciones[self::ACCION] = __('Verificar y activar', 'flavor-news-hub');
        return $acciones;
    }

    /**
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
            if (!$post || $post->post_type !== Source::SLUG) {
                continue;
            }
            update_post_meta($idPost, '_fnh_active', true);
            wp_update_post([
                'ID'          => $idPost,
                'post_status' => 'publish',
            ]);
            $procesados++;
        }

        return add_query_arg('fnh_activated_count', $procesados, $urlRedirect);
    }

    public static function mostrarAviso(): void
    {
        if (!isset($_GET['fnh_activated_count'])) {
            return;
        }
        $cuenta = (int) $_GET['fnh_activated_count'];
        if ($cuenta <= 0) {
            return;
        }
        printf(
            '<div class="notice notice-success is-dismissible"><p>%s</p></div>',
            esc_html(sprintf(
                /* translators: %d = número de medios activados */
                _n(
                    '%d medio verificado y activado.',
                    '%d medios verificados y activados.',
                    $cuenta,
                    'flavor-news-hub'
                ),
                $cuenta
            ))
        );
    }
}
