<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Stats\Recopilador;
use FlavorNewsHub\Support\Transients;

/**
 * Pantalla "Estadísticas" del menú admin.
 *
 * Muestra contadores de descargas reales del proyecto leyendo la API
 * pública de GitHub Releases. Cero tracking en cliente: los contadores
 * los lleva GitHub server-side cada vez que alguien descarga un asset
 * (APK o ZIP del plugin), y los exponemos sumados aquí. Coherente con
 * el manifiesto del proyecto: no instrumentamos la app ni el plugin
 * para contar usuarios, sólo leemos lo que GitHub ya cuenta.
 *
 * Cache: transient `fnh_stats_descargas` con TTL 1h. Sin él tiraríamos
 * contra api.github.com en cada visita al admin (límite 60/h sin
 * token), y la mayoría de visitas serían refrescos cosméticos.
 */
final class EstadisticasPage
{
    public const SLUG = 'flavor-news-hub-stats';
    private const REPO_GITHUB = 'JosuIru/flavor-news-hub';
    private const TRANSIENT_CACHE = 'fnh_stats_descargas';

    /**
     * Hook del evento WP-Cron one-off que recalcula el bundle de descargas
     * en segundo plano cuando el render encuentra el caché frío. Así la
     * pantalla carga al instante sin esperar el HTTP a api.github.com.
     * Se engancha a `precalentarCacheDescargas` en Plugin::registrarHooks.
     */
    public const HOOK_REFRESCO_BG = 'fnh_refrescar_stats_descargas';

    /**
     * Option (no autoload) con la serie histórica de descargas. GitHub
     * sólo expone el contador ACUMULADO de cada asset, sin fecha, así que
     * guardamos un snapshot del acumulado por día y derivamos las
     * descargas diarias como la diferencia entre días consecutivos.
     * Formato: ['YYYY-MM-DD' => ['apk' => int, 'zip' => int]] (acumulado
     * crudo al cierre de ese día; se sobrescribe en cada pase del cron).
     */
    private const OPTION_HISTORICO = 'fnh_descargas_historico';

    /** Días de histórico que conservamos (poda lo más viejo). */
    private const DIAS_RETENCION_HISTORICO = 90;

    /** Días que mostramos en el gráfico de barras de descargas/día. */
    private const DIAS_GRAFICO = 30;

    /**
     * Render de la pantalla. Cuando se invoca desde `SistemaPage`
     * (tabs unificadas), `$conWrap` debe ser false para que el
     * contenedor `.wrap` y el `<h1>` los aporte la página padre y no
     * se dupliquen.
     */
    public static function render(bool $conWrap = true): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        // Botón "Refrescar ya": recalcula en línea y sobrescribe el
        // transient (la carga normal, en cambio, nunca bloquea).
        // Antes redirigíamos con `wp_safe_redirect` para limpiar la URL,
        // pero si cualquier plugin/tema imprime output antes de que
        // EstadisticasPage::render se ejecute (espacios, BOM…), los
        // headers ya están enviados y el redirect deja la pantalla en
        // blanco. Refrescar inline siempre funciona aunque los headers
        // ya hayan salido — el coste es que la URL sigue mostrando
        // `&refrescar=1&_wpnonce=…` hasta que el usuario navegue.
        $refrescoForzado = false;
        if (isset($_GET['refrescar'])) {
            check_admin_referer('fnh_stats_refrescar', '_wpnonce');
            // El refresco también invalida las stats internas
            // (Recopilador) para que el admin no vea el bundle de
            // GitHub fresco al lado de KPIs internos rancios.
            Recopilador::invalidarCacheStatsAdmin();
            // El admin pulsó "Refrescar ya" y acepta esperar: recalculamos
            // en línea (sí bloquea contra api.github.com). Si GitHub
            // falla, `recalcular…` deja intacto el bundle anterior.
            $datos = self::recalcularYGuardarDescargas();
            $refrescoForzado = !isset($datos['error']);
        } else {
            // Carga normal: NO bloqueamos el render esperando a GitHub.
            // Servimos el caché si existe; si está frío, devolvemos el
            // estado "calculando" y disparamos el refresco en segundo plano.
            $datos = self::leerDescargasParaRender();
        }
        // Calculado y cacheado una sola vez: lo comparten las dos
        // secciones internas (ingesta + medios) que pintamos abajo.
        $statsInternas = Recopilador::statsAdmin();

