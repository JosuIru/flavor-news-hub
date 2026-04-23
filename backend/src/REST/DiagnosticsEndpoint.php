<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\Scheduler;

/**
 * Endpoint de diagnóstico público para saber el estado real de la
 * ingesta — útil cuando el usuario ve noticias viejas y no sabe si es
 * problema de feeds, de cron, o de la app.
 *
 * No expone nada sensible (sin emails ni tokens). Sólo agregados y los
 * últimos N logs con `source_id` anónimo.
 *
 * GET /wp-json/flavor-news/v1/diagnostics
 */
final class DiagnosticsEndpoint
{
    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/diagnostics', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'obtener'],
                'permission_callback' => '__return_true',
            ],
        ]);
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        global $wpdb;
        $nombreTabla = IngestLogTable::nombreCompleto();

        // Última ingesta global (por cualquier fuente, con timestamp mayor).
        $ultimaEjecucion = $wpdb->get_var(
            "SELECT MAX(started_at) FROM {$nombreTabla}"
        );
        $ultimoFinalizado = $wpdb->get_var(
            "SELECT MAX(finished_at) FROM {$nombreTabla} WHERE status = 'ok'"
        );

        // Últimos 10 logs: status + items + error si hubo.
        $ultimos = $wpdb->get_results(
            "SELECT source_id, status, started_at, finished_at, items_new, items_skipped, error_message
             FROM {$nombreTabla}
             ORDER BY started_at DESC
             LIMIT 10",
            ARRAY_A
        );
        $ultimos = is_array($ultimos) ? $ultimos : [];
        foreach ($ultimos as &$log) {
            // Resolvemos el nombre del source para que el diagnóstico sea
            // legible sin tener que cruzar IDs contra /sources.
            $idSource = (int) ($log['source_id'] ?? 0);
            $log['source_name'] = $idSource > 0
                ? (string) (get_the_title($idSource) ?: '')
                : '';
            $log['source_id'] = $idSource;
            // Truncamos mensajes de error muy largos.
            if (!empty($log['error_message']) && strlen((string) $log['error_message']) > 400) {
                $log['error_message'] = substr((string) $log['error_message'], 0, 400) . '…';
            }
        }
        unset($log);

        // Items nuevos creados en las últimas 24h — métrica útil para
        // saber si la ingesta está aportando contenido real.
        $itemsUltimas24h = (int) $wpdb->get_var(
            "SELECT COALESCE(SUM(items_new), 0)
             FROM {$nombreTabla}
             WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 24 HOUR)"
        );

        // Número de sources activas actualmente.
        $sourcesActivas = (int) $wpdb->get_var(
            "SELECT COUNT(*) FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_fnh_active' AND pm.meta_value = '1'
               AND p.post_type = 'fnh_source' AND p.post_status = 'publish'"
        );

        // Próxima ejecución programada de wp-cron para la ingesta.
        $proximoCron = wp_next_scheduled(Scheduler::HOOK_CRON);

        return new \WP_REST_Response([
            'sources_activas'         => $sourcesActivas,
            'ultima_ejecucion_utc'    => self::normalizarIso($ultimaEjecucion),
            'ultimo_finalizado_utc'   => self::normalizarIso($ultimoFinalizado),
            'items_nuevos_ultimas_24h'=> $itemsUltimas24h,
            'proximo_cron_utc'        => is_int($proximoCron) && $proximoCron > 0
                ? gmdate('c', $proximoCron)
                : null,
            'ahora_utc'               => gmdate('c'),
            'ultimos_logs'            => $ultimos,
        ], 200);
    }

    private static function normalizarIso(mixed $valor): ?string
    {
        if (!is_string($valor) || $valor === '') {
            return null;
        }
        $ts = strtotime($valor . ' UTC');
        if ($ts === false) return $valor;
        return gmdate('c', $ts);
    }
}
