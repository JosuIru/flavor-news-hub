<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin;

use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Admin\Pages\SettingsPage;
use FlavorNewsHub\Admin\Pages\IngestLogPage;
use FlavorNewsHub\Admin\Pages\CatalogoPage;
use FlavorNewsHub\Admin\Pages\SistemaPage;
use FlavorNewsHub\Admin\Pages\EstadoFuentesPage;
use FlavorNewsHub\Admin\Pages\EstadisticasPage;

/**
 * Menú principal del plugin en el admin de WordPress.
 *
 * Antes había siete entradas (Resumen, Temáticas, Catálogo, Estado
 * de fuentes, Log de ingesta, Estadísticas, Ajustes) que en la
 * práctica respondían a tres tipos de pregunta:
 *
 *   - Estado y observabilidad → 4 pantallas que comparten el mismo
 *     contexto: ¿se usa la app?, ¿hay fuentes muertas?, ¿cuántas
 *     descargas hay?, ¿qué pasó en la última ingesta? Ahora se
 *     consolidan en una sola "Sistema" con tabs.
 *   - Configuración           → Ajustes (queda separado).
 *   - Datos editoriales       → Catálogo, Log de ingesta, Temáticas
 *     (siguen separados; cada uno es una pantalla densa con su
 *     propio propósito y mezclarlas con el dashboard las haría
 *     difíciles de encontrar).
 *
 * Los slugs antiguos `flavor-news-hub-stats` y `fnh-estado-fuentes`
 * los redirigimos a la tab correspondiente de Sistema desde
 * `redirigirSlugsAntiguos()` para no romper bookmarks.
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
            [SistemaPage::class, 'render'],
            'dashicons-rss',
            25
        );

        // Submenu Sistema (sobreescribe la entrada auto-añadida por add_menu_page).
        add_submenu_page(
            self::SLUG_MENU,
            __('Sistema', 'flavor-news-hub'),
            __('Sistema', 'flavor-news-hub'),
            'edit_posts',
            self::SLUG_MENU,
            [SistemaPage::class, 'render']
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
            __('Log de ingesta', 'flavor-news-hub'),
            __('Log de ingesta', 'flavor-news-hub'),
            'edit_posts',
            'fnh-ingest-log',
            [IngestLogPage::class, 'render']
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

    /**
     * Redirige los slugs antiguos (Estado de fuentes, Estadísticas,
     * Resumen explícito) a la tab apropiada del nuevo Sistema.
     *
     * Se engancha al hook `admin_init`. Llamamos `wp_safe_redirect` y
     * `exit` antes de que admin.php pinte nada — si el slug no
     * coincide con uno conocido, no hacemos nada y la request sigue
     * su curso normal.
     */
    public static function redirigirSlugsAntiguos(): void
    {
        if (!is_admin() || !isset($_GET['page'])) {
            return;
        }
        $paginaSolicitada = (string) $_GET['page'];
        $tabDestino = null;
        if ($paginaSolicitada === EstadoFuentesPage::SLUG) {
            $tabDestino = SistemaPage::TAB_FUENTES;
        } elseif ($paginaSolicitada === EstadisticasPage::SLUG) {
            $tabDestino = SistemaPage::TAB_DESCARGAS;
        }
        if ($tabDestino === null) {
            return;
        }
        // Conservamos cualquier query param adicional (avisos como
        // `fnh_duplicados_papelera=7`, paginadores, etc.) — si los
        // perdiéramos, los notices del admin no tendrían contexto al
        // pintarse en el slug nuevo.
        $parametrosOriginales = $_GET;
        unset($parametrosOriginales['page']);
        $parametrosFinales = array_merge($parametrosOriginales, [
            'page' => self::SLUG_MENU,
            'tab'  => $tabDestino,
        ]);
        wp_safe_redirect(add_query_arg($parametrosFinales, admin_url('admin.php')));
        exit;
    }
}
