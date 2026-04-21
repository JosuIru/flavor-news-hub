<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Database\IngestLogTable;

/**
 * Pantalla de log de ingesta. Tabla paginada con las últimas ejecuciones
 * filtrables por estado (running / success / error).
 */
final class IngestLogPage
{
    public const POR_PAGINA = 50;

    public static function render(): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        $filtroEstado = isset($_GET['status']) ? sanitize_key((string) wp_unslash($_GET['status'])) : '';
        $paginaActual = isset($_GET['paged']) ? max(1, (int) $_GET['paged']) : 1;
        $offset = ($paginaActual - 1) * self::POR_PAGINA;

        global $wpdb;
        $nombreTablaLog = IngestLogTable::nombreCompleto();
        $condicionEstado = '';
        $parametrosConsulta = [];
        if (in_array($filtroEstado, ['running', 'success', 'error'], true)) {
            $condicionEstado = 'WHERE l.status = %s';
            $parametrosConsulta[] = $filtroEstado;
        }

        $consultaBase = "SELECT SQL_CALC_FOUND_ROWS l.*, p.post_title
            FROM {$nombreTablaLog} l
            LEFT JOIN {$wpdb->posts} p ON p.ID = l.source_id
            {$condicionEstado}
            ORDER BY l.started_at DESC
            LIMIT %d OFFSET %d";
        $parametrosConsulta[] = self::POR_PAGINA;
        $parametrosConsulta[] = $offset;
        $filas = $wpdb->get_results($wpdb->prepare($consultaBase, ...$parametrosConsulta));
        $totalFilas = (int) $wpdb->get_var('SELECT FOUND_ROWS()');
        $totalPaginas = (int) ceil($totalFilas / self::POR_PAGINA);

        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Log de ingesta', 'flavor-news-hub'); ?></h1>

            <ul class="subsubsub">
                <?php
                foreach ([
                    ''        => __('Todo', 'flavor-news-hub'),
                    'success' => __('Éxito', 'flavor-news-hub'),
                    'error'   => __('Error', 'flavor-news-hub'),
                    'running' => __('En curso', 'flavor-news-hub'),
                ] as $slugEstado => $etiqueta) {
                    $urlFiltro = add_query_arg([
                        'page'   => 'fnh-ingest-log',
                        'status' => $slugEstado,
                    ], admin_url('admin.php'));
                    $actual = $filtroEstado === $slugEstado ? ' class="current"' : '';
                    printf(
                        '<li><a href="%s"%s>%s</a> | </li>',
                        esc_url($urlFiltro),
                        $actual,
                        esc_html($etiqueta)
                    );
                }
                ?>
            </ul>
            <div style="clear:both;"></div>

            <table class="widefat striped">
                <thead>
                    <tr>
                        <th><?php esc_html_e('ID', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Medio', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Estado', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Inicio (UTC)', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Fin (UTC)', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Nuevos', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Descartados', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Error', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                <?php if (empty($filas)) : ?>
                    <tr><td colspan="8"><?php esc_html_e('Sin registros.', 'flavor-news-hub'); ?></td></tr>
                <?php else : foreach ($filas as $fila) : ?>
                    <tr>
                        <td>#<?php echo (int) $fila->id; ?></td>
                        <td>
                            <?php if ($fila->source_id && $fila->post_title) : ?>
                                <a href="<?php echo esc_url(admin_url('post.php?action=edit&post=' . (int) $fila->source_id)); ?>">
                                    <?php echo esc_html($fila->post_title); ?>
                                </a>
                            <?php else : ?>
                                #<?php echo (int) $fila->source_id; ?>
                            <?php endif; ?>
                        </td>
                        <td><?php echo esc_html($fila->status); ?></td>
                        <td><?php echo esc_html($fila->started_at); ?></td>
                        <td><?php echo esc_html((string) ($fila->finished_at ?? '—')); ?></td>
                        <td><?php echo (int) $fila->items_new; ?></td>
                        <td><?php echo (int) $fila->items_skipped; ?></td>
                        <td><?php echo esc_html((string) ($fila->error_message ?? '')); ?></td>
                    </tr>
                <?php endforeach; endif; ?>
                </tbody>
            </table>

            <?php if ($totalPaginas > 1) : ?>
                <div class="tablenav">
                    <div class="tablenav-pages">
                        <?php
                        echo paginate_links([
                            'base'      => add_query_arg('paged', '%#%'),
                            'format'    => '',
                            'current'   => $paginaActual,
                            'total'     => $totalPaginas,
                            'prev_text' => '«',
                            'next_text' => '»',
                        ]);
                        ?>
                    </div>
                </div>
            <?php endif; ?>
        </div>
        <?php
    }
}