        ?>
        <?php if ($conWrap) : ?>
        <div class="wrap">
            <h1><?php esc_html_e('Estadísticas de descargas', 'flavor-news-hub'); ?></h1>
        <?php endif; ?>
            <p class="description">
                <?php esc_html_e('Contadores leídos de GitHub Releases. La app y el plugin no envían telemetría — sólo se cuenta lo que GitHub registra al servir el asset. Si has descargado tú un release recién publicado, márcalo abajo para descontarlo de los contadores.', 'flavor-news-hub'); ?>
            </p>

            <?php if ($refrescoForzado && !isset($datos['error'])) : ?>
                <div class="notice notice-success is-dismissible"><p>
                    <?php esc_html_e('Datos refrescados desde GitHub.', 'flavor-news-hub'); ?>
                </p></div>
            <?php endif; ?>

            <?php if (isset($datos['error'])) : ?>
                <div class="notice notice-error"><p><?php echo esc_html($datos['error']); ?></p></div>
            <?php elseif (isset($datos['calculando'])) : ?>
                <div class="notice notice-info"><p>
                    <?php esc_html_e('Calculando las descargas desde GitHub en segundo plano… recarga esta página en unos segundos.', 'flavor-news-hub'); ?>
                </p></div>
                <p>
                    <a href="<?php echo esc_url(remove_query_arg(['refrescar', '_wpnonce'])); ?>" class="button button-secondary">
                        <?php esc_html_e('Recargar', 'flavor-news-hub'); ?>
                    </a>
                </p>
            <?php else : ?>
                <div style="display:flex;gap:1em;margin:1em 0;flex-wrap:wrap;">
                    <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:160px;">
                        <div style="font-size:.85em;color:#666;"><?php esc_html_e('APKs descargados', 'flavor-news-hub'); ?></div>
                        <div style="font-size:2em;font-weight:600;"><?php echo (int) $datos['total_apk']; ?></div>
                    </div>
                    <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:160px;">
                        <div style="font-size:.85em;color:#666;"><?php esc_html_e('ZIPs del plugin', 'flavor-news-hub'); ?></div>
                        <div style="font-size:2em;font-weight:600;"><?php echo (int) $datos['total_zip']; ?></div>
                    </div>
                    <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:160px;">
                        <div style="font-size:.85em;color:#666;"><?php esc_html_e('Releases publicadas', 'flavor-news-hub'); ?></div>
                        <div style="font-size:2em;font-weight:600;"><?php echo (int) $datos['total_releases']; ?></div>
                    </div>
                </div>

