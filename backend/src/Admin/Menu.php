<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin;

use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Admin\Pages\SettingsPage;
use FlavorNewsHub\Admin\Pages\IngestLogPage;
use FlavorNewsHub\Admin\Pages\DashboardPage;
use FlavorNewsHub\Admin\Pages\CatalogoPage;
use FlavorNewsHub\Admin\Pages\EstadoFuentesPage;
use FlavorNewsHub\Admin\Pages\EstadisticasPage;

/**
 * Menú principal del plugin en el admin de WordPress.
 *
 * Los 3 CPTs se anidan como submenús mediante `show_in_menu => 'flavor-news-hub'`
 * en su registro. Aquí añadimos el menú padre, el dashboard, el listado de
 * temáticas (enlace a la pantalla estándar de taxonomía), el log de ingesta
 * y la pantalla de ajustes.
 */
final class Menu
{
    public const SLUG_MENU = 'flavor-news-hub';

    public static function registrar(): void
    {
        add_menu_page(
            __('Flavor News Hub', 'flavor-news-hub'),
            __('Flavor News Hub', 'flavor-news-hub'),
            'edit_posts',
            self::SLUG_MENU,
            [DashboardPage::class, 'render'],
            'dashicons-rss',
            25
        );

        // Submenu Dashboard (sobreescribe la entrada auto-añadida por add_menu_page).
        add_submenu_page(
            self::SLUG_MENU,
            __('Resumen', 'flavor-news-hub'),
            __('Resumen', 'flavor-news-hub'),
            'edit_posts',
            self::SLUG_MENU,
            [DashboardPage::class, 'render']
        );

        // Enlace a la pantalla estándar de términos para la taxonomía.
        add_submenu_page(
            self::SLUG_MENU,
            __('Temáticas', 'flavor-news-hub'),
            __('Temáticas', 'flavor-news-hub'),
            'manage_categories',
            'edit-tags.php?taxonomy=' . Topic::SLUG
        );

        add_submenu_page(
            self::SLUG_MENU,
            __('Catálogo por defecto', 'flavor-news-hub'),
            __('Catálogo', 'flavor-news-hub'),
            'manage_options',
            CatalogoPage::SLUG,
            [CatalogoPage::class, 'render']
        );

        add_submenu_page(
            self::SLUG_MENU,
            __('Estado de fuentes', 'flavor-news-hub'),
            __('Estado de fuentes', 'flavor-news-hub'),
            'edit_posts',
            EstadoFuentesPage::SLUG,
            [EstadoFuentesPage::class, 'render']
        );

        add_submenu_page(
            self::SLUG_MENU,
            __('Log de ingesta', 'flavor-news-hub'),
            __('Log de ingesta', 'flavor-news-hub'),
            'edit_posts',
            'fnh-ingest-log',
            [IngestLogPage::class, 'render']
        );

        add_submenu_page(
            self::SLUG_MENU,
            __('Estadísticas', 'flavor-news-hub'),
            __('Estadísticas', 'flavor-news-hub'),
            'edit_posts',
            EstadisticasPage::SLUG,
            [EstadisticasPage::class, 'render']
        );

        add_submenu_page(
            self::SLUG_MENU,
            __('Ajustes', 'flavor-news-hub'),
            __('Ajustes', 'flavor-news-hub'),
            'manage_options',
            'fnh-settings',
            [SettingsPage::class, 'render']
        );
    }
}
