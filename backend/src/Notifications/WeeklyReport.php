<?php
declare(strict_types=1);

namespace FlavorNewsHub\Notifications;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Options\OptionsRepository;

/**
 * Informe semanal con estadísticas de feeds: top 10 más activos en los
 * últimos 7 días, fuentes muertas, fuentes con errores y propuestas
 * pendientes de moderación.
 *
 * Se ejecuta por wp_cron en el hook `Scheduler::HOOK_WEEKLY_REPORT`,
 * configurable en Ajustes (toggle + día de la semana). Si está
 * desactivado, el método `ejecutar()` sale sin enviar nada.
 *
 * El destino del email reutiliza la misma opción que `SubmitNotifier`:
 * `notify_email_target` con fallback a `admin_email` de WP.
 */
final class WeeklyReport
{
    /** Umbral en días para clasificar una fuente como "muerta" (sin items recientes). */
    public const UMBRAL_MUERTA_DIAS = 14;
    /** Cantidad máxima de filas listadas en cada bloque del informe. */
    public const TOPE_FILAS_LISTA = 10;

    public static function ejecutar(): void
    {
        $opciones = OptionsRepository::todas();
        if (empty($opciones['weekly_report_enabled'])) {
            return;
        }

        $emailDestino = trim((string) ($opciones['notify_email_target'] ?? ''));
        if ($emailDestino === '' || !is_email($emailDestino)) {
            $emailDestino = (string) get_option('admin_email');
        }
        if ($emailDestino === '' || !is_email($emailDestino)) {
            return;
        }

        $datos = self::recopilarDatos();
        $cuerpo = self::componerCuerpo($datos);
        $asunto = sprintf(
            /* translators: %s nombre del sitio */
            __('[%s] Informe semanal de feeds', 'flavor-news-hub'),
            (string) get_bloginfo('name')
        );

        wp_mail($emailDestino, $asunto, $cuerpo);
    }

    /** @return array<string,mixed> */
    private static function recopilarDatos(): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();

        $totales = [
            'sources_activas'    => self::contarSourcesActivas(),
            'sources_total'      => self::contarPorTipo(Source::SLUG, 'publish'),
            'collectives_total'  => self::contarPorTipo(Collective::SLUG, 'publish'),
            'radios_total'       => self::contarPorTipo(Radio::SLUG, 'publish'),
            'items_total'        => self::contarPorTipo(Item::SLUG, 'publish'),
            'items_7d'           => self::contarItemsUltimosDias(7),
            'pendientes_sources' => self::contarPorTipo(Source::SLUG, 'pending'),
            'pendientes_collectives' => self::contarPorTipo(Collective::SLUG, 'pending'),
        ];

