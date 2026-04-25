<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Admin\Menu;
use FlavorNewsHub\Admin\MetaBoxes\SourceMetaBox;
use FlavorNewsHub\Admin\MetaBoxes\ItemMetaBox;
use FlavorNewsHub\Admin\MetaBoxes\CollectiveMetaBox;
use FlavorNewsHub\Admin\MetaBoxes\RadioMetaBox;
use FlavorNewsHub\Admin\Actions\IngestNowHandler;
use FlavorNewsHub\Admin\Actions\CrearPaginasHandler;
use FlavorNewsHub\Admin\Actions\VerifyCollectivesBulk;
use FlavorNewsHub\Admin\Actions\ActivateSourcesBulk;
use FlavorNewsHub\Admin\Actions\EstadoFuentesActions;
use FlavorNewsHub\Admin\Hooks\SourceDefaults;
use FlavorNewsHub\Admin\Pages\SettingsPage;

/**
 * Orquestador del admin. Llamado desde Plugin::arrancar().
 *
 * Registrar todos estos hooks desde el frontend es inofensivo (los hooks
 * `admin_*` no disparan fuera del admin), así que no hace falta envolverlo
 * en `is_admin()`.
 */
final class AdminController
{
    public static function arrancar(): void
    {
        // Menú principal y pantallas propias.
        add_action('admin_menu', [Menu::class, 'registrar']);
        add_action('admin_init', [SettingsPage::class, 'registrarAjustes']);

        // Metaboxes.
        add_action('add_meta_boxes', [SourceMetaBox::class, 'registrar']);
        add_action('add_meta_boxes', [ItemMetaBox::class, 'registrar']);
        add_action('add_meta_boxes', [CollectiveMetaBox::class, 'registrar']);
        add_action('add_meta_boxes', [RadioMetaBox::class, 'registrar']);

        // Guardado de metaboxes.
        add_action('save_post_' . Source::SLUG, [SourceMetaBox::class, 'guardar'], 10, 2);
        add_action('save_post_' . Collective::SLUG, [CollectiveMetaBox::class, 'guardar'], 10, 2);
        add_action('save_post_' . Radio::SLUG, [RadioMetaBox::class, 'guardar'], 10, 2);

        // Defaults de source: se aplican DESPUÉS del save del metabox.
        add_action('save_post_' . Source::SLUG, [SourceDefaults::class, 'aplicarDefaults'], 20, 2);

        // Ingest now: admin-post endpoint.
        add_action(IngestNowHandler::HOOK_ADMIN_POST, [IngestNowHandler::class, 'manejar']);
        add_action('admin_notices', [IngestNowHandler::class, 'mostrarAvisoTrasIngesta']);

        // Crear páginas de frontend: admin-post endpoint.
        add_action(CrearPaginasHandler::HOOK_ADMIN_POST, [CrearPaginasHandler::class, 'manejar']);
        add_action('admin_notices', [CrearPaginasHandler::class, 'mostrarAviso']);

        // Bulk action "Verify and publish" en la lista de colectivos.
        add_filter('bulk_actions-edit-' . Collective::SLUG, [VerifyCollectivesBulk::class, 'registrarAccion']);
        add_filter('handle_bulk_actions-edit-' . Collective::SLUG, [VerifyCollectivesBulk::class, 'manejar'], 10, 3);
        add_action('admin_notices', [VerifyCollectivesBulk::class, 'mostrarAviso']);

        // Bulk action "Verificar y activar" en la lista de medios.
        add_filter('bulk_actions-edit-' . Source::SLUG, [ActivateSourcesBulk::class, 'registrarAccion']);
        add_filter('handle_bulk_actions-edit-' . Source::SLUG, [ActivateSourcesBulk::class, 'manejar'], 10, 3);
        add_action('admin_notices', [ActivateSourcesBulk::class, 'mostrarAviso']);

        // Acciones desde la pantalla "Estado de fuentes": desactivar una,
        // desactivar todas las caídas, aplicar URLs corregidas conocidas.
        add_action(EstadoFuentesActions::HOOK_DESACTIVAR_UNA, [EstadoFuentesActions::class, 'manejarDesactivarUna']);
        add_action(EstadoFuentesActions::HOOK_DESACTIVAR_CAIDAS, [EstadoFuentesActions::class, 'manejarDesactivarCaidas']);
        add_action(EstadoFuentesActions::HOOK_APLICAR_URLS, [EstadoFuentesActions::class, 'manejarAplicarUrls']);
        add_action('admin_notices', [EstadoFuentesActions::class, 'mostrarAviso']);
    }
}
