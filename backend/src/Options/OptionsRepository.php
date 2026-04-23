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

    /** Retención mínima de items: no tiene sentido borrar noticias de menos
     *  de una semana — muchas apps móviles revisitan items recientes. */
    public const RETENCION_MINIMA_ITEMS_DIAS = 7;

    /** URL de donación por defecto del proyecto. */
    public const DONATION_URL_DEFAULT = 'https://www.paypal.com/paypalme/codigodespierto';

    /** @return array<string,mixed> */
    public static function defaults(): array
    {
        return [
            'cron_interval_minutes'     => 30,
            'ingest_log_retention_days' => 30,
            // 90 días cubre cualquier revisita útil de titulares; pasado
            // ese tiempo el valor editorial es prácticamente cero y la
            // tabla wp_posts se ahorra crecimiento ilimitado.
            'item_retention_days'       => 90,
            'delete_on_uninstall'       => false,
            'donation_url'              => self::DONATION_URL_DEFAULT,
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
        $retencionItemsBruta = (int) ($fusion['item_retention_days'] ?? 90);
        $fusion['item_retention_days'] = $retencionItemsBruta === 0
            ? 0
            : max(self::RETENCION_MINIMA_ITEMS_DIAS, $retencionItemsBruta);
        $fusion['delete_on_uninstall'] = (bool) $fusion['delete_on_uninstall'];
        $urlSaneada = esc_url_raw((string) ($fusion['donation_url'] ?? ''));
        $fusion['donation_url'] = $urlSaneada !== '' ? $urlSaneada : self::DONATION_URL_DEFAULT;

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
