<?php
declare(strict_types=1);

namespace FlavorNewsHub\Database;

/**
 * Esquema y operaciones sobre la tabla de log de ingesta `{prefix}fnh_ingest_log`.
 *
 * Cada ejecución de ingesta (por fuente) escribe una fila con:
 *  - cuándo empezó y cuándo terminó
 *  - cuántos items nuevos creó y cuántos descartó por dedupe
 *  - si hubo error, el mensaje
 *
 * Los logs sirven para diagnosticar fuentes caídas, feeds corruptos o
 * cambios de estructura sin tener que reproducir la ingesta en vivo.
 */
final class IngestLogTable
{
    public const NOMBRE_TABLA_SIN_PREFIJO = 'fnh_ingest_log';

    public static function nombreCompleto(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::NOMBRE_TABLA_SIN_PREFIJO;
    }

    /**
     * Crea o actualiza la tabla. Idempotente gracias a `dbDelta()`, que
     * compara la definición con la real y sólo aplica los ALTER necesarios.
     * Debe ejecutarse en el hook de activación del plugin.
     *
     * Nota: `dbDelta()` es estricto con la sintaxis — los dos espacios entre
     * "PRIMARY KEY" y el paréntesis son obligatorios.
     */
    public static function crearOActualizar(): void
    {
        global $wpdb;

        $nombreTabla = self::nombreCompleto();
        $collateCharset = $wpdb->get_charset_collate();

        // `http_status`: código HTTP de la respuesta del origen (200,
        // 304, 404, 500…). 0 indica que no llegó a haber respuesta
        // HTTP (timeout, DNS, SSL, fuente tipo flavor_platform, etc.).
        // Lo persistimos para poder calcular % de 304 por fuente sin
        // tener que parsear el `error_message` (frágil: depende del
        // string literal "Feed no modificado..."). SMALLINT cubre
        // hasta 999, suficiente para HTTP estándar y extensiones.
        $sentenciaSql = "CREATE TABLE {$nombreTabla} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            source_id BIGINT UNSIGNED NOT NULL,
            status VARCHAR(16) NOT NULL DEFAULT 'running',
            started_at DATETIME NOT NULL,
            finished_at DATETIME DEFAULT NULL,
            items_new INT UNSIGNED NOT NULL DEFAULT 0,
            items_skipped INT UNSIGNED NOT NULL DEFAULT 0,
            error_message TEXT DEFAULT NULL,
            http_status SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY  (id),
            KEY idx_source_started (source_id, started_at),
            KEY idx_status (status),
            KEY idx_http_status (http_status)
        ) {$collateCharset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sentenciaSql);
    }

    /**
     * Elimina las filas más antiguas que `$diasARetener`.
     * Devuelve el número de filas borradas (o 0 si nada encaja).
     */
    public static function eliminarLogsAntiguos(int $diasARetener): int
    {
        if ($diasARetener < 1) {
            return 0;
        }
        global $wpdb;
        $nombreTabla = self::nombreCompleto();
        $resultado = $wpdb->query($wpdb->prepare(
            "DELETE FROM {$nombreTabla} WHERE started_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)",
            $diasARetener
        ));
        return is_int($resultado) ? $resultado : 0;
    }
}
