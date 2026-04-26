<?php
declare(strict_types=1);

namespace FlavorNewsHub\Notifications;

use FlavorNewsHub\Options\OptionsRepository;
use FlavorNewsHub\Stats\Recopilador;

/**
 * Informe semanal con estadísticas de feeds: top 10 más activos en los
 * últimos 7 días, fuentes muertas, fuentes con errores y propuestas
 * pendientes de moderación.
 *
 * Se ejecuta por wp_cron en el hook `Scheduler::HOOK_WEEKLY_REPORT`,
 * configurable en Ajustes (toggle + día de la semana). Si está
 * desactivado, el método `ejecutar()` sale sin enviar nada.
 *
 * El destino del email reutiliza la misma opción que `SubmitNotifier`:
 * `notify_email_target` con fallback a `admin_email` de WP.
 *
 * Toda la lógica de SQL — top activas, muertas, con error, totales — se
 * delega a `Stats\Recopilador`. Antes vivía duplicada aquí y en
 * `EstadisticasPage`, y al cambiar el umbral de "muerta" o el SQL de
 * top había que tocar dos sitios y los resultados podían divergir.
 */
final class WeeklyReport
{
    /** Cantidad máxima de filas listadas en cada bloque del informe. */
    public const TOPE_FILAS_LISTA = 10;

    public static function ejecutar(): void
    {
        $opciones = OptionsRepository::todas();
        if (empty($opciones['weekly_report_enabled'])) {
            return;
        }

        $emailDestino = trim((string) ($opciones['notify_email_target'] ?? ''));
        if ($emailDestino === '' || !is_email($emailDestino)) {
            $emailDestino = (string) get_option('admin_email');
        }
        if ($emailDestino === '' || !is_email($emailDestino)) {
            return;
        }

        $datosInforme = self::recopilarDatos();
        $cuerpoInforme = self::componerCuerpo($datosInforme);
        $asuntoInforme = sprintf(
            /* translators: %s nombre del sitio */
            __('[%s] Informe semanal de feeds', 'flavor-news-hub'),
            (string) get_bloginfo('name')
        );

        wp_mail($emailDestino, $asuntoInforme, $cuerpoInforme);
    }

    /** @return array<string,mixed> */
    private static function recopilarDatos(): array
    {
        return [
            'totales'      => Recopilador::totalesCatalogo(),
            'items_7d'     => Recopilador::actividadIngesta()['items_7d'],
            'top_activas'  => Recopilador::topFuentesActivas(self::TOPE_FILAS_LISTA, 7),
            'muertas'      => Recopilador::fuentesMuertas(self::TOPE_FILAS_LISTA),
            'con_errores'  => Recopilador::fuentesConError(self::TOPE_FILAS_LISTA),
        ];
    }

