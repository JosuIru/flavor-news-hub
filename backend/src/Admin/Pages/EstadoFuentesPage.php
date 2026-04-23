<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Database\IngestLogTable;

/**
 * Pantalla de admin "Estado de fuentes": una fila por cada fuente
 * activa con su actividad real (última ingesta, items creados en 7/30
 * días, total histórico, último error si lo hubiera).
 *
 * Pensada para encontrar rápidamente:
 *  - Fuentes muertas (sin items nuevos en semanas) → candidatas a quitar.
 *  - Fuentes con errores recurrentes → feed roto o URL caducada.
 *  - Oligopolios en el feed (unos pocos medios dominando los últimos
 *    días) → señal de que otros deberían revisarse.
 */
final class EstadoFuentesPage
{
    public const SLUG = 'fnh-estado-fuentes';

    public static function render(): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();

        // Sources activas ordenadas por actividad descendente. Una sola
        // query con subconsultas correlacionadas — no es bonito pero
        // cabe en pantalla y evita N+1 a 110 fuentes.
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT pm2.meta_value FROM {$wpdb->postmeta} pm2
                    WHERE pm2.post_id = p.ID AND pm2.meta_key = '_fnh_feed_url' LIMIT 1) AS feed_url,
                (SELECT pm3.meta_value FROM {$wpdb->postmeta} pm3
                    WHERE pm3.post_id = p.ID AND pm3.meta_key = '_fnh_feed_type' LIMIT 1) AS feed_type,
                (SELECT pm4.meta_value FROM {$wpdb->postmeta} pm4
                    WHERE pm4.post_id = p.ID AND pm4.meta_key = '_fnh_territory' LIMIT 1) AS territorio,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                ) AS total_items,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                ) AS items_7d,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                ) AS items_30d,
                (SELECT MAX(il.started_at) FROM {$logsTabla} il WHERE il.source_id = p.ID) AS ultima_ingesta,
                (SELECT il2.status FROM {$logsTabla} il2 WHERE il2.source_id = p.ID
                    ORDER BY il2.started_at DESC LIMIT 1) AS ultimo_status,
                (SELECT il3.error_message FROM {$logsTabla} il3 WHERE il3.source_id = p.ID
                    AND il3.error_message IS NOT NULL AND il3.error_message != ''
                    ORDER BY il3.started_at DESC LIMIT 1) AS ultimo_error
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             ORDER BY items_7d DESC, nombre ASC",
            Item::SLUG, Item::SLUG, Item::SLUG, Source::SLUG
        ), ARRAY_A);

        $filas = is_array($filas) ? $filas : [];

        // Clasificar en tres categorías visuales.
        $ahora = time();
        $muertas = []; $inactivas = []; $sanas = []; $conErrores = [];
        foreach ($filas as $f) {
            $itemsSiete = (int) ($f['items_7d'] ?? 0);
            $itemsTreinta = (int) ($f['items_30d'] ?? 0);
            $status = (string) ($f['ultimo_status'] ?? '');
            if ($status === 'error') {
                $conErrores[] = $f;
            } elseif ($itemsSiete > 0) {
                $sanas[] = $f;
            } elseif ($itemsTreinta > 0) {
                $inactivas[] = $f;
            } else {
                $muertas[] = $f;
            }
        }

        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Estado de las fuentes', 'flavor-news-hub'); ?></h1>
            <p class="description">
                <?php printf(
                    /* translators: %1$d total, %2$d sanas, %3$d inactivas, %4$d muertas, %5$d con errores */
                    esc_html__('Total: %1$d fuentes activas · %2$d sanas (items últimos 7d) · %3$d inactivas (sin items en 7d pero sí en 30d) · %4$d muertas (sin items en 30d) · %5$d con errores en la última ingesta.', 'flavor-news-hub'),
                    count($filas),
                    count($sanas),
                    count($inactivas),
                    count($muertas),
                    count($conErrores)
                ); ?>
            </p>

            <?php if ($conErrores !== []) : ?>
                <h2 style="color:#dc3232; margin-top:2em"><?php esc_html_e('Con errores en la última ingesta', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($conErrores, true); ?>
            <?php endif; ?>

            <?php if ($muertas !== []) : ?>
                <h2 style="color:#dc3232; margin-top:2em"><?php esc_html_e('Muertas (sin items en 30 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($muertas, false); ?>
            <?php endif; ?>

            <?php if ($inactivas !== []) : ?>
                <h2 style="color:#dba617; margin-top:2em"><?php esc_html_e('Inactivas (sin items en 7 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($inactivas, false); ?>
            <?php endif; ?>

            <?php if ($sanas !== []) : ?>
                <h2 style="color:#46b450; margin-top:2em"><?php esc_html_e('Sanas (activas últimos 7 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($sanas, false); ?>
            <?php endif; ?>
        </div>
        <?php
    }

    /** @param list<array<string,mixed>> $filas */
    private static function renderTabla(array $filas, bool $mostrarError): void
    {
        ?>
        <table class="widefat striped" style="max-width:1200px">
            <thead>
                <tr>
                    <th><?php esc_html_e('Medio', 'flavor-news-hub'); ?></th>
                    <th style="width:60px"><?php esc_html_e('Tipo', 'flavor-news-hub'); ?></th>
                    <th style="width:80px; text-align:right"><?php esc_html_e('7d', 'flavor-news-hub'); ?></th>
                    <th style="width:80px; text-align:right"><?php esc_html_e('30d', 'flavor-news-hub'); ?></th>
                    <th style="width:90px; text-align:right"><?php esc_html_e('Total', 'flavor-news-hub'); ?></th>
                    <th style="width:160px"><?php esc_html_e('Última ingesta', 'flavor-news-hub'); ?></th>
                    <?php if ($mostrarError) : ?><th><?php esc_html_e('Error', 'flavor-news-hub'); ?></th><?php endif; ?>
                    <th style="width:80px"><?php esc_html_e('Acciones', 'flavor-news-hub'); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($filas as $f) :
                    $idSource = (int) $f['source_id'];
                    $editUrl = get_edit_post_link($idSource);
                    $feedUrl = (string) ($f['feed_url'] ?? '');
                    $ultima = (string) ($f['ultima_ingesta'] ?? '');
                    $ultimaHumana = $ultima !== ''
                        ? human_time_diff(strtotime($ultima . ' UTC'), time()) . ' atrás'
                        : '—';
                ?>
                <tr>
                    <td>
                        <strong><?php echo esc_html((string) $f['nombre']); ?></strong>
                        <?php if (!empty($f['territorio'])) : ?>
                            <br><span style="color:#888; font-size:.85em"><?php echo esc_html((string) $f['territorio']); ?></span>
                        <?php endif; ?>
                        <?php if ($feedUrl !== '') : ?>
                            <br><a href="<?php echo esc_url($feedUrl); ?>" target="_blank" style="font-size:.8em; color:#999" rel="noopener"><?php echo esc_html(wp_parse_url($feedUrl, PHP_URL_HOST) ?: $feedUrl); ?></a>
                        <?php endif; ?>
                    </td>
                    <td><code style="font-size:.75em"><?php echo esc_html((string) ($f['feed_type'] ?? '?')); ?></code></td>
                    <td style="text-align:right"><?php echo (int) ($f['items_7d'] ?? 0); ?></td>
                    <td style="text-align:right"><?php echo (int) ($f['items_30d'] ?? 0); ?></td>
                    <td style="text-align:right"><?php echo (int) ($f['total_items'] ?? 0); ?></td>
                    <td style="font-size:.85em"><?php echo esc_html($ultimaHumana); ?></td>
                    <?php if ($mostrarError) : ?>
                        <td style="font-size:.8em; color:#c33;"><?php echo esc_html(mb_substr((string) ($f['ultimo_error'] ?? ''), 0, 200)); ?></td>
                    <?php endif; ?>
                    <td>
                        <?php if ($editUrl) : ?>
                            <a href="<?php echo esc_url($editUrl); ?>"><?php esc_html_e('Editar', 'flavor-news-hub'); ?></a>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <?php
    }
}
