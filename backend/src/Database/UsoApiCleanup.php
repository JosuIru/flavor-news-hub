<?php
declare(strict_types=1);

namespace FlavorNewsHub\Database;

/**
 * Limpieza periódica de la tabla `fnh_uso_api`.
 *
 * Ejecutada por `wp_cron` a diario (hook `fnh_cleanup_logs`, compartido
 * con LogsCleanup e ItemsCleanup para no multiplicar eventos en el cron
 * por algo tan ligero). Retención fija a 90 días: más allá la señal
 * agregada deja de aportar y la tabla crece sin necesidad.
 *
 * Si en el futuro hace falta hacer la retención configurable se mueve
 * a `OptionsRepository`; hoy 90 días es decisión documentada en
 * `UsoApiTable`.
 */
final class UsoApiCleanup
{
    public const DIAS_RETENCION = 90;

    public static function ejecutar(): int
    {
        return UsoApiTable::eliminarRegistrosAntiguos(self::DIAS_RETENCION);
    }
}
