<?php
declare(strict_types=1);

namespace FlavorNewsHub\Database;

use FlavorNewsHub\Options\OptionsRepository;

/**
 * Limpieza periódica de la tabla `fnh_ingest_log`.
 *
 * Ejecutada por `wp_cron` a diario (hook `fnh_cleanup_logs`). Elimina filas
 * más antiguas que la retención configurada en `fnh_settings`.
 */
final class LogsCleanup
{
    public static function ejecutar(): int
    {
        $diasARetener = (int) OptionsRepository::todas()['ingest_log_retention_days'];
        if ($diasARetener < OptionsRepository::RETENCION_MINIMA_DIAS) {
            $diasARetener = OptionsRepository::RETENCION_MINIMA_DIAS;
        }
        return IngestLogTable::eliminarLogsAntiguos($diasARetener);
    }
}
