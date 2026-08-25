<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Ingest\FeedIngester;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Options\OptionsRepository;
use FlavorNewsHub\Stats\Recopilador;
use FlavorNewsHub\Support\Transients;

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
    /**
     * Transient con el bloque de top-N (errores 7d + latencia 7d).
     * Se invalida cuando la purga diaria de logs corre, para que
     * los rankings reflejen sólo logs vigentes.
     */
    public const TRANSIENT_TOP_METRICS = 'fnh_diag_top_metrics';

    /**
     * Tope de fuentes en `top_errores_7d`. Más alto que latencia/304
     * (10) porque lo que interesa aquí es ver TODAS las que fallan, no
     * sólo las peores: con ~280 fuentes activas, las que erran en una
     * ventana de 7 días pueden ser varias decenas. 40 cubre el caso
     * real sin inflar el payload de un endpoint público y cacheado.
     */
    private const LIMITE_TOP_ERRORES = 40;

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
        // status guardado por el ingester es 'success' (no 'ok') —
        // corregido tras ver `ultimo_finalizado_utc: null` en el endpoint
        // a pesar de haber ejecuciones exitosas.
        $ultimoFinalizado = $wpdb->get_var(
            "SELECT MAX(finished_at) FROM {$nombreTabla} WHERE status = 'success'"
        );

        // Últimos 10 logs: status + items + error si hubo.
        // Usamos `source_id` internamente para resolver el nombre, pero NO
        // lo exponemos en el payload — el endpoint es público y el id es
        // un identificador estable que permitiría rastrear cambios sobre
        // una fuente concreta. El nombre legible es suficiente para
        // diagnóstico y ya está accesible en `/sources`.
        $ultimos = $wpdb->get_results(
            "SELECT source_id, status, started_at, finished_at, items_new, items_skipped, error_message
             FROM {$nombreTabla}
             ORDER BY started_at DESC
             LIMIT 10",
            ARRAY_A
        );
        $ultimos = is_array($ultimos) ? $ultimos : [];
        foreach ($ultimos as &$log) {
            $idSource = (int) ($log['source_id'] ?? 0);
            $log['source_name'] = $idSource > 0
                ? (string) (get_the_title($idSource) ?: '')
                : '';
            unset($log['source_id']);
            // Castear a int los contadores — $wpdb los devuelve como
            // string por defecto y en JSON quedaban como "0" vs 0, feo.
            $log['items_new'] = (int) ($log['items_new'] ?? 0);
            $log['items_skipped'] = (int) ($log['items_skipped'] ?? 0);
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

        // Salud de la tabla de items: total acumulado + retención actual.
        // Sirve para que admin vea si la purga está conteniendo el
        // crecimiento o si hace falta bajar el retention.
        $itemsTotales = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = %s AND post_status = 'publish'",
            Item::SLUG
        ));
        $retencionItems = (int) (OptionsRepository::todas()['item_retention_days'] ?? 90);

        // Top-N agregado: errores 7d y latencia media 7d. Caché 5 min
        // porque son agregaciones sobre la tabla de logs y el endpoint
        // es público — un crawler curioso no debe poder dispararlas en
        // bucle.
        $topMetricas = self::obtenerTopMetricasCacheadas();

        return new \WP_REST_Response([
            // Versión del plugin que está realmente ejecutando este request.
            // Crítica para diferenciar "WP cree que está actualizado" de
            // "PHP-FPM/OPcache sigue sirviendo el bytecode viejo": si
            // wp-admin → Plugins muestra X y este campo devuelve Y, hay
            // OPcache stale y un reinicio o reactivación lo resuelve.
            'plugin_version'          => defined('FNH_VERSION') ? FNH_VERSION : 'desconocida',
            'sources_activas'         => $sourcesActivas,
            'ultima_ejecucion_utc'    => self::normalizarIso($ultimaEjecucion),
            'ultimo_finalizado_utc'   => self::normalizarIso($ultimoFinalizado),
            'items_nuevos_ultimas_24h'=> $itemsUltimas24h,
            'items_totales'           => $itemsTotales,
            'item_retention_days'     => $retencionItems,
            'proximo_cron_utc'        => is_int($proximoCron) && $proximoCron > 0
                ? gmdate('c', $proximoCron)
                : null,
            'ahora_utc'               => gmdate('c'),
            'ultimos_logs'            => $ultimos,
            'top_errores_7d'          => $topMetricas['errores'],
            'top_latencia_7d'         => $topMetricas['latencia'],
            'fuentes_sin_304_7d'      => $topMetricas['sin_304'],
            'fuentes_en_cuarentena'   => self::obtenerFuentesEnCuarentena(),
        ], 200);
    }

    /**
     * Fuentes que el circuit breaker tiene en cuarentena ahora mismo.
     *
     * Sin esta lista son literalmente invisibles: `ingestarFuente` sale
     * ANTES de crear el log cuando la fuente está en cuarentena (a
     * propósito, para no inundar la tabla), así que una fuente que
     * falla de forma sostenida deja de aparecer en `ultimos_logs` y,
     * como sólo se reintenta una vez al día, tampoco acumula errores
     * suficientes para entrar en `top_errores_7d` — que lo copan las
     * que fallan en cada ronda. El resultado es una fuente que no
     * publica nada y no da ninguna señal de por qué.
     *
     * Igual que `ultimos_logs`, expone el nombre y no el `source_id`:
     * el endpoint es público y el id es un identificador estable.
     *
     * @return list<array{source_name:string,errores_consecutivos:int,reintento_utc:string}>
     */
    private static function obtenerFuentesEnCuarentena(): array
    {
        global $wpdb;
        $ahora = time();
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT p.ID, p.post_title, m_next.meta_value AS proximo, m_err.meta_value AS errores
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} m_next
               ON m_next.post_id = p.ID AND m_next.meta_key = %s
             LEFT JOIN {$wpdb->postmeta} m_err
               ON m_err.post_id = p.ID AND m_err.meta_key = %s
             WHERE p.post_type = %s
               AND p.post_status = 'publish'
               AND CAST(m_next.meta_value AS UNSIGNED) > %d
             ORDER BY CAST(m_err.meta_value AS UNSIGNED) DESC
             LIMIT 50",
            FeedIngester::META_PROXIMO_INTENTO_TRAS,
            FeedIngester::META_ERRORES_CONSECUTIVOS,
            Source::SLUG,
            $ahora
        ), ARRAY_A) ?: [];

        $salida = [];
        foreach ($filas as $fila) {
            $salida[] = [
                'source_name'          => (string) $fila['post_title'],
                'errores_consecutivos' => (int) $fila['errores'],
                'reintento_utc'        => gmdate('c', (int) $fila['proximo']),
            ];
        }
        return $salida;
    }

    /**
     * Devuelve `['errores' => [...], 'latencia' => [...]]` con caché
     * de 5 min. El bundle se calcula y guarda como un solo transient
     * porque ambas listas se sirven juntas y quien quiera invalidar
     * sólo tiene que borrar una clave.
     *
     * @return array{errores: list<array>, latencia: list<array>}
     */
    private static function obtenerTopMetricasCacheadas(): array
    {
        $cache = get_transient(self::TRANSIENT_TOP_METRICS);
        if (is_array($cache) && isset($cache['errores'], $cache['latencia'])) {
            return $cache;
        }
        $datos = [
            'errores'   => Recopilador::topFuentesPorErrores(self::LIMITE_TOP_ERRORES, 7),
            'latencia'  => Recopilador::topFuentesPorLatencia(10, 7),
            'sin_304'   => Recopilador::fuentesSinCabecerasCondicionales(10, 7, 3),
        ];
        set_transient(self::TRANSIENT_TOP_METRICS, $datos, Transients::CACHE_DIAGNOSTICS_TOP);
        return $datos;
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
