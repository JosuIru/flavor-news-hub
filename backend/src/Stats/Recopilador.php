<?php
declare(strict_types=1);

namespace FlavorNewsHub\Stats;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Support\Transients;

/**
 * Servicio que centraliza el cálculo de estadísticas del catálogo y la
 * ingesta. Se usa desde la pantalla de Estadísticas del admin y desde
 * el informe semanal por email — antes esta lógica estaba duplicada.
 *
 * Cada método ejecuta SQL directo sobre `wp_postmeta` y la tabla
 * `fnh_ingest_log` con queries acotadas. Sin caché interna: el caller
 * decide si quiere envolverlo en transient (la página admin sí lo
 * hace, el cron del informe no porque corre cada semana).
 */
final class Recopilador
{
    /** Umbral en días para clasificar una fuente activa como "muerta". */
    public const UMBRAL_MUERTA_DIAS = 14;

    /**
     * Transient que cachea el bundle completo de stats para el admin.
     * Las consultas que lo alimentan (topFuentesActivas, fuentesMuertas,
     * fuentesConError, ...) llevan subqueries correlacionadas que se
     * evalúan por cada fuente activa — un par de centenas de fuentes
     * convierten cada visita al admin en cientos de joins. Cacheamos
     * el resultado entero para que sólo el primer render tras la
     * caducidad pague el coste.
     *
     * No se invoca desde el cron del informe semanal (allí queremos
     * lectura cruda); ese caller sigue llamando a los métodos
     * individuales sin cache.
     */
    public const TRANSIENT_STATS_ADMIN = 'fnh_stats_recopilador';

    /**
     * Bundle de todas las stats que pinta `EstadisticasPage`. Cachea
     * el resultado en un único transient — calcular esto cuesta
     * decenas o centenas de queries (subqueries correlacionadas por
     * fuente). El TTL es `Transients::CACHE_ESTADISTICAS` (1h), ya
     * usado para el bundle de descargas de GitHub.
     *
     * Para forzar recálculo desde el botón "Refrescar ya" o tras una
     * acción del admin, hace falta invocar `invalidarCacheStatsAdmin()`.
     *
     * @return array{
     *   actividad: array<string, mixed>,
     *   totales: array<string, int>,
     *   top: list<array{source_id:int, nombre:string, items:int}>,
     *   muertas: list<array{source_id:int, nombre:string, ultimo_item_utc:?string}>,
     *   errores: list<array{source_id:int, nombre:string, error:string}>,
     *   distribucion: list<array{tipo:string, total:int}>,
     *   ts_lectura: int
     * }
     */
    public static function statsAdmin(): array
    {
        $cache = get_transient(self::TRANSIENT_STATS_ADMIN);
        if (is_array($cache) && isset($cache['totales'])) {
            return $cache;
        }
        $datos = [
            'actividad'    => self::actividadIngesta(),
            'totales'      => self::totalesCatalogo(),
            'top'          => self::topFuentesActivas(10, 7),
            'muertas'      => self::fuentesMuertas(10),
            'errores'      => self::fuentesConError(10),
            'distribucion' => self::distribucionPorTipoFeed(),
            'ts_lectura'   => time(),
        ];
        set_transient(self::TRANSIENT_STATS_ADMIN, $datos, Transients::CACHE_ESTADISTICAS);
        return $datos;
    }

    /**
     * Invalida el bundle cacheado por `statsAdmin()`. Lo llaman las
     * acciones del admin que cambian datos visibles en la pantalla
     * (refresco manual, edición de fuentes, etc.).
     */
    public static function invalidarCacheStatsAdmin(): void
    {
        delete_transient(self::TRANSIENT_STATS_ADMIN);
    }

    /**
     * Recalcula el bundle de stats y reescribe el transient. Pensado
     * para engancharse al final del cron de ingesta: así, cuando el
     * admin abre la pestaña Sistema → Descargas, el transient está
     * caliente y se ahorra los segundos que cuestan las subqueries
     * correlacionadas de `topFuentesActivas` y `fuentesMuertas`.
     */
    public static function precalentarCacheStatsAdmin(): void
    {
        self::invalidarCacheStatsAdmin();
        self::statsAdmin();
    }

    /**
     * Contadores agregados del catálogo.
     *
     * @return array{
     *   sources_total:int, sources_activas:int,
     *   collectives_total:int, radios_total:int,
     *   items_total:int,
     *   pendientes_sources:int, pendientes_collectives:int
     * }
     */
    public static function totalesCatalogo(): array
    {
        return [
            'sources_total'           => self::contarPorTipo(Source::SLUG, 'publish'),
            'sources_activas'         => self::contarSourcesActivas(),
            'collectives_total'       => self::contarPorTipo(Collective::SLUG, 'publish'),
            'radios_total'            => self::contarPorTipo(Radio::SLUG, 'publish'),
            'items_total'             => self::contarPorTipo(Item::SLUG, 'publish'),
            'pendientes_sources'      => self::contarPorTipo(Source::SLUG, 'pending'),
            'pendientes_collectives'  => self::contarPorTipo(Collective::SLUG, 'pending'),
        ];
    }

