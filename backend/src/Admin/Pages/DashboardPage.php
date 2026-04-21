<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\Database\IngestLogTable;

/**
 * Pantalla "Resumen" del menú principal. Muestra contadores básicos y
 * la última fila de ingesta para cada fuente activa.
 */
final class DashboardPage
{
    public static function render(): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        $numeroFuentes = wp_count_posts(Source::SLUG);
        $numeroItems = wp_count_posts(Item::SLUG);
        $numeroColectivos = wp_count_posts(Collective::SLUG);

        $totalFuentes = (int) ($numeroFuentes->publish ?? 0);
        $totalItems = (int) ($numeroItems->publish ?? 0);
        $totalColectivosPublicados = (int) ($numeroColectivos->publish ?? 0);
        $totalColectivosPendientes = (int) ($numeroColectivos->pending ?? 0);

        global $wpdb;
        $nombreTablaLog = IngestLogTable::nombreCompleto();
        $filasLogRecientes = $wpdb->get_results(
            "SELECT l.source_id, l.status, l.started_at, l.items_new, l.items_skipped, l.error_message, p.post_title
             FROM {$nombreTablaLog} l
             LEFT JOIN {$wpdb->posts} p ON p.ID = l.source_id
             ORDER BY l.started_at DESC
             LIMIT 10"
        );

        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Flavor News Hub', 'flavor-news-hub'); ?></h1>
            <p class="description">
                <?php esc_html_e('Backend headless: agrega medios alternativos y lista colectivos organizados. Consulta el manifiesto del proyecto para entender qué entra aquí y qué no.', 'flavor-news-hub'); ?>
            </p>

            <div style="display:flex; gap:1em; margin:1em 0; flex-wrap:wrap;">
                <?php
                self::renderTarjeta(__('Medios', 'flavor-news-hub'), (string) $totalFuentes, 'edit.php?post_type=' . Source::SLUG);
                self::renderTarjeta(__('Noticias', 'flavor-news-hub'), (string) $totalItems, 'edit.php?post_type=' . Item::SLUG);
                self::renderTarjeta(__('Colectivos publicados', 'flavor-news-hub'), (string) $totalColectivosPublicados, 'edit.php?post_type=' . Collective::SLUG);
                self::renderTarjeta(
                    __('Colectivos pendientes de verificar', 'flavor-news-hub'),
                    (string) $totalColectivosPendientes,
                    'edit.php?post_status=pending&post_type=' . Collective::SLUG
                );
                ?>
            </div>

            <h2><?php esc_html_e('Últimas ingestas', 'flavor-news-hub'); ?></h2>
            <?php if (empty($filasLogRecientes)) : ?>
                <p><?php esc_html_e('Todavía no hay registros de ingesta. Se crearán en cuanto el cron ejecute, o lanzando manualmente "Ingest now" desde un medio.', 'flavor-news-hub'); ?></p>
            <?php else : ?>
                <table class="widefat striped">
                    <thead>
                        <tr>
                            <th><?php esc_html_e('Medio', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Estado', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Inicio', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Nuevos', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Descartados', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Error', 'flavor-news-hub'); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                    <?php foreach ($filasLogRecientes as $fila) : ?>
                        <tr>
                            <td><?php echo esc_html($fila->post_title ?? ('#' . $fila->source_id)); ?></td>
                            <td><?php echo esc_html($fila->status); ?></td>
                            <td><?php echo esc_html($fila->started_at); ?></td>
                            <td><?php echo (int) $fila->items_new; ?></td>
                            <td><?php echo (int) $fila->items_skipped; ?></td>
                            <td><?php echo esc_html((string) ($fila->error_message ?? '')); ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
        <?php
    }

    private static function renderTarjeta(string $titulo, string $valor, string $urlDestino): void
    {
        ?>
        <a href="<?php echo esc_url(admin_url($urlDestino)); ?>" style="text-decoration:none; color:inherit;">
            <div style="background:#fff; border:1px solid #ccd0d4; padding:1em 1.5em; min-width:180px; border-radius:4px;">
                <div style="font-size:0.85em; color:#666;"><?php echo esc_html($titulo); ?></div>
                <div style="font-size:1.8em; font-weight:600; margin-top:.2em;"><?php echo esc_html($valor); ?></div>
            </div>
        </a>
        <?php
    }
}
