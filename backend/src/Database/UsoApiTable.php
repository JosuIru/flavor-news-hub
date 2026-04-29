<?php
declare(strict_types=1);

namespace FlavorNewsHub\Database;

/**
 * Tabla de métricas agregadas de uso de la API pública (`flavor-news/v1`).
 *
 * Diseño: cada fila representa "tantas peticiones a este endpoint en este
 * día desde este user-agent". La granularidad es (día, endpoint, hash-UA),
 * no (request, IP, fingerprint). Sirve para responder a:
 *   - ¿Cuántas peticiones recibió la API en la última semana?
 *   - ¿Hay actividad real o sólo descargas del APK?
 *   - ¿Cuántos user-agents distintos en una ventana? (señal de pluralidad)
 *
 * No sirve para:
 *   - Identificar usuarios (no hay IP, sólo md5 truncado del UA).
 *   - Reconstruir sesiones (sólo días, no horas).
 *   - Geolocalizar (no se almacena IP).
 *
 * Política de retención: 90 días. Más allá no aporta señal y la tabla
 * se mantendría innecesariamente grande.
 */
final class UsoApiTable
{
    public const NOMBRE_TABLA_SIN_PREFIJO = 'fnh_uso_api';

    public static function nombreCompleto(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::NOMBRE_TABLA_SIN_PREFIJO;
    }

    /**
     * Crea o actualiza la tabla. Idempotente vía `dbDelta()`.
     *
     * `ua_hash` es MD5 truncado a 16 caracteres del user-agent. No
     * podemos invertirlo a UA original — sólo permite contar UAs
     * distintos en una ventana sin guardar el valor crudo.
     *
     * Clave única (dia, endpoint, ua_hash) hace que el incremento sea
     * atómico vía `INSERT ... ON DUPLICATE KEY UPDATE`.
     */
    public static function crearOActualizar(): void
    {
        global $wpdb;
        $nombreTabla = self::nombreCompleto();
        $collateCharset = $wpdb->get_charset_collate();

        $sentenciaSql = "CREATE TABLE {$nombreTabla} (
            dia DATE NOT NULL,
            endpoint VARCHAR(100) NOT NULL,
            ua_hash CHAR(16) NOT NULL,
            peticiones BIGINT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY  (dia, endpoint, ua_hash),
            KEY idx_dia (dia)
        ) {$collateCharset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sentenciaSql);
    }

    /**
     * Borra filas con `dia` anterior a `$diasARetener` días atrás.
     * Devuelve el número de filas eliminadas.
     */
    public static function eliminarRegistrosAntiguos(int $diasARetener): int
    {
        if ($diasARetener < 1) {
            return 0;
        }
        global $wpdb;
        $nombreTabla = self::nombreCompleto();
        $resultado = $wpdb->query($wpdb->prepare(
            "DELETE FROM {$nombreTabla} WHERE dia < DATE_SUB(CURDATE(), INTERVAL %d DAY)",
            $diasARetener
        ));
        return is_int($resultado) ? $resultado : 0;
    }
}