    /** @param array<string,mixed> $datosInforme */
    private static function componerCuerpo(array $datosInforme): string
    {
        $totales = $datosInforme['totales'];
        $lineasInforme = [];

        $lineasInforme[] = sprintf(
            __('Informe semanal · %s', 'flavor-news-hub'),
            wp_date('Y-m-d')
        );
        $lineasInforme[] = str_repeat('=', 56);
        $lineasInforme[] = '';
        $lineasInforme[] = __('Resumen', 'flavor-news-hub') . ':';
        $lineasInforme[] = sprintf(
            /* translators: %1$d activas, %2$d total */
            __('  Fuentes: %1$d activas / %2$d totales', 'flavor-news-hub'),
            (int) $totales['sources_activas'],
            (int) $totales['sources_total']
        );
        $lineasInforme[] = sprintf(
            /* translators: %d colectivos */
            __('  Colectivos: %d', 'flavor-news-hub'),
            (int) $totales['collectives_total']
        );
        $lineasInforme[] = sprintf(
            /* translators: %d radios */
            __('  Radios: %d', 'flavor-news-hub'),
            (int) $totales['radios_total']
        );
        $lineasInforme[] = sprintf(
            /* translators: %1$d total items, %2$d últimos 7d */
            __('  Items: %1$d totales · %2$d en los últimos 7 días', 'flavor-news-hub'),
            (int) $totales['items_total'],
            (int) $datosInforme['items_7d']
        );
        $lineasInforme[] = sprintf(
            /* translators: %1$d sources pendientes, %2$d colectivos pendientes */
            __('  Pendientes de moderación: %1$d medios · %2$d colectivos', 'flavor-news-hub'),
            (int) $totales['pendientes_sources'],
            (int) $totales['pendientes_collectives']
        );
        $lineasInforme[] = '';

        $lineasInforme[] = __('Top fuentes más activas (últimos 7 días)', 'flavor-news-hub') . ':';
        if (empty($datosInforme['top_activas'])) {
            $lineasInforme[] = '  ' . __('(ninguna)', 'flavor-news-hub');
        } else {
            foreach ($datosInforme['top_activas'] as $filaTopActiva) {
                $lineasInforme[] = sprintf(
                    '  %d items · %s',
                    (int) $filaTopActiva['items'],
                    (string) $filaTopActiva['nombre']
                );
            }
        }
        $lineasInforme[] = '';

        $lineasInforme[] = sprintf(
            /* translators: %d umbral en días */
            __('Fuentes muertas (sin items en %d días)', 'flavor-news-hub'),
            Recopilador::UMBRAL_MUERTA_DIAS
        ) . ':';
        if (empty($datosInforme['muertas'])) {
            $lineasInforme[] = '  ' . __('(ninguna — todo bien)', 'flavor-news-hub');
        } else {
            foreach ($datosInforme['muertas'] as $filaFuenteMuerta) {
                $ultimoItemIso = (string) ($filaFuenteMuerta['ultimo_item_utc'] ?? '');
                $textoUltimoItem = $ultimoItemIso !== ''
                    ? sprintf(
                        /* translators: %s fecha último item */
                        __('último: %s', 'flavor-news-hub'),
                        $ultimoItemIso
                    )
                    : __('sin items', 'flavor-news-hub');
                $lineasInforme[] = sprintf(
                    '  %s (%s)',
                    (string) $filaFuenteMuerta['nombre'],
                    $textoUltimoItem
                );
            }
        }
        $lineasInforme[] = '';

        $lineasInforme[] = __('Fuentes con error en la última ingesta', 'flavor-news-hub') . ':';
        if (empty($datosInforme['con_errores'])) {
            $lineasInforme[] = '  ' . __('(ninguna)', 'flavor-news-hub');
        } else {
            foreach ($datosInforme['con_errores'] as $filaFuenteError) {
                $textoErrorIngesta = (string) ($filaFuenteError['error'] ?? __('sin detalle', 'flavor-news-hub'));
                if ($textoErrorIngesta === '') {
                    $textoErrorIngesta = __('sin detalle', 'flavor-news-hub');
                }
                if (mb_strlen($textoErrorIngesta) > 120) {
                    $textoErrorIngesta = mb_substr($textoErrorIngesta, 0, 117) . '…';
                }
                $lineasInforme[] = sprintf(
                    '  %s — %s',
                    (string) $filaFuenteError['nombre'],
                    $textoErrorIngesta
                );
            }
        }
        $lineasInforme[] = '';

        $urlEstadoFuentes = admin_url('edit.php?post_type=fnh_source&page=fnh-estado-fuentes');
        $lineasInforme[] = __('Estado completo en el admin:', 'flavor-news-hub');
        $lineasInforme[] = $urlEstadoFuentes;
        $lineasInforme[] = '';
        $lineasInforme[] = sprintf(
            /* translators: %s nombre del sitio */
            __('— Flavor News Hub @ %s', 'flavor-news-hub'),
            (string) get_bloginfo('name')
        );

        return implode("\n", $lineasInforme);
    }
}