        // Top 10 fuentes más activas en 7 días.
        $topActivas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                ) AS items_7d
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             ORDER BY items_7d DESC, nombre ASC
             LIMIT %d",
            Item::SLUG, Source::SLUG, self::TOPE_FILAS_LISTA
        ), ARRAY_A);

        // Fuentes "muertas": activas con 0 items en los últimos 14 días.
        $muertas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT MAX(pi.post_date_gmt) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                ) AS ultimo_item
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
               AND NOT EXISTS (
                    SELECT 1 FROM {$wpdb->postmeta} pmi2
                    INNER JOIN {$wpdb->posts} pi2 ON pi2.ID = pmi2.post_id
                    WHERE pmi2.meta_key = '_fnh_source_id' AND pmi2.meta_value = p.ID
                      AND pi2.post_type = %s AND pi2.post_status = 'publish'
                      AND pi2.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
               )
             ORDER BY p.post_title ASC
             LIMIT %d",
            Item::SLUG, Source::SLUG, Item::SLUG, self::UMBRAL_MUERTA_DIAS, self::TOPE_FILAS_LISTA
        ), ARRAY_A);

        // Fuentes con error en la última ingesta logueada.
        $conErrores = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT il.error_message FROM {$logsTabla} il
                    WHERE il.source_id = p.ID
                      AND il.error_message IS NOT NULL AND il.error_message != ''
                    ORDER BY il.started_at DESC LIMIT 1) AS error_msg,
                (SELECT il2.status FROM {$logsTabla} il2
                    WHERE il2.source_id = p.ID
                    ORDER BY il2.started_at DESC LIMIT 1) AS ultimo_status
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             HAVING ultimo_status = 'error'
             ORDER BY p.post_title ASC
             LIMIT %d",
            Source::SLUG, self::TOPE_FILAS_LISTA
        ), ARRAY_A);

        return [
            'totales'      => $totales,
            'top_activas'  => is_array($topActivas) ? $topActivas : [],
            'muertas'      => is_array($muertas) ? $muertas : [],
            'con_errores'  => is_array($conErrores) ? $conErrores : [],
        ];
    }

    private static function contarSourcesActivas(): int
    {
        global $wpdb;
        $resultado = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(DISTINCT p.ID)
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pm ON pm.post_id = p.ID
                AND pm.meta_key = '_fnh_active' AND pm.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'",
            Source::SLUG
        ));
        return $resultado;
    }

    private static function contarPorTipo(string $tipoPost, string $estado): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->posts}
             WHERE post_type = %s AND post_status = %s",
            $tipoPost,
            $estado
        ));
    }

    private static function contarItemsUltimosDias(int $dias): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->posts}
             WHERE post_type = %s
               AND post_status = 'publish'
               AND post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)",
            Item::SLUG,
            $dias
        ));
    }

    /** @param array<string,mixed> $datos */
    private static function componerCuerpo(array $datos): string
    {
        $totales = $datos['totales'];
        $lineas = [];

        $lineas[] = sprintf(
            __('Informe semanal · %s', 'flavor-news-hub'),
            wp_date('Y-m-d')
        );
        $lineas[] = str_repeat('=', 56);
        $lineas[] = '';
        $lineas[] = __('Resumen', 'flavor-news-hub') . ':';
        $lineas[] = sprintf(
            /* translators: %1$d activas, %2$d total */
            __('  Fuentes: %1$d activas / %2$d totales', 'flavor-news-hub'),
            (int) $totales['sources_activas'],
            (int) $totales['sources_total']
        );
        $lineas[] = sprintf(
            /* translators: %d colectivos */
            __('  Colectivos: %d', 'flavor-news-hub'),
            (int) $totales['collectives_total']
        );
        $lineas[] = sprintf(
            /* translators: %d radios */
            __('  Radios: %d', 'flavor-news-hub'),
            (int) $totales['radios_total']
        );
        $lineas[] = sprintf(
            /* translators: %1$d total items, %2$d últimos 7d */
            __('  Items: %1$d totales · %2$d en los últimos 7 días', 'flavor-news-hub'),
            (int) $totales['items_total'],
            (int) $totales['items_7d']
        );
        $lineas[] = sprintf(
            /* translators: %1$d sources pendientes, %2$d colectivos pendientes */
            __('  Pendientes de moderación: %1$d medios · %2$d colectivos', 'flavor-news-hub'),
            (int) $totales['pendientes_sources'],
            (int) $totales['pendientes_collectives']
        );
        $lineas[] = '';

        $lineas[] = __('Top fuentes más activas (últimos 7 días)', 'flavor-news-hub') . ':';
        if (empty($datos['top_activas'])) {
            $lineas[] = '  ' . __('(ninguna)', 'flavor-news-hub');
        } else {
            foreach ($datos['top_activas'] as $fila) {
                $lineas[] = sprintf(
                    '  %d items · %s',
                    (int) $fila['items_7d'],
                    (string) $fila['nombre']
                );
            }
        }
        $lineas[] = '';

        $lineas[] = sprintf(
            /* translators: %d umbral en días */
            __('Fuentes muertas (sin items en %d días)', 'flavor-news-hub'),
            self::UMBRAL_MUERTA_DIAS
        ) . ':';
        if (empty($datos['muertas'])) {
            $lineas[] = '  ' . __('(ninguna — todo bien)', 'flavor-news-hub');
        } else {
            foreach ($datos['muertas'] as $fila) {
                $ultimoIso = (string) ($fila['ultimo_item'] ?? '');
                $textoUltimo = $ultimoIso !== ''
                    ? sprintf(
                        /* translators: %s fecha último item */
                        __('último: %s', 'flavor-news-hub'),
                        $ultimoIso
                    )
                    : __('sin items', 'flavor-news-hub');
                $lineas[] = sprintf(
                    '  %s (%s)',
                    (string) $fila['nombre'],
                    $textoUltimo
                );
            }
        }
        $lineas[] = '';

        $lineas[] = __('Fuentes con error en la última ingesta', 'flavor-news-hub') . ':';
        if (empty($datos['con_errores'])) {
            $lineas[] = '  ' . __('(ninguna)', 'flavor-news-hub');
        } else {
            foreach ($datos['con_errores'] as $fila) {
                $errorTexto = (string) ($fila['error_msg'] ?? __('sin detalle', 'flavor-news-hub'));
                if (mb_strlen($errorTexto) > 120) {
                    $errorTexto = mb_substr($errorTexto, 0, 117) . '…';
                }
                $lineas[] = sprintf(
                    '  %s — %s',
                    (string) $fila['nombre'],
                    $errorTexto
                );
            }
        }
        $lineas[] = '';

        $urlEstado = admin_url('edit.php?post_type=fnh_source&page=fnh-estado-fuentes');
        $lineas[] = __('Estado completo en el admin:', 'flavor-news-hub');
        $lineas[] = $urlEstado;
        $lineas[] = '';
        $lineas[] = sprintf(
            /* translators: %s nombre del sitio */
            __('— Flavor News Hub @ %s', 'flavor-news-hub'),
            (string) get_bloginfo('name')
        );

        return implode("\n", $lineas);
    }
}
