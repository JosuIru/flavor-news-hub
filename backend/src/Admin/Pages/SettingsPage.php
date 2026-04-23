<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Options\OptionsRepository;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Catalog\CreadorPaginas;
use FlavorNewsHub\Admin\Actions\CrearPaginasHandler;

/**
 * Pantalla de ajustes del plugin. Usa la Settings API de WordPress con un
 * único option (`fnh_settings`) serializado como array.
 *
 * Los cambios de intervalo de cron disparan una reagenda automática.
 */
final class SettingsPage
{
    public const GRUPO_OPCIONES = 'fnh_settings_group';
    public const SECCION_GENERAL = 'fnh_settings_seccion_general';
    public const SECCION_PRIVACIDAD = 'fnh_settings_seccion_privacidad';

    public static function registrarAjustes(): void
    {
        register_setting(
            self::GRUPO_OPCIONES,
            OptionsRepository::NOMBRE_OPCION,
            [
                'type'              => 'array',
                'sanitize_callback' => [self::class, 'sanearAjustes'],
                'default'           => OptionsRepository::defaults(),
            ]
        );

        add_settings_section(
            self::SECCION_GENERAL,
            __('General', 'flavor-news-hub'),
            static fn() => print '<p>' . esc_html__('Ajustes de ingesta y retención.', 'flavor-news-hub') . '</p>',
            'fnh-settings'
        );

        add_settings_field(
            'cron_interval_minutes',
            __('Intervalo de ingesta (minutos)', 'flavor-news-hub'),
            [self::class, 'campoIntervaloCron'],
            'fnh-settings',
            self::SECCION_GENERAL
        );

        add_settings_field(
            'ingest_log_retention_days',
            __('Retención de logs (días)', 'flavor-news-hub'),
            [self::class, 'campoRetencionLogs'],
            'fnh-settings',
            self::SECCION_GENERAL
        );

        add_settings_field(
            'item_retention_days',
            __('Retención de noticias (días)', 'flavor-news-hub'),
            [self::class, 'campoRetencionItems'],
            'fnh-settings',
            self::SECCION_GENERAL
        );

        add_settings_field(
            'donation_url',
            __('URL de donaciones', 'flavor-news-hub'),
            [self::class, 'campoUrlDonaciones'],
            'fnh-settings',
            self::SECCION_GENERAL
        );

        add_settings_section(
            self::SECCION_PRIVACIDAD,
            __('Privacidad y desinstalación', 'flavor-news-hub'),
            static fn() => print '<p>' . esc_html__('Controla qué ocurre con los datos al desinstalar el plugin.', 'flavor-news-hub') . '</p>',
            'fnh-settings'
        );

        add_settings_field(
            'delete_on_uninstall',
            __('Borrar todos los datos al desinstalar', 'flavor-news-hub'),
            [self::class, 'campoBorrarAlDesinstalar'],
            'fnh-settings',
            self::SECCION_PRIVACIDAD
        );
    }

    public static function render(): void
    {
        if (!current_user_can('manage_options')) {
            return;
        }
        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Ajustes · Flavor News Hub', 'flavor-news-hub'); ?></h1>
            <form method="post" action="options.php">
                <?php
                settings_fields(self::GRUPO_OPCIONES);
                do_settings_sections('fnh-settings');
                submit_button();
                ?>
            </form>

            <hr />

            <h2><?php esc_html_e('Páginas de frontend', 'flavor-news-hub'); ?></h2>
            <p><?php esc_html_e('El plugin puede generar automáticamente las páginas de Noticias, Radios, Vídeos y Colectivos con los shortcodes correspondientes.', 'flavor-news-hub'); ?></p>

            <table class="widefat striped" style="max-width:700px">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Página', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Estado', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Acciones', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach (CreadorPaginas::obtenerEstadoPaginas() as $pagina) : ?>
                    <tr>
                        <td>
                            <strong><?php echo esc_html($pagina['titulo']); ?></strong>
                            <code>/<?php echo esc_html($pagina['slug']); ?></code>
                        </td>
                        <td>
                            <?php if ($pagina['id'] > 0) : ?>
                                <span style="color:#46b450">&#10003; <?php esc_html_e('Creada', 'flavor-news-hub'); ?></span>
                            <?php else : ?>
                                <span style="color:#dc3232">&#10007; <?php esc_html_e('No existe', 'flavor-news-hub'); ?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if ($pagina['id'] > 0) : ?>
                                <a href="<?php echo esc_url($pagina['url']); ?>" target="_blank"><?php esc_html_e('Ver', 'flavor-news-hub'); ?></a>
                                &nbsp;&middot;&nbsp;
                                <a href="<?php echo esc_url($pagina['edit_url']); ?>"><?php esc_html_e('Editar', 'flavor-news-hub'); ?></a>
                            <?php else : ?>
                                &mdash;
                            <?php endif; ?>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>

            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin-top:1rem">
                <input type="hidden" name="action" value="fnh_crear_paginas" />
                <?php wp_nonce_field(CrearPaginasHandler::NONCE_ACCION); ?>
                <?php submit_button(__('Crear páginas que faltan', 'flavor-news-hub'), 'secondary', 'fnh_crear_paginas', false); ?>
            </form>
        </div>
        <?php
    }

