<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Actions;

use FlavorNewsHub\Catalog\CreadorPaginas;

/**
 * Handler del botón "Crear páginas que faltan" de la pantalla de ajustes.
 *
 * Se engancha a `admin_post_fnh_crear_paginas`. Verifica nonce y permisos,
 * llama a CreadorPaginas::crearSiNoExisten() y redirige de vuelta a ajustes.
 */
final class CrearPaginasHandler
{
    public const HOOK_ADMIN_POST = 'admin_post_fnh_crear_paginas';
    public const NONCE_ACCION    = 'fnh_crear_paginas';

    public static function manejar(): void
    {
        if (!current_user_can('manage_options')) {
            wp_die(esc_html__('Permiso denegado.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        $nonceEnviado = isset($_POST['_wpnonce']) ? (string) wp_unslash($_POST['_wpnonce']) : '';
        if (!wp_verify_nonce($nonceEnviado, self::NONCE_ACCION)) {
            wp_die(esc_html__('Nonce inválido o caducado.', 'flavor-news-hub'), '', ['response' => 403]);
        }

        CreadorPaginas::crearSiNoExisten();

        wp_safe_redirect(add_query_arg(
            ['fnh_paginas_result' => 'ok'],
            admin_url('admin.php?page=fnh-settings')
        ));
        exit;
    }

    public static function mostrarAviso(): void
    {
        $pantalla = get_current_screen();
        if (!$pantalla || $pantalla->id !== 'flavor-news-hub_page_fnh-settings') {
            return;
        }
        if (!isset($_GET['fnh_paginas_result'])) {
            return;
        }
        echo '<div class="notice notice-success is-dismissible"><p>'
            . esc_html__('Las páginas de frontend han sido creadas o actualizadas.', 'flavor-news-hub')
            . '</p></div>';
    }
}