                <p>
                    <?php
                    $textoCache = sprintf(
                        /* translators: %s = momento humanizado del último refresco */
                        esc_html__('Datos cacheados; última lectura: %s.', 'flavor-news-hub'),
                        esc_html(human_time_diff((int) $datos['ts_lectura']) . ' ' . __('atrás', 'flavor-news-hub'))
                    );
                    echo $textoCache;
                    ?>
                    <a href="<?php echo esc_url(wp_nonce_url(
                        add_query_arg('refrescar', '1'),
                        'fnh_stats_refrescar',
                        '_wpnonce'
                    )); ?>" class="button button-secondary">
                        <?php esc_html_e('Refrescar ya', 'flavor-news-hub'); ?>
                    </a>
                </p>

                <h2><?php esc_html_e('Desglose por release', 'flavor-news-hub'); ?></h2>
                <table class="widefat striped" style="max-width:900px;">
                    <thead>
                        <tr>
                            <th><?php esc_html_e('Release', 'flavor-news-hub'); ?></th>
                            <th><?php esc_html_e('Asset', 'flavor-news-hub'); ?></th>
                            <th style="text-align:right;"><?php esc_html_e('Descargas', 'flavor-news-hub'); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($datos['filas'] as $fila) : ?>
                            <tr>
                                <td><code><?php echo esc_html($fila['tag']); ?></code></td>
                                <td><?php echo esc_html($fila['nombre']); ?></td>
                                <td style="text-align:right;"><?php echo (int) $fila['descargas']; ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>

                <?php self::renderSeccionDescargasPorDia(); ?>
            <?php endif; ?>

            <?php self::renderSeccionIngesta($statsInternas['actividad']); ?>
            <?php self::renderSeccionMedios($statsInternas); ?>
        <?php if ($conWrap) : ?>
        </div>
        <?php endif; ?>
        <?php
    }

    /**
     * Recalcula el bundle de descargas y reescribe el transient.
     * Pensado para engancharse al final del cron de ingesta: así,
     * cuando el admin abre la pestaña Sistema → Descargas, no paga
     * el coste del HTTP a la API de GitHub (hasta 10s de timeout)
     * en el render.
     *
     * Si GitHub devuelve error, `recalcularYGuardarDescargas` no escribe
     * el transient — eso deja intacto el bundle anterior, que aunque
     * rancio sigue siendo más útil que un mensaje de fallo.
     */
    public static function precalentarCacheDescargas(): void
    {
        self::recalcularYGuardarDescargas();
    }

    /**
     * Lectura para el render: nunca bloquea contra api.github.com.
     * Devuelve el bundle cacheado si existe; si el caché está frío,
     * programa el recálculo en segundo plano y devuelve el estado
     * `['calculando' => true]` para que la pantalla cargue al instante.
     *
     * @return array{
     *   total_apk:int,total_zip:int,total_releases:int,
     *   filas:list<array{tag:string,nombre:string,descargas:int}>,
     *   ts_lectura:int
     * }|array{calculando:true}
     */
    private static function leerDescargasParaRender(): array
    {
        $cache = get_transient(self::TRANSIENT_CACHE);
        if (is_array($cache) && isset($cache['filas'])) {
            return $cache;
        }
        self::programarRefrescoEnSegundoPlano();
        return ['calculando' => true];
    }

    /**
     * Encola un evento WP-Cron one-off para recalcular el bundle sin
     * bloquear la petición actual. El guard `wp_next_scheduled` evita
     * apilar duplicados si el admin recarga varias veces mientras el
     * caché sigue frío.
     */
    private static function programarRefrescoEnSegundoPlano(): void
    {
        if (!wp_next_scheduled(self::HOOK_REFRESCO_BG)) {
            wp_schedule_single_event(time(), self::HOOK_REFRESCO_BG);
        }
    }

    /**
     * Recalcula el bundle pidiéndolo a la API de GitHub (bloqueante) y
     * reescribe el transient. Lo usan el precalentamiento por cron, el
     * refresco en segundo plano y el botón "Refrescar ya". Si GitHub
     * falla devuelve `['error' => …]` SIN tocar el transient, de modo
     * que el bundle anterior (aunque rancio) sigue disponible.
     *
     * @return array{
     *   total_apk:int,total_zip:int,total_releases:int,
     *   filas:list<array{tag:string,nombre:string,descargas:int}>,
     *   ts_lectura:int
     * }|array{error:string}
     */
    private static function recalcularYGuardarDescargas(): array
    {
        // Paginamos hasta agotar el histórico — antes pedíamos sólo
        // `per_page=30` y el total de descargas dejaba fuera todas las
        // releases anteriores a la 30ª. Con `per_page=100` (máximo que
        // permite GitHub) la mayoría de proyectos cabe en una página
        // sola; mantenemos un tope de 10 páginas (1000 releases) como
        // salvaguarda para no consumir el rate-limit en un loop si la
        // API empieza a comportarse de forma rara.
        $headers = ['Accept' => 'application/vnd.github+json'];
        if (defined('FLAVOR_GH_TOKEN') && FLAVOR_GH_TOKEN !== '') {
            $headers['Authorization'] = 'Bearer ' . FLAVOR_GH_TOKEN;
        }
        $perPage = 100;
        $paginaMaxima = 10;
        $cuerpo = [];
        for ($pagina = 1; $pagina <= $paginaMaxima; $pagina++) {
            $url = sprintf(
                'https://api.github.com/repos/%s/releases?per_page=%d&page=%d',
                self::REPO_GITHUB,
                $perPage,
                $pagina,
            );
            $respuesta = wp_remote_get($url, [
                'headers' => $headers,
                'timeout' => 10,
            ]);
            if (is_wp_error($respuesta)) {
                return ['error' => __('No se pudo contactar con la API de GitHub.', 'flavor-news-hub')];
            }
            $codigoHttp = (int) wp_remote_retrieve_response_code($respuesta);
            if ($codigoHttp !== 200) {
                return ['error' => sprintf(
                    /* translators: %d = código HTTP */
                    __('GitHub devolvió HTTP %d (puede ser rate-limit; configura FLAVOR_GH_TOKEN si te pasa a menudo).', 'flavor-news-hub'),
                    $codigoHttp
                )];
            }
            $paginaCuerpo = json_decode((string) wp_remote_retrieve_body($respuesta), true);
            if (!is_array($paginaCuerpo)) {
                return ['error' => __('Respuesta inesperada de GitHub.', 'flavor-news-hub')];
            }
            if ($paginaCuerpo === []) {
                break;
            }
            $cuerpo = array_merge($cuerpo, $paginaCuerpo);
            // Última página: GitHub habría devuelto los `perPage` items
            // si quedaran más. Cuando devuelve menos, no hay más que
            // pedir — paramos sin gastar otra petición vacía.
            if (count($paginaCuerpo) < $perPage) {
                break;
            }
        }

        // Offset de descargas marcadas como propias por el admin desde la
        // tab Descargas (ver `SistemaPage::offsetDescargasPropias`). Lo
        // aplicamos por release entera: si el admin se descarga una
        // versión, suele bajarse APK + ZIP — restamos el mismo offset
        // de cada asset para no dejar uno de los dos artificialmente
        // alto. Si el offset deja un asset en negativo lo capamos a 0.
        $offsetPropias = SistemaPage::offsetDescargasPropias();

        $totalApk = 0;
        $totalZip = 0;
        // Acumulados CRUDOS (sin restar el offset de descargas propias):
        // son los que alimentan el snapshot diario. Usar el crudo evita
        // que la serie por día se distorsione si el admin cambia el offset
        // a posteriori — el delta entre dos días sólo refleja descargas
        // reales de GitHub, no reajustes del contador propio.
        $totalApkCrudo = 0;
        $totalZipCrudo = 0;
        $filas = [];
        foreach ($cuerpo as $release) {
            if (!is_array($release)) continue;
            $tag = (string) ($release['tag_name'] ?? '');
            $offsetReleaseActual = (int) ($offsetPropias[$tag] ?? 0);
            foreach (($release['assets'] ?? []) as $asset) {
                if (!is_array($asset)) continue;
                $nombre = (string) ($asset['name'] ?? '');
                $descargasCrudas = (int) ($asset['download_count'] ?? 0);
                $extension = strtolower((string) pathinfo($nombre, PATHINFO_EXTENSION));
                if ($extension === 'apk') {
                    $totalApkCrudo += $descargasCrudas;
                } elseif ($extension === 'zip') {
                    $totalZipCrudo += $descargasCrudas;
                }
                // Total mostrado: descuenta las descargas propias del admin.
                $descargas = max(0, $descargasCrudas - $offsetReleaseActual);
                if ($descargas <= 0) continue;
                if ($extension === 'apk') {
                    $totalApk += $descargas;
                } elseif ($extension === 'zip') {
                    $totalZip += $descargas;
                }
                $filas[] = [
                    'tag'       => $tag,
                    'nombre'    => $nombre,
                    'descargas' => $descargas,
                ];
            }
        }

        // Registramos el acumulado del día para construir la serie por día
        // (GitHub no expone descargas con fecha, sólo el contador total).
        self::registrarSnapshotDiario($totalApkCrudo, $totalZipCrudo);

        $datos = [
            'total_apk'      => $totalApk,
            'total_zip'      => $totalZip,
            'total_releases' => count($cuerpo),
            'filas'          => $filas,
            'ts_lectura'     => time(),
        ];
        set_transient(self::TRANSIENT_CACHE, $datos, Transients::CACHE_DESCARGAS_GITHUB);
        return $datos;
    }

    /**
     * Guarda (o sobrescribe) el acumulado crudo del día en curso. Como el
     * cron pasa varias veces al día, el día queda con el último valor
     * leído; el delta diario se deriva al renderizar. Poda el histórico a
     * `DIAS_RETENCION_HISTORICO` días para no inflar la tabla de options.
     */
    private static function registrarSnapshotDiario(int $apkCrudo, int $zipCrudo): void
    {
        $hoy = current_time('Y-m-d');
        $historico = get_option(self::OPTION_HISTORICO, []);
        if (!is_array($historico)) {
            $historico = [];
        }
        $historico[$hoy] = ['apk' => $apkCrudo, 'zip' => $zipCrudo];
        if (count($historico) > self::DIAS_RETENCION_HISTORICO) {
            // Las claves son 'YYYY-MM-DD': el orden lexicográfico coincide
            // con el cronológico, así que ksort + slice deja los más nuevos.
            ksort($historico);
            $historico = array_slice($historico, -self::DIAS_RETENCION_HISTORICO, null, true);
        }
        update_option(self::OPTION_HISTORICO, $historico, false);
    }

    /**
     * Deriva las descargas POR DÍA a partir de los snapshots acumulados:
     * cada día vale `acumulado[día] - acumulado[día_anterior]`. El primer
     * día no tiene referencia previa y se omite. Capamos a 0 los deltas
     * negativos (pueden aparecer si se borra un asset y el acumulado baja).
     *
     * @return list<array{fecha:string,apk:int,zip:int,total:int}>
     */
    private static function serieDescargasPorDia(): array
    {
        $historico = get_option(self::OPTION_HISTORICO, []);
        if (!is_array($historico) || count($historico) < 2) {
            return [];
        }
        ksort($historico);
        $serie = [];
        $diaPrevio = null;
        foreach ($historico as $fecha => $acumulado) {
            if (!is_array($acumulado)) {
                continue;
            }
            $apk = (int) ($acumulado['apk'] ?? 0);
            $zip = (int) ($acumulado['zip'] ?? 0);
            if ($diaPrevio !== null) {
                $deltaApk = max(0, $apk - $diaPrevio['apk']);
                $deltaZip = max(0, $zip - $diaPrevio['zip']);
                $serie[] = [
                    'fecha' => (string) $fecha,
                    'apk'   => $deltaApk,
                    'zip'   => $deltaZip,
                    'total' => $deltaApk + $deltaZip,
                ];
            }
            $diaPrevio = ['apk' => $apk, 'zip' => $zip];
        }
        return $serie;
    }

    /**
     * Sección "Descargas por día": gráfico de barras (CSS, sin librerías)
     * de los últimos `DIAS_GRAFICO` días más una tabla. Si aún no hay al
     * menos dos snapshots, explica que la serie se construye desde ahora.
     */
    private static function renderSeccionDescargasPorDia(): void
    {
        $serie = self::serieDescargasPorDia();
        ?>
        <h2><?php esc_html_e('Descargas por día', 'flavor-news-hub'); ?></h2>
        <?php if ($serie === []) : ?>
            <p class="description">
                <?php esc_html_e('Aún recopilando datos. GitHub no expone las descargas con fecha, sólo el contador acumulado, así que esta serie se construye a partir de un snapshot diario y empieza a poblarse desde ahora: vuelve dentro de uno o dos días.', 'flavor-news-hub'); ?>
            </p>
        <?php else :
            $ultimos = array_slice($serie, -self::DIAS_GRAFICO);
            $maximo = 0;
            foreach ($ultimos as $dia) {
                if ($dia['total'] > $maximo) {
                    $maximo = $dia['total'];
                }
            }
            ?>
            <div style="display:flex;gap:1.2em;align-items:center;margin:.5em 0;font-size:.85em;color:#555;">
                <span style="display:inline-flex;align-items:center;gap:.35em;">
                    <span style="width:12px;height:12px;background:#2271b1;border-radius:2px;display:inline-block;"></span>
                    <?php esc_html_e('APK', 'flavor-news-hub'); ?>
                </span>
                <span style="display:inline-flex;align-items:center;gap:.35em;">
                    <span style="width:12px;height:12px;background:#00a32a;border-radius:2px;display:inline-block;"></span>
                    <?php esc_html_e('ZIP del plugin', 'flavor-news-hub'); ?>
                </span>
            </div>
            <div style="display:flex;align-items:flex-end;gap:3px;height:160px;max-width:900px;border-bottom:1px solid #ccd0d4;padding-bottom:2px;margin:0 0 1em;">
                <?php foreach ($ultimos as $dia) :
                    // Barra apilada: segmento APK (abajo) + segmento ZIP
                    // (arriba). Cada segmento se escala contra el MISMO
                    // máximo (el total del día más alto), así la altura total
                    // de la columna sigue representando el total del día y a
                    // la vez se ve el reparto. Damos 2px mínimos a cualquier
                    // valor > 0 que redondee a 0 para que no desaparezca.
                    $alturaApk = $maximo > 0 ? (int) round($dia['apk'] / $maximo * 150) : 0;
                    $alturaZip = $maximo > 0 ? (int) round($dia['zip'] / $maximo * 150) : 0;
                    if ($dia['apk'] > 0 && $alturaApk < 2) {
                        $alturaApk = 2;
                    }
                    if ($dia['zip'] > 0 && $alturaZip < 2) {
                        $alturaZip = 2;
                    }
                    $titulo = sprintf(
                        /* translators: 1: fecha, 2: total, 3: APK, 4: ZIP */
                        __('%1$s — %2$d descargas (APK %3$d, ZIP %4$d)', 'flavor-news-hub'),
                        $dia['fecha'],
                        $dia['total'],
                        $dia['apk'],
                        $dia['zip']
                    );
                    // El redondeo del segmento superior visible va arriba: si
                    // hay ZIP, lo lleva el ZIP; si no, el APK.
                    $radioApk = $alturaZip > 0 ? '0' : '2px 2px 0 0';
                    ?>
                    <div title="<?php echo esc_attr($titulo); ?>"
                         style="flex:1 1 0;min-width:4px;display:flex;flex-direction:column;justify-content:flex-end;">
                        <?php if ($alturaZip > 0) : ?>
                            <div style="height:<?php echo (int) $alturaZip; ?>px;background:#00a32a;border-radius:2px 2px 0 0;"></div>
                        <?php endif; ?>
                        <?php if ($alturaApk > 0) : ?>
                            <div style="height:<?php echo (int) $alturaApk; ?>px;background:#2271b1;border-radius:<?php echo esc_attr($radioApk); ?>;"></div>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>
            <p class="description">
                <?php echo esc_html(sprintf(
                    /* translators: %d = número de días */
                    __('Descargas diarias de los últimos %d días (pasa el ratón por cada barra para el detalle).', 'flavor-news-hub'),
                    count($ultimos)
                )); ?>
            </p>
            <table class="widefat striped" style="max-width:500px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Día', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('APK', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('ZIP', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Total', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach (array_reverse($ultimos) as $dia) : ?>
                        <tr>
                            <td><?php echo esc_html($dia['fecha']); ?></td>
                            <td style="text-align:right;"><?php echo (int) $dia['apk']; ?></td>
                            <td style="text-align:right;"><?php echo (int) $dia['zip']; ?></td>
                            <td style="text-align:right;"><strong><?php echo (int) $dia['total']; ?></strong></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif;
    }

    /**
     * Sección "Ingesta": items nuevos por ventana, tasa de éxito, último
     * cron, próximo cron. Recibe el bloque ya calculado del bundle
     * cacheado en `Recopilador::statsAdmin()`.
     *
     * @param array<string, mixed> $stats
     */
    private static function renderSeccionIngesta(array $stats): void
    {
        ?>
        <h2 style="margin-top:2em;"><?php esc_html_e('Ingesta', 'flavor-news-hub'); ?></h2>
        <p class="description">
            <?php esc_html_e('Volumen de noticias entrando al sistema y salud del cron.', 'flavor-news-hub'); ?>
        </p>
        <div style="display:flex;gap:1em;margin:1em 0;flex-wrap:wrap;">
            <?php
            self::renderTarjeta(__('Items últimas 24h', 'flavor-news-hub'), (string) $stats['items_24h']);
            self::renderTarjeta(__('Items últimos 7 días', 'flavor-news-hub'), (string) $stats['items_7d']);
            self::renderTarjeta(__('Items últimos 30 días', 'flavor-news-hub'), (string) $stats['items_30d']);
            self::renderTarjeta(
                __('Tasa de éxito 7d', 'flavor-news-hub'),
                $stats['tasa_exito_7d'] . '%',
                sprintf(
                    /* translators: %1$d ingestas totales, %2$d con error */
                    __('%1$d ingestas · %2$d con error', 'flavor-news-hub'),
                    (int) $stats['ingestas_7d'],
                    (int) $stats['ingestas_error_7d']
                )
            );
            ?>
        </div>
        <p>
            <?php
            $ultimaIngesta = $stats['ultima_ingesta_utc'];
            $proximoCron = $stats['proximo_cron_utc'];
            if ($ultimaIngesta) {
                $tsUltima = strtotime($ultimaIngesta);
                if ($tsUltima !== false) {
                    printf(
                        /* translators: %s = momento humanizado de la última ingesta */
                        esc_html__('Última ingesta exitosa: %s.', 'flavor-news-hub'),
                        '<strong>' . esc_html(human_time_diff($tsUltima) . ' ' . __('atrás', 'flavor-news-hub')) . '</strong>'
                    );
                }
            } else {
                esc_html_e('Aún no hay ingestas exitosas registradas.', 'flavor-news-hub');
            }
            echo ' ';
            if ($proximoCron) {
                $tsProx = strtotime($proximoCron);
                if ($tsProx !== false) {
                    printf(
                        /* translators: %s = momento humanizado del próximo cron */
                        esc_html__('Próxima programada: %s.', 'flavor-news-hub'),
                        '<strong>' . esc_html(human_time_diff($tsProx) . ' ' . __('por delante', 'flavor-news-hub')) . '</strong>'
                    );
                }
            }
            ?>
        </p>
        <?php
    }

    /**
     * Sección "Medios": totales del catálogo, top fuentes activas, fuentes
     * muertas, fuentes con error, distribución por tipo de feed.
     * Recibe los bloques ya calculados del bundle cacheado en
     * `Recopilador::statsAdmin()`.
     *
     * @param array{
     *   totales: array<string, int>,
     *   top: list<array{source_id:int, nombre:string, items:int}>,
     *   muertas: list<array{source_id:int, nombre:string, ultimo_item_utc:?string}>,
     *   errores: list<array{source_id:int, nombre:string, error:string}>,
     *   distribucion: list<array{tipo:string, total:int}>
     * } $statsInternas
     */
    private static function renderSeccionMedios(array $statsInternas): void
    {
        $totales = $statsInternas['totales'];
        $top = $statsInternas['top'];
        $muertas = $statsInternas['muertas'];
        $errores = $statsInternas['errores'];
        $distribucion = $statsInternas['distribucion'];
        ?>
        <h2 style="margin-top:2em;"><?php esc_html_e('Medios', 'flavor-news-hub'); ?></h2>
        <p class="description">
            <?php esc_html_e('Catálogo agregado y salud individual de cada fuente activa.', 'flavor-news-hub'); ?>
        </p>
        <div style="display:flex;gap:1em;margin:1em 0;flex-wrap:wrap;">
            <?php
            self::renderTarjeta(
                __('Fuentes', 'flavor-news-hub'),
                (string) $totales['sources_activas'],
                sprintf(
                    /* translators: %d total de fuentes */
                    __('de %d publicadas', 'flavor-news-hub'),
                    (int) $totales['sources_total']
                )
            );
            self::renderTarjeta(__('Colectivos', 'flavor-news-hub'), (string) $totales['collectives_total']);
            self::renderTarjeta(__('Radios', 'flavor-news-hub'), (string) $totales['radios_total']);
            self::renderTarjeta(__('Items totales', 'flavor-news-hub'), (string) $totales['items_total']);
            $pendientes = (int) $totales['pendientes_sources'] + (int) $totales['pendientes_collectives'];
            if ($pendientes > 0) {
                self::renderTarjeta(
                    __('Pendientes', 'flavor-news-hub'),
                    (string) $pendientes,
                    sprintf(
                        /* translators: %1$d sources, %2$d colectivos */
                        __('%1$d medios · %2$d colectivos', 'flavor-news-hub'),
                        (int) $totales['pendientes_sources'],
                        (int) $totales['pendientes_collectives']
                    )
                );
            }
            ?>
        </div>

        <?php if ($distribucion !== []) : ?>
            <p style="margin:1em 0;">
                <strong><?php esc_html_e('Distribución por tipo de feed:', 'flavor-news-hub'); ?></strong>
                <?php
                $partes = array_map(
                    static fn(array $f) => esc_html($f['tipo']) . ' (' . (int) $f['total'] . ')',
                    $distribucion
                );
                echo implode(' · ', $partes);
                ?>
            </p>
        <?php endif; ?>

        <h3 style="margin-top:1.5em;"><?php esc_html_e('Top fuentes más activas (últimos 7 días)', 'flavor-news-hub'); ?></h3>
        <?php if ($top === []) : ?>
            <p><?php esc_html_e('Aún no hay actividad reciente para mostrar.', 'flavor-news-hub'); ?></p>
        <?php else : ?>
            <table class="widefat striped" style="max-width:900px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Fuente', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Items 7d', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($top as $fila) : ?>
                        <tr>
                            <td><?php echo esc_html($fila['nombre']); ?></td>
                            <td style="text-align:right;"><?php echo (int) $fila['items']; ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>

        <?php if ($muertas !== []) : ?>
            <h3 style="margin-top:1.5em;color:#dc3232;">
                <?php
                printf(
                    /* translators: %d días umbral para "muerta" */
                    esc_html__('Fuentes muertas (sin items en %d días)', 'flavor-news-hub'),
                    (int) Recopilador::UMBRAL_MUERTA_DIAS
                );
                ?>
            </h3>
            <table class="widefat striped" style="max-width:900px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Fuente', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Último item', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($muertas as $fila) : ?>
                        <tr>
                            <td><?php echo esc_html($fila['nombre']); ?></td>
                            <td>
                                <?php
                                if ($fila['ultimo_item_utc']) {
                                    $ts = strtotime($fila['ultimo_item_utc']);
                                    if ($ts !== false) {
                                        echo esc_html(human_time_diff($ts) . ' ' . __('atrás', 'flavor-news-hub'));
                                    }
                                } else {
                                    esc_html_e('sin items', 'flavor-news-hub');
                                }
                                ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>

        <?php if ($errores !== []) : ?>
            <h3 style="margin-top:1.5em;color:#dc3232;">
                <?php esc_html_e('Fuentes con error en la última ingesta', 'flavor-news-hub'); ?>
            </h3>
            <table class="widefat striped" style="max-width:900px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Fuente', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Error', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($errores as $fila) : ?>
                        <tr>
                            <td><?php echo esc_html($fila['nombre']); ?></td>
                            <td><code style="font-size:.85em;"><?php echo esc_html($fila['error']); ?></code></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
        <?php
    }

    /**
     * Tarjeta visual reutilizable para los KPIs de las dos secciones.
     */
    private static function renderTarjeta(string $etiqueta, string $valorPrincipal, string $sub = ''): void
    {
        ?>
        <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:160px;">
            <div style="font-size:.85em;color:#666;"><?php echo esc_html($etiqueta); ?></div>
            <div style="font-size:2em;font-weight:600;"><?php echo esc_html($valorPrincipal); ?></div>
            <?php if ($sub !== '') : ?>
                <div style="font-size:.8em;color:#888;margin-top:.25em;"><?php echo esc_html($sub); ?></div>
            <?php endif; ?>
        </div>
        <?php
    }
}