    public static function campoIntervaloCron(): void
    {
        $valor = (int) OptionsRepository::todas()['cron_interval_minutes'];
        printf(
            '<input type="number" name="%1$s[cron_interval_minutes]" value="%2$d" min="%3$d" step="1" class="small-text" /> <p class="description">%4$s</p>',
            esc_attr(OptionsRepository::NOMBRE_OPCION),
            esc_attr((string) $valor),
            esc_attr((string) OptionsRepository::INTERVALO_MINIMO_MINUTOS),
            esc_html(sprintf(
                /* translators: %d es el intervalo mínimo */
                __('Mínimo %d minutos por respeto a los feeds de los medios. Recuerda que wp_cron se dispara oportunistamente en cada request, no en un cron de sistema.', 'flavor-news-hub'),
                OptionsRepository::INTERVALO_MINIMO_MINUTOS
            ))
        );
    }

    public static function campoRetencionLogs(): void
    {
        $valor = (int) OptionsRepository::todas()['ingest_log_retention_days'];
        printf(
            '<input type="number" name="%1$s[ingest_log_retention_days]" value="%2$d" min="%3$d" step="1" class="small-text" />',
            esc_attr(OptionsRepository::NOMBRE_OPCION),
            esc_attr((string) $valor),
            esc_attr((string) OptionsRepository::RETENCION_MINIMA_DIAS)
        );
    }

    public static function campoRetencionItems(): void
    {
        $valor = (int) (OptionsRepository::todas()['item_retention_days'] ?? 90);
        printf(
            '<input type="number" name="%1$s[item_retention_days]" value="%2$d" min="0" step="1" class="small-text" /> <p class="description">%3$s</p>',
            esc_attr(OptionsRepository::NOMBRE_OPCION),
            esc_attr((string) $valor),
            esc_html(sprintf(
                /* translators: %1$d es la retención mínima en días */
                __('Purga diaria de noticias más antiguas que N días. Mínimo %1$d. Poner 0 desactiva la purga (crecimiento ilimitado, no recomendado).', 'flavor-news-hub'),
                OptionsRepository::RETENCION_MINIMA_ITEMS_DIAS
            ))
        );
    }

    public static function campoUrlDonaciones(): void
    {
        $valor = (string) OptionsRepository::todas()['donation_url'];
        printf(
            '<input type="url" name="%1$s[donation_url]" value="%2$s" class="regular-text" placeholder="%3$s" /> <p class="description">%4$s</p>',
            esc_attr(OptionsRepository::NOMBRE_OPCION),
            esc_attr($valor),
            esc_attr(OptionsRepository::DONATION_URL_DEFAULT),
            esc_html__('URL del botón ♥ Apoyar del menú y del popup de donaciones. PayPal, Liberapay, Open Collective… cualquier destino público.', 'flavor-news-hub')
        );
    }

    public static function campoBorrarAlDesinstalar(): void
    {
        $activo = (bool) OptionsRepository::todas()['delete_on_uninstall'];
        printf(
            '<label><input type="checkbox" name="%1$s[delete_on_uninstall]" value="1" %2$s /> %3$s</label>',
            esc_attr(OptionsRepository::NOMBRE_OPCION),
            checked($activo, true, false),
            esc_html__('Sí, al desinstalar borra CPTs, términos, tabla de logs y ajustes.', 'flavor-news-hub')
        );
    }

    /**
     * Saneado de todo el array antes de persistirlo.
     *
     * @param mixed $valorBruto
     * @return array<string,mixed>
     */
    public static function sanearAjustes($valorBruto): array
    {
        $actuales = OptionsRepository::todas();
        if (!is_array($valorBruto)) {
            return $actuales;
        }

        $urlDonacionesBruta = isset($valorBruto['donation_url'])
            ? trim((string) $valorBruto['donation_url'])
            : (string) $actuales['donation_url'];
        $urlDonacionesSaneada = esc_url_raw($urlDonacionesBruta);

        $retencionItemsBruta = isset($valorBruto['item_retention_days'])
            ? (int) $valorBruto['item_retention_days']
            : (int) ($actuales['item_retention_days'] ?? 90);

        $nuevos = [
            'cron_interval_minutes'     => isset($valorBruto['cron_interval_minutes'])
                ? (int) $valorBruto['cron_interval_minutes']
                : $actuales['cron_interval_minutes'],
            'ingest_log_retention_days' => isset($valorBruto['ingest_log_retention_days'])
                ? (int) $valorBruto['ingest_log_retention_days']
                : $actuales['ingest_log_retention_days'],
            'item_retention_days'       => $retencionItemsBruta === 0
                ? 0
                : max(OptionsRepository::RETENCION_MINIMA_ITEMS_DIAS, $retencionItemsBruta),
            'delete_on_uninstall'       => !empty($valorBruto['delete_on_uninstall']),
            'donation_url'              => $urlDonacionesSaneada !== ''
                ? $urlDonacionesSaneada
                : OptionsRepository::DONATION_URL_DEFAULT,
        ];

        if ($nuevos['cron_interval_minutes'] < OptionsRepository::INTERVALO_MINIMO_MINUTOS) {
            $nuevos['cron_interval_minutes'] = OptionsRepository::INTERVALO_MINIMO_MINUTOS;
        }
        if ($nuevos['ingest_log_retention_days'] < OptionsRepository::RETENCION_MINIMA_DIAS) {
            $nuevos['ingest_log_retention_days'] = OptionsRepository::RETENCION_MINIMA_DIAS;
        }

        // Si cambia el intervalo, reagendamos el cron. Se hace aquí porque
        // la Settings API todavía no ha aplicado el valor nuevo a la DB;
        // reagendamos después, en el hook `update_option`.
        if ((int) $actuales['cron_interval_minutes'] !== $nuevos['cron_interval_minutes']) {
            add_action(
                'update_option_' . OptionsRepository::NOMBRE_OPCION,
                static function () {
                    Scheduler::reagendar();
                },
                10,
                0
            );
        }

        return $nuevos;
    }
}
