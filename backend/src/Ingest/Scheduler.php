<?php
declare(strict_types=1);

namespace FlavorNewsHub\Ingest;

use FlavorNewsHub\Options\OptionsRepository;

/**
 * Programación del job de ingesta en wp_cron, más el job diario de limpieza
 * de logs antiguos.
 *
 * Aclaración importante: wp_cron en WordPress NO es un cron del sistema.
 * Se dispara cuando alguien visita el sitio y ha pasado el intervalo desde
 * la última ejecución. Si el sitio tiene poco tráfico, los intervalos reales
 * serán mayores que el declarado. Para disparos inmediatos existe WP-CLI
 * (`wp flavor-news ingest`) y el botón "Ingest now" en admin.
 */
final class Scheduler
{
    public const HOOK_CRON = 'fnh_ingest_all';
    public const HOOK_CLEANUP_LOGS = 'fnh_cleanup_logs';
    public const RECURRENCE_SLUG = 'fnh_ingest_interval';

    /**
     * Declara el intervalo de cron leyendo su valor de las opciones.
     * Debe engancharse al filtro `cron_schedules` en cada request: WordPress
     * resuelve las recurrences dinámicamente y las consulta cada vez.
     *
     * @param array<string,array{interval:int,display:string}> $intervalosExistentes
     * @return array<string,array{interval:int,display:string}>
     */
    public static function registrarIntervalo(array $intervalosExistentes): array
    {
        $minutosConfigurados = (int) OptionsRepository::todas()['cron_interval_minutes'];
        if ($minutosConfigurados < OptionsRepository::INTERVALO_MINIMO_MINUTOS) {
            $minutosConfigurados = OptionsRepository::INTERVALO_MINIMO_MINUTOS;
        }
        $intervalosExistentes[self::RECURRENCE_SLUG] = [
            'interval' => $minutosConfigurados * MINUTE_IN_SECONDS,
            'display'  => sprintf(
                /* translators: %d es el intervalo en minutos */
                __('Cada %d minutos (Flavor News Hub)', 'flavor-news-hub'),
                $minutosConfigurados
            ),
        ];
        return $intervalosExistentes;
    }

    /** Agenda el job si no hay ya uno pendiente. */
    public static function agendarSiHaceFalta(): void
    {
        if (!wp_next_scheduled(self::HOOK_CRON)) {
            wp_schedule_event(time(), self::RECURRENCE_SLUG, self::HOOK_CRON);
        }
    }

    /** Cancela completamente el job. Llamado desde desactivación. */
    public static function desagendar(): void
    {
        $timestampProximo = wp_next_scheduled(self::HOOK_CRON);
        if ($timestampProximo !== false) {
            wp_unschedule_event($timestampProximo, self::HOOK_CRON);
        }
        // Limpia cualquier resto por si hubiera varios eventos encolados.
        wp_clear_scheduled_hook(self::HOOK_CRON);
    }

    /**
     * Re-agenda con el intervalo vigente en ese momento (útil tras cambiar
     * la opción de intervalo desde Settings).
     */
    public static function reagendar(): void
    {
        self::desagendar();
        self::agendarSiHaceFalta();
    }

    /** Agenda el job diario de limpieza de logs. */
    public static function agendarLimpiezaLogs(): void
    {
        if (!wp_next_scheduled(self::HOOK_CLEANUP_LOGS)) {
            wp_schedule_event(time() + HOUR_IN_SECONDS, 'daily', self::HOOK_CLEANUP_LOGS);
        }
    }

    /** Desagenda el job diario de limpieza de logs. */
    public static function desagendarLimpiezaLogs(): void
    {
        $timestampProximo = wp_next_scheduled(self::HOOK_CLEANUP_LOGS);
        if ($timestampProximo !== false) {
            wp_unschedule_event($timestampProximo, self::HOOK_CLEANUP_LOGS);
        }
        wp_clear_scheduled_hook(self::HOOK_CLEANUP_LOGS);
    }
}
