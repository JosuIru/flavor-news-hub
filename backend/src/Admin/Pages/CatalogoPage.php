<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Catalog\CatalogoPorDefecto;
use FlavorNewsHub\Catalog\ImportadorCatalogo;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Radio;

/**
 * Pantalla admin "Catálogo": lista el seed curado que viaja con el
 * plugin (el mismo catálogo que usa la app Flutter) y permite al admin
 * activar fuentes/radios con un clic. Cada entrada muestra su estado
 * (si ya existe como post o no) y se puede seleccionar por checkbox
 * para una importación parcial.
 *
 * Pensado para "ponerse en marcha rápido": tras instalar el plugin,
 * el admin entra aquí, marca los que le interesan y le da a importar.
 * El `FeedIngester` hará su trabajo periódico con esos.
 */
final class CatalogoPage
{
    public const SLUG = 'fnh-catalogo';
    public const NONCE_ACCION = 'fnh_catalogo_importar';

    public static function render(): void
    {
        if (!current_user_can('manage_options')) {
            wp_die(__('No tienes permisos para ver esta página.', 'flavor-news-hub'));
        }

        self::procesarAccionSiCorresponde();

        $tabActiva = isset($_GET['tab']) ? sanitize_key((string) $_GET['tab']) : 'sources';
        if (!in_array($tabActiva, ['sources', 'radios'], true)) {
            $tabActiva = 'sources';
        }

        echo '<div class="wrap">';
        echo '<h1>' . esc_html__('Catálogo por defecto', 'flavor-news-hub') . '</h1>';
        echo '<p class="description">' . esc_html__(
            'Este catálogo viaja con el plugin y es el mismo que usa la app. Marca los medios que quieras activar en tu instancia y pulsa "Importar seleccionados". Puedes re-importar más tarde para recibir cambios — sólo crea los nuevos.',
            'flavor-news-hub'
        ) . '</p>';

        // Tabs
        $urlBase = admin_url('admin.php?page=' . self::SLUG);
        echo '<h2 class="nav-tab-wrapper">';
        printf(
            '<a href="%s" class="nav-tab %s">%s</a>',
            esc_url(add_query_arg('tab', 'sources', $urlBase)),
            $tabActiva === 'sources' ? 'nav-tab-active' : '',
            esc_html__('Fuentes', 'flavor-news-hub')
        );
        printf(
            '<a href="%s" class="nav-tab %s">%s</a>',
            esc_url(add_query_arg('tab', 'radios', $urlBase)),
            $tabActiva === 'radios' ? 'nav-tab-active' : '',
            esc_html__('Radios', 'flavor-news-hub')
        );
        echo '</h2>';

        self::renderizarTab($tabActiva);

        echo '</div>';
    }

    private static function renderizarTab(string $tab): void
    {
        $datos = $tab === 'sources'
            ? CatalogoPorDefecto::sources()
            : CatalogoPorDefecto::radios();

        if (empty($datos)) {
            echo '<p>' . esc_html__('No hay entradas en el catálogo por defecto para esta pestaña.', 'flavor-news-hub') . '</p>';
            return;
        }

        $cptSlug = $tab === 'sources' ? Source::SLUG : Radio::SLUG;
        // Mapa slug → post_id para saber cuáles ya están importados.
        $slugsJson = array_map(
            static fn(array $x): string => (string) ($x['slug'] ?? ''),
            $datos
        );
        $existentesMapa = self::mapaExistentesPorSlug($cptSlug, $slugsJson);

        $totalJson = count($datos);
        $totalExistentes = count($existentesMapa);
        $totalPendientes = $totalJson - $totalExistentes;

        echo '<p>' . sprintf(
            esc_html__(
                'Catálogo: %1$d entradas. Ya instaladas: %2$d. Pendientes: %3$d.',
                'flavor-news-hub'
            ),
            $totalJson,
            $totalExistentes,
            $totalPendientes
        ) . '</p>';

        echo '<form method="post">';
        wp_nonce_field(self::NONCE_ACCION);
        echo '<input type="hidden" name="fnh_catalogo_tab" value="' . esc_attr($tab) . '" />';

        echo '<div style="margin: 12px 0;">';
        echo '<label><input type="checkbox" name="fnh_catalogo_actualizar" value="1" /> ';
        echo esc_html__(
            'Sobrescribir metas de los que ya existen (mantiene tus cambios si no marcas esto).',
            'flavor-news-hub'
        );
        echo '</label>';
        echo '</div>';

        echo '<p>';
        submit_button(
            __('Importar seleccionados', 'flavor-news-hub'),
            'primary',
            'fnh_catalogo_importar_seleccion',
            false
        );
        echo ' ';
        submit_button(
            __('Importar todos los pendientes', 'flavor-news-hub'),
            'secondary',
            'fnh_catalogo_importar_todos',
            false
        );
        echo '</p>';

        echo '<table class="widefat striped">';
        echo '<thead><tr>';
        echo '<td style="width:32px;"><input type="checkbox" id="fnh-check-all" /></td>';
        echo '<th>' . esc_html__('Nombre', 'flavor-news-hub') . '</th>';
        echo '<th>' . esc_html__('Territorio', 'flavor-news-hub') . '</th>';
        echo '<th>' . esc_html__('Idiomas', 'flavor-news-hub') . '</th>';
        if ($tab === 'sources') {
            echo '<th>' . esc_html__('Tipo', 'flavor-news-hub') . '</th>';
            echo '<th>' . esc_html__('URL del feed', 'flavor-news-hub') . '</th>';
        } else {
            echo '<th>' . esc_html__('Stream', 'flavor-news-hub') . '</th>';
        }
        echo '<th>' . esc_html__('Estado', 'flavor-news-hub') . '</th>';
        echo '</tr></thead><tbody>';

        foreach ($datos as $entry) {
            $slug = (string) ($entry['slug'] ?? '');
            if ($slug === '') continue;
            $existe = isset($existentesMapa[$slug]);

            echo '<tr>';
            echo '<td>';
            if (!$existe) {
                printf(
                    '<input type="checkbox" name="slugs[]" value="%s" />',
                    esc_attr($slug)
                );
            }
            echo '</td>';
            echo '<td><strong>' . esc_html((string) ($entry['name'] ?? '')) . '</strong></td>';
            echo '<td>' . esc_html((string) ($entry['territory'] ?? '')) . '</td>';
            $idiomas = $entry['languages'] ?? [];
            echo '<td>' . esc_html(is_array($idiomas) ? implode(', ', $idiomas) : '') . '</td>';
            if ($tab === 'sources') {
                echo '<td>' . esc_html((string) ($entry['feed_type'] ?? 'rss')) . '</td>';
                echo '<td><code style="font-size:11px;">' . esc_html((string) ($entry['feed_url'] ?? '')) . '</code></td>';
            } else {
                echo '<td><code style="font-size:11px;">' . esc_html((string) ($entry['stream_url'] ?? '')) . '</code></td>';
            }
            echo '<td>';
            if ($existe) {
                $urlEdicion = get_edit_post_link($existentesMapa[$slug]);
                printf(
                    '<a href="%s">%s</a>',
                    esc_url((string) $urlEdicion),
                    esc_html__('Ya instalada — editar', 'flavor-news-hub')
                );
            } else {
                echo '<span style="color:#777;">' . esc_html__('Pendiente', 'flavor-news-hub') . '</span>';
            }
            echo '</td>';
            echo '</tr>';
        }

        echo '</tbody></table>';

        echo '</form>';

        // Pequeño JS para el "select all" — sin dependencias.
        echo '<script>(function(){var c=document.getElementById("fnh-check-all");';
        echo 'if(!c)return;c.addEventListener("change",function(){';
        echo 'document.querySelectorAll(\'input[name="slugs[]"]\').forEach(function(x){x.checked=c.checked;});});})();</script>';
    }