    /**
     * Stats temporales de ingesta: items nuevos por ventana + tasa de éxito.
     *
     * @return array{
     *   items_24h:int, items_7d:int, items_30d:int,
     *   ingestas_7d:int, ingestas_error_7d:int, tasa_exito_7d:float,
     *   ultima_ingesta_utc:?string, proximo_cron_utc:?string
     * }
     */
    public static function actividadIngesta(): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();

        $totalIngestas7d = (int) $wpdb->get_var(
            "SELECT COUNT(*) FROM {$logsTabla}
             WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)"
        );
        $erroresIngesta7d = (int) $wpdb->get_var(
            "SELECT COUNT(*) FROM {$logsTabla}
             WHERE status = 'error'
               AND started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)"
        );
        $tasaExito = $totalIngestas7d > 0
            ? round((($totalIngestas7d - $erroresIngesta7d) / $totalIngestas7d) * 100, 1)
            : 0.0;

        $ultimaIngestaIso = (string) $wpdb->get_var(
            "SELECT MAX(started_at) FROM {$logsTabla} WHERE status = 'success'"
        );
        $proximoCron = wp_next_scheduled(Scheduler::HOOK_CRON);

        return [
            'items_24h'           => self::contarItemsUltimosDias(1),
            'items_7d'            => self::contarItemsUltimosDias(7),
            'items_30d'           => self::contarItemsUltimosDias(30),
            'ingestas_7d'         => $totalIngestas7d,
            'ingestas_error_7d'   => $erroresIngesta7d,
            'tasa_exito_7d'       => $tasaExito,
            'ultima_ingesta_utc'  => self::normalizarIso($ultimaIngestaIso),
            'proximo_cron_utc'    => is_int($proximoCron) && $proximoCron > 0
                ? gmdate('c', $proximoCron) : null,
        ];
    }

    /**
     * Top N fuentes con más items publicados en los últimos `$dias`.
     *
     * @return list<array{source_id:int, nombre:string, items:int}>
     */
    public static function topFuentesActivas(int $tope = 10, int $dias = 7): array
    {
        global $wpdb;
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
                ) AS items
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             ORDER BY items DESC, nombre ASC
             LIMIT %d",
            Item::SLUG, $dias, Source::SLUG, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'source_id' => (int) $f['source_id'],
            'nombre'    => (string) $f['nombre'],
            'items'     => (int) $f['items'],
        ], $filas);
    }

    /**
     * Fuentes activas sin items en los últimos `UMBRAL_MUERTA_DIAS`.
     *
     * @return list<array{source_id:int, nombre:string, ultimo_item_utc:?string}>
     */
    public static function fuentesMuertas(int $tope = 10): array
    {
        global $wpdb;
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT MAX(pi.post_date_gmt) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                ) AS ultimo
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
            Item::SLUG, Source::SLUG, Item::SLUG, self::UMBRAL_MUERTA_DIAS, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'source_id'        => (int) $f['source_id'],
            'nombre'           => (string) $f['nombre'],
            'ultimo_item_utc'  => self::normalizarIso((string) ($f['ultimo'] ?? '')),
        ], $filas);
    }

    /**
     * Fuentes con error en su última ingesta logueada.
     *
     * @return list<array{source_id:int, nombre:string, error:string}>
     */
    public static function fuentesConError(int $tope = 10): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();
        $filas = $wpdb->get_results($wpdb->prepare(
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
            Source::SLUG, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'source_id' => (int) $f['source_id'],
            'nombre'    => (string) $f['nombre'],
            'error'     => mb_substr((string) ($f['error_msg'] ?? ''), 0, 200),
        ], $filas);
    }

    /**
     * Top-N fuentes con más logs de error en los últimos N días. A
     * diferencia de `fuentesConError`, que mira sólo el ÚLTIMO log,
     * esta cuenta acumulado: detecta fuentes que fallan
     * intermitentemente (un día sí, otro no) — invisibles a la otra
     * métrica si la última ronda fue success.
     *
     * @return list<array{nombre:string, errores:int, ultimo_error:string}>
     */
    public static function topFuentesPorErrores(int $tope = 10, int $dias = 7): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                il.source_id,
                COUNT(*) AS errores,
                MAX(il.started_at) AS ultimo_error,
                p.post_title AS nombre
             FROM {$logsTabla} il
             INNER JOIN {$wpdb->posts} p ON p.ID = il.source_id
             WHERE il.status = 'error'
               AND il.started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
               AND p.post_type = %s
             GROUP BY il.source_id, p.post_title
             ORDER BY errores DESC, ultimo_error DESC
             LIMIT %d",
            $dias, Source::SLUG, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            // Anonimizamos: NO exponemos source_id porque este dato
            // viaja en el endpoint público `/diagnostics`. El nombre
            // legible es suficiente para diagnóstico.
            'nombre'       => (string) $f['nombre'],
            'errores'      => (int) $f['errores'],
            'ultimo_error' => (string) ($f['ultimo_error'] ?? ''),
        ], $filas);
    }

    /**
     * Top-N fuentes con mayor latencia media (ms) en los últimos N
     * días. Sólo cuenta logs `success` con `finished_at` no nulo —
     * los `error` o `running` huérfanos no aportan latencia
     * representativa.
     *
     * Útil para detectar feeds en degradación: cuando una fuente
     * pasa de 2s a 6s media, suele ser preludio del timeout (8s) y
     * de la cuarentena. Con esto se ven antes de que entren en
     * cuarentena.
     *
     * @return list<array{nombre:string, latencia_media_ms:int, muestras:int}>
     */
    public static function topFuentesPorLatencia(int $tope = 10, int $dias = 7): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                il.source_id,
                AVG(TIMESTAMPDIFF(MICROSECOND, il.started_at, il.finished_at) / 1000) AS latencia_media_ms,
                COUNT(*) AS muestras,
                p.post_title AS nombre
             FROM {$logsTabla} il
             INNER JOIN {$wpdb->posts} p ON p.ID = il.source_id
             WHERE il.status = 'success'
               AND il.finished_at IS NOT NULL
               AND il.started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
               AND p.post_type = %s
             GROUP BY il.source_id, p.post_title
             HAVING latencia_media_ms > 0
             ORDER BY latencia_media_ms DESC
             LIMIT %d",
            $dias, Source::SLUG, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'nombre'            => (string) $f['nombre'],
            'latencia_media_ms' => (int) round((float) $f['latencia_media_ms']),
            'muestras'          => (int) $f['muestras'],
        ], $filas);
    }

    /**
     * Fuentes que tras N rondas exitosas en N días NO devolvieron NI
     * UNA respuesta 304. Significa que ignoran nuestras cabeceras
     * condicionales (`If-None-Match` / `If-Modified-Since`) y siempre
     * obligan a re-parsear el cuerpo entero.
     *
     * Sirve para detectar candidatos a:
     *   - Limitar la frecuencia de ingesta (no aporta nada bajar más)
     *   - Implementar caché propio basado en hash del cuerpo
     *   - Reportar al dueño del feed que su CDN no soporta validators
     *
     * Filtramos por `>= MIN_RONDAS` para no señalar fuentes recién
     * añadidas que aún no acumulan historial representativo.
     *
     * @return list<array{nombre:string, rondas:int}>
     */
    public static function fuentesSinCabecerasCondicionales(int $tope = 10, int $dias = 7, int $minRondas = 3): array
    {
        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                il.source_id,
                COUNT(*) AS total_rondas,
                SUM(CASE WHEN il.http_status = 304 THEN 1 ELSE 0 END) AS rondas_304,
                p.post_title AS nombre
             FROM {$logsTabla} il
             INNER JOIN {$wpdb->posts} p ON p.ID = il.source_id
             WHERE il.status = 'success'
               AND il.http_status > 0
               AND il.started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
               AND p.post_type = %s
             GROUP BY il.source_id, p.post_title
             HAVING total_rondas >= %d AND rondas_304 = 0
             ORDER BY total_rondas DESC
             LIMIT %d",
            $dias, Source::SLUG, $minRondas, $tope
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'nombre' => (string) $f['nombre'],
            'rondas' => (int) $f['total_rondas'],
        ], $filas);
    }

    /**
     * Distribución de fuentes activas por tipo de feed (rss, youtube,
     * mastodon, podcast, video, atom). Útil para ver el reparto del
     * catálogo de un vistazo.
     *
     * @return list<array{tipo:string, total:int}>
     */
    public static function distribucionPorTipoFeed(): array
    {
        global $wpdb;
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT pmt.meta_value AS tipo, COUNT(*) AS total
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             INNER JOIN {$wpdb->postmeta} pmt ON pmt.post_id = p.ID
                AND pmt.meta_key = '_fnh_feed_type'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             GROUP BY pmt.meta_value
             ORDER BY total DESC, tipo ASC",
            Source::SLUG
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];
        return array_map(static fn(array $f) => [
            'tipo'  => (string) ($f['tipo'] ?? 'rss'),
            'total' => (int) $f['total'],
        ], $filas);
    }

    private static function contarSourcesActivas(): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(DISTINCT p.ID)
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pm ON pm.post_id = p.ID
                AND pm.meta_key = '_fnh_active' AND pm.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'",
            Source::SLUG
        ));
    }

    private static function contarPorTipo(string $tipoPost, string $estado): int
    {
        global $wpdb;
        return (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$wpdb->posts}
             WHERE post_type = %s AND post_status = %s",
            $tipoPost, $estado
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
            Item::SLUG, $dias
        ));
    }

    private static function normalizarIso(string $valor): ?string
    {
        if ($valor === '') return null;
        $ts = strtotime($valor . ' UTC');
        if ($ts === false) return $valor;
        return gmdate('c', $ts);
    }
}
