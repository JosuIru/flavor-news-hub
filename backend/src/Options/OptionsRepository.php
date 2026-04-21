<?php
declare(strict_types=1);

namespace FlavorNewsHub\Options;

/**
 * Repositorio para la opción `fnh_settings`.
 *
 * Todos los ajustes del plugin viven en una sola fila de `wp_options` como
 * array asociativo. Esto simplifica la serialización, la exportación y la
 * limpieza en `uninstall.php`.
 *
 * Se definen defaults seguros que se combinan con lo persistido para que el
 * plugin pueda leer siempre valores consistentes aunque la fila no exista
 * aún (primera activación).
 */
final class OptionsRepository
{
    public const NOMBRE_OPCION = 'fnh_settings';

    /** Intervalo mínimo de cron: por respeto a los feeds de los medios. */
    public const INTERVALO_MINIMO_MINUTOS = 5;

    /** Retención mínima de logs: ver al menos los de las últimas 24h. */
    public const RETENCION_MINIMA_DIAS = 1;

    /** @return array<string,mixed> */
    public static function defaults(): array
    {
        return [
            'cron_interval_minutes'     => 30,
            'ingest_log_retention_days' => 30,
            'delete_on_uninstall'       => false,
        ];
    }

    /**
     * Ajustes vigentes: defaults + overrides persistidos.
     * @return array<string,mixed>
     */
    public static function todas(): array
    {
        $persistidas = get_option(self::NOMBRE_OPCION, []);
        if (!is_array($persistidas)) {
            $persistidas = [];
        }
        return array_merge(self::defaults(), $persistidas);
    }

    /**
     * Fusiona y persiste nuevos valores. Sanea rangos.
     *
     * @param array<string,mixed> $nuevosValores
     */
    public static function actualizar(array $nuevosValores): void
    {
        $actuales = self::todas();
        $fusion = array_merge($actuales, $nuevosValores);

        $fusion['cron_interval_minutes'] = max(
            self::INTERVALO_MINIMO_MINUTOS,
            (int) $fusion['cron_interval_minutes']
        );
        $fusion['ingest_log_retention_days'] = max(
            self::RETENCION_MINIMA_DIAS,
            (int) $fusion['ingest_log_retention_days']
        );
        $fusion['delete_on_uninstall'] = (bool) $fusion['delete_on_uninstall'];

        update_option(self::NOMBRE_OPCION, $fusion);
    }

    /** Garantiza que la fila exista con defaults. Se llama en activación. */
    public static function asegurarDefaults(): void
    {
        if (get_option(self::NOMBRE_OPCION, null) === null) {
            update_option(self::NOMBRE_OPCION, self::defaults());
        }
    }
}