    /**
     * @param list<string> $slugs
     * @return array<string,int>
     */
    private static function mapaExistentesPorSlug(string $cptSlug, array $slugs): array
    {
        if (empty($slugs)) return [];
        // `get_page_by_path` funciona con CPTs; para rendimiento hacemos
        // una única query por slugs en batch.
        global $wpdb;
        $placeholders = implode(',', array_fill(0, count($slugs), '%s'));
        $params = array_merge([$cptSlug], $slugs);
        $filas = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT ID, post_name FROM {$wpdb->posts}
                 WHERE post_type = %s AND post_name IN ($placeholders)",
                ...$params
            )
        );
        $mapa = [];
        foreach ($filas as $f) {
            $mapa[(string) $f->post_name] = (int) $f->ID;
        }
        return $mapa;
    }

    private static function procesarAccionSiCorresponde(): void
    {
        if (!isset($_POST['fnh_catalogo_tab'])) return;
        check_admin_referer(self::NONCE_ACCION);

        $tab = sanitize_key((string) $_POST['fnh_catalogo_tab']);
        $actualizar = !empty($_POST['fnh_catalogo_actualizar']);

        $importarTodos = isset($_POST['fnh_catalogo_importar_todos']);
        $slugs = $_POST['slugs'] ?? [];
        if (!is_array($slugs)) $slugs = [];
        $slugs = array_values(array_filter(array_map('sanitize_title', $slugs)));

        if (!$importarTodos && empty($slugs)) {
            add_settings_error(
                'fnh_catalogo',
                'vacio',
                __('No seleccionaste ninguna entrada para importar.', 'flavor-news-hub'),
                'warning'
            );
            settings_errors('fnh_catalogo');
            return;
        }

        $filtro = $importarTodos ? null : $slugs;
        $datos = $tab === 'sources'
            ? CatalogoPorDefecto::sources()
            : CatalogoPorDefecto::radios();

        $resultado = $tab === 'sources'
            ? ImportadorCatalogo::importarSources($datos, $actualizar, $filtro)
            : ImportadorCatalogo::importarRadios($datos, $actualizar, $filtro);

        add_settings_error(
            'fnh_catalogo',
            'ok',
            sprintf(
                esc_html__(
                    'Importación completada: %1$d nuevas, %2$d actualizadas, %3$d saltadas.',
                    'flavor-news-hub'
                ),
                $resultado['creados'],
                $resultado['actualizados'],
                $resultado['saltados']
            ),
            'updated'
        );
        if (!empty($resultado['errores'])) {
            add_settings_error(
                'fnh_catalogo',
                'errores',
                implode(' · ', $resultado['errores']),
                'error'
            );
        }
        settings_errors('fnh_catalogo');
    }
}
