<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\REST\AppUpdateEndpoint;
use FlavorNewsHub\Stats\UsoTracker;

/**
 * Pantalla unificada "Sistema" — un único punto de entrada para la
 * salud operacional del plugin. Antes había siete entradas de menú
 * (Resumen, Catálogo, Estado de fuentes, Log de ingesta,
 * Estadísticas, Ajustes y Temáticas), lo que obligaba al admin a
 * pasear por varias pantallas para responder preguntas básicas:
 * "¿se está usando esto?", "¿cuántas descargas son mías?", "¿hay
 * fuentes muertas?".
 *
 * Esta página agrupa esas preguntas en cuatro tabs:
 *
 *   - resumen   → contadores generales y últimas ingestas (lo que
 *                 antes era DashboardPage).
 *   - fuentes   → estado individual de cada source activa, con
 *                 acciones de mantenimiento (lo que antes era
 *                 EstadoFuentesPage).
 *   - descargas → KPIs de GitHub Releases + posibilidad de marcar
 *                 una descarga como "mía" para no contaminar el
 *                 contador con descargas del propio dev.
 *   - uso       → métrica anónima agregada del consumo de la API
 *                 pública (clientes app, peticiones por endpoint,
 *                 días con actividad). Sin IPs, sin cookies.
 *
 * Las tabs antiguas (Catálogo, Log de ingesta, Estadísticas, Ajustes,
 * Temáticas) siguen siendo páginas separadas porque cada una tiene
 * un propósito distinto (configuración, edición o inspección densa
 * de un solo ámbito) y meterlas todas aquí haría la pantalla
 * inmanejable. La consolidación afecta sólo a las pantallas de
 * estado/observabilidad, que se beneficiaban más de tenerlas
 * juntas.
 */
final class SistemaPage
{
    public const SLUG = 'flavor-news-hub';

    public const TAB_RESUMEN = 'resumen';
    public const TAB_FUENTES = 'fuentes';
    public const TAB_ESTADISTICAS = 'estadisticas';
    public const TAB_ACTUALIZACIONES_APP = 'actualizaciones-app';

    // Slugs antiguos ('descargas' y 'uso' eran tabs separadas) mapeados a
    // la tab fusionada, para no romper enlaces guardados ni bookmarks.
    private const TABS_LEGACY = [
        'descargas' => self::TAB_ESTADISTICAS,
        'uso'       => self::TAB_ESTADISTICAS,
    ];

    /**
     * Lista de tabs en el orden que aparecerán. Cada entrada tiene
     * etiqueta i18n y la capability mínima para verla — algunas
     * tabs (descargas, fuentes con acciones) requieren manage_options.
     *
     * @return array<string,array{label:string,cap:string}>
     */
    private static function tabs(): array
    {
        return [
            self::TAB_RESUMEN            => ['label' => __('Resumen', 'flavor-news-hub'),        'cap' => 'edit_posts'],
            self::TAB_FUENTES            => ['label' => __('Fuentes', 'flavor-news-hub'),        'cap' => 'manage_options'],
            self::TAB_ESTADISTICAS      => ['label' => __('Estadísticas', 'flavor-news-hub'),   'cap' => 'edit_posts'],
            self::TAB_ACTUALIZACIONES_APP => ['label' => __('Actualizaciones app', 'flavor-news-hub'), 'cap' => 'manage_options'],
        ];
    }

    public static function render(): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        $tabsDisponibles = self::tabs();
        $tabSolicitada = isset($_GET['tab']) ? sanitize_key((string) $_GET['tab']) : self::TAB_RESUMEN;
        // Redirige slugs antiguos ('descargas', 'uso') a la tab fusionada.
        $tabSolicitada = self::TABS_LEGACY[$tabSolicitada] ?? $tabSolicitada;
        if (!isset($tabsDisponibles[$tabSolicitada])) {
            $tabSolicitada = self::TAB_RESUMEN;
        }
        // Si el usuario no tiene capability para la tab solicitada,
        // caemos a Resumen (siempre tiene `edit_posts` por la guarda
        // inicial). Evita 403 en mitad del render.
        $capRequerida = $tabsDisponibles[$tabSolicitada]['cap'];
        if (!current_user_can($capRequerida)) {
            $tabSolicitada = self::TAB_RESUMEN;
        }

        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Sistema', 'flavor-news-hub'); ?></h1>
            <p class="description">
                <?php esc_html_e('Estado operacional del plugin: resumen de contadores, salud de fuentes, estadísticas de audiencia (app y descargas) y anuncio de actualizaciones.', 'flavor-news-hub'); ?>
            </p>

            <h2 class="nav-tab-wrapper" style="margin-bottom:20px;">
                <?php foreach ($tabsDisponibles as $slugTab => $datosTab) : ?>
                    <?php if (!current_user_can($datosTab['cap'])) continue; ?>
                    <a class="nav-tab <?php echo $slugTab === $tabSolicitada ? 'nav-tab-active' : ''; ?>"
                       href="<?php echo esc_url(add_query_arg([
                           'page' => self::SLUG,
                           'tab'  => $slugTab,
                       ], admin_url('admin.php'))); ?>">
                        <?php echo esc_html($datosTab['label']); ?>
                    </a>
                <?php endforeach; ?>
            </h2>

            <?php
            switch ($tabSolicitada) {
                case self::TAB_FUENTES:
                    EstadoFuentesPage::render(false);
                    break;
                case self::TAB_ESTADISTICAS:
                    self::renderTabEstadisticas();
                    break;
                case self::TAB_ACTUALIZACIONES_APP:
                    self::renderTabActualizacionesApp();
                    break;
                case self::TAB_RESUMEN:
                default:
                    DashboardPage::render(false);
                    break;
            }
            ?>
        </div>
        <?php
    }

    /**
     * Tab "Estadísticas": audiencia del proyecto en un solo sitio. Fusiona
     * lo que antes eran tres bloques dispersos, ordenados de más fiable a
     * más ruidoso:
     *
     *  1. Actividad real de la app por versión — señal limpia (cruce de
     *     hashes de UA), responde a "¿la gente actualiza?".
     *  2. Uso de la API — volumen agregado por endpoint y día.
     *  3. Descargas de GitHub — contadores brutos, inflados por bots y
     *     sin contar F-Droid; se dejan al final, con su aviso.
     *
     * El procesado de formularios (marcar descarga propia / resetear
     * offset) vive aquí arriba porque debe correr ANTES de que
     * `EstadisticasPage` lea los contadores en la sección 3.
     */
    private static function renderTabEstadisticas(): void
    {
        // Formularios de la sección "Descargas de GitHub". Se procesan al
        // principio para que el offset ya esté aplicado cuando se renderice
        // esa sección más abajo.
        if (
            isset($_POST['fnh_marcar_descarga_propia'], $_POST['_wpnonce'], $_POST['tag'])
            && current_user_can('edit_posts')
            && wp_verify_nonce((string) $_POST['_wpnonce'], 'fnh_marcar_descarga_propia')
        ) {
            self::incrementarOffsetDescargaPropia((string) $_POST['tag']);
            delete_transient('fnh_stats_descargas');
            echo '<div class="notice notice-success is-dismissible"><p>'
                . esc_html__('Descarga marcada como tuya. Los contadores se descontarán a partir del próximo refresco.', 'flavor-news-hub')
                . '</p></div>';
        }
        if (
            isset($_POST['fnh_resetear_descargas_propias'], $_POST['_wpnonce'])
            && current_user_can('edit_posts')
            && wp_verify_nonce((string) $_POST['_wpnonce'], 'fnh_resetear_descargas_propias')
        ) {
            delete_option('fnh_descargas_propias_offset');
            delete_transient('fnh_stats_descargas');
            echo '<div class="notice notice-success is-dismissible"><p>'
                . esc_html__('Offset de descargas propias reseteado a cero.', 'flavor-news-hub')
                . '</p></div>';
        }

        $diasVentana = isset($_GET['dias']) ? max(1, min(90, (int) $_GET['dias'])) : 7;
        ?>
        <h2><?php esc_html_e('Audiencia del proyecto', 'flavor-news-hub'); ?></h2>
        <p class="description" style="max-width:640px;">
            <?php esc_html_e('De la señal más fiable a la más ruidosa: primero qué versiones de la app están activas de verdad, luego el uso de la API, y al final los contadores de descargas de GitHub (útiles pero inflados por bots y sin contar F-Droid).', 'flavor-news-hub'); ?>
        </p>

        <p>
            <?php esc_html_e('Ventana (afecta a app y API, no a los contadores de GitHub):', 'flavor-news-hub'); ?>
            <?php foreach ([1, 7, 30, 90] as $dias) : ?>
                <a href="<?php echo esc_url(add_query_arg([
                    'page' => self::SLUG,
                    'tab'  => self::TAB_ESTADISTICAS,
                    'dias' => $dias,
                ], admin_url('admin.php'))); ?>"
                   class="button <?php echo $diasVentana === $dias ? 'button-primary' : 'button-secondary'; ?>"
                   style="margin-right:.3em;">
                    <?php echo esc_html(sprintf(_n('%d día', '%d días', $dias, 'flavor-news-hub'), $dias)); ?>
                </a>
            <?php endforeach; ?>
        </p>

        <?php
        self::renderSeccionActividadApp($diasVentana);
        self::renderSeccionUsoApi($diasVentana);
        self::renderSeccionDescargasGitHub();
    }

    /**
     * Sección 1 (señal fiable): reparto de actividad por versión de la app.
     * Cruza los hashes de UA de la tabla de uso con los hashes
     * reconstruidos de cada release conocida — ver `UsoTracker`. La lista
     * de versiones sale del listado que ya cachea el endpoint de
     * actualización, así se auto-mantiene con cada release nueva.
     */
    private static function renderSeccionActividadApp(int $diasVentana): void
    {
        $releasesConocidas = AppUpdateEndpoint::listarReleasesParaAdmin(15);
        $versionesConocidas = array_column($releasesConocidas, 'version');
        $actividad = UsoTracker::actividadPorVersion($versionesConocidas, $diasVentana);
        $totalVersionado = array_sum(array_column($actividad['por_version'], 'peticiones'));
        ?>
        <h2 style="margin-top:2.5em;border-top:1px solid #dcdcde;padding-top:1.5em;">
            <?php esc_html_e('1. Actividad real de la app, por versión', 'flavor-news-hub'); ?>
        </h2>
        <p class="description" style="max-width:640px;">
            <?php esc_html_e('La señal fiable para responder "¿la gente actualiza?". Reconstruye el reparto cruzando el hash del User-Agent con el de cada release. Es VOLUMEN de peticiones por versión, no número de usuarios (todas las instalaciones de un build comparten hash), pero el reparto relativo lo dice todo: si una versión vieja concentra la actividad y la última casi nada, no están actualizando. Incluye a los usuarios de F-Droid (también consultan la API). "Otros" son navegadores, bots y versiones fuera de las últimas releases.', 'flavor-news-hub'); ?>
        </p>
        <?php if ($totalVersionado === 0) : ?>
            <p><?php esc_html_e('Todavía no hay actividad identificable de la app en esta ventana (sólo tráfico de "otros").', 'flavor-news-hub'); ?></p>
        <?php else : ?>
            <table class="widefat striped" style="max-width:600px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Versión', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Plataforma', 'flavor-news-hub'); ?></th>
                        <th><?php esc_html_e('Canal', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Peticiones', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('% app', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($actividad['por_version'] as $fila) : ?>
                        <tr>
                            <td><code><?php echo esc_html((string) $fila['version']); ?></code></td>
                            <td><?php echo esc_html((string) $fila['plataforma']); ?></td>
                            <td><?php echo esc_html((string) $fila['canal']); ?></td>
                            <td style="text-align:right;"><?php echo (int) $fila['peticiones']; ?></td>
                            <td style="text-align:right;"><?php echo esc_html(number_format(100 * $fila['peticiones'] / $totalVersionado, 1)); ?>%</td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
                <tfoot>
                    <tr>
                        <td colspan="3"><em><?php esc_html_e('Otros (web, bots, versiones antiguas)', 'flavor-news-hub'); ?></em></td>
                        <td style="text-align:right;"><em><?php echo (int) $actividad['otros']; ?></em></td>
                        <td style="text-align:right;">—</td>
                    </tr>
                </tfoot>
            </table>
        <?php endif; ?>
        <?php
    }

    /**
     * Sección 2: uso agregado de la API pública (endpoints y días). Es el
     * mismo dato que alimenta la sección 1, visto por endpoint/día en vez
     * de por versión.
     */
    private static function renderSeccionUsoApi(int $diasVentana): void
    {
        $resumen = UsoTracker::resumen($diasVentana);
        ?>
        <h2 style="margin-top:2.5em;border-top:1px solid #dcdcde;padding-top:1.5em;">
            <?php esc_html_e('2. Uso de la API pública', 'flavor-news-hub'); ?>
        </h2>
        <p class="description" style="max-width:640px;">
            <?php esc_html_e('Métrica agregada anónima (día, endpoint, hash MD5 truncado del User-Agent). Sin IPs ni cookies. Responde a "¿se usa la app?" sin poder responder a "¿quién la usa?". Retención: 90 días.', 'flavor-news-hub'); ?>
        </p>

        <div style="display:flex;gap:1em;margin:1em 0;flex-wrap:wrap;">
            <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:200px;">
                <div style="font-size:.85em;color:#666;"><?php esc_html_e('Peticiones totales', 'flavor-news-hub'); ?></div>
                <div style="font-size:2em;font-weight:600;"><?php echo (int) $resumen['total_peticiones']; ?></div>
            </div>
            <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:200px;">
                <div style="font-size:.85em;color:#666;"><?php esc_html_e('Variantes de cliente', 'flavor-news-hub'); ?></div>
                <div style="font-size:2em;font-weight:600;"><?php echo (int) $resumen['uas_distintos']; ?></div>
                <div style="font-size:.8em;color:#888;margin-top:.25em;">
                    <?php esc_html_e('versión + plataforma de la app, navegadores, curl, bots… No cuenta instalaciones únicas.', 'flavor-news-hub'); ?>
                </div>
            </div>
            <div style="background:#fff;padding:1em 1.5em;border:1px solid #ccd0d4;min-width:200px;">
                <div style="font-size:.85em;color:#666;"><?php esc_html_e('Días con actividad', 'flavor-news-hub'); ?></div>
                <div style="font-size:2em;font-weight:600;"><?php echo (int) count($resumen['por_dia']); ?></div>
                <div style="font-size:.8em;color:#888;margin-top:.25em;">
                    <?php
                    printf(
                        /* translators: %d días en la ventana */
                        esc_html__('de %d en la ventana', 'flavor-news-hub'),
                        (int) $resumen['dias']
                    );
                    ?>
                </div>
            </div>
        </div>

        <?php if ($resumen['total_peticiones'] === 0) : ?>
            <p>
                <?php esc_html_e('Aún no hay registros. El tracker se activa con la próxima petición a flavor-news/v1/...', 'flavor-news-hub'); ?>
            </p>
        <?php else : ?>
            <h3 style="margin-top:1.5em;"><?php esc_html_e('Peticiones por endpoint', 'flavor-news-hub'); ?></h3>
            <table class="widefat striped" style="max-width:600px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Endpoint', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Peticiones', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($resumen['por_endpoint'] as $endpoint => $peticiones) : ?>
                        <tr>
                            <td><code><?php echo esc_html((string) $endpoint); ?></code></td>
                            <td style="text-align:right;"><?php echo (int) $peticiones; ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>

            <h3 style="margin-top:1.5em;"><?php esc_html_e('Peticiones por día', 'flavor-news-hub'); ?></h3>
            <table class="widefat striped" style="max-width:600px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Día', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Peticiones', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($resumen['por_dia'] as $dia => $peticiones) : ?>
                        <tr>
                            <td><?php echo esc_html((string) $dia); ?></td>
                            <td style="text-align:right;"><?php echo (int) $peticiones; ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>

        <p style="margin-top:1.5em;font-size:.9em;color:#666;max-width:640px;">
            <?php esc_html_e('Sólo se cuentan endpoints de flavor-news/v1 con métodos GET/POST. ua_hash es MD5 truncado a 16 caracteres del User-Agent — irreversible y no permite identificar a la persona. La app envía un UA fijo por build (FlavorNewsHub/version (plataforma; canal)), así que todas las instalaciones del mismo build colapsan en un único hash: la métrica indica variedad de clientes, no número de usuarios. La tabla se purga automáticamente cada 90 días.', 'flavor-news-hub'); ?>
        </p>
        <?php
    }

    /**
     * Sección 3 (la ruidosa): contadores de descargas de GitHub Releases,
     * más el botón "marcar como mía" para descontar del total las
     * descargas de prueba del propio admin. El procesado del form vive en
     * `renderTabEstadisticas()` (debe correr antes que `EstadisticasPage`).
     */
    private static function renderSeccionDescargasGitHub(): void
    {
        ?>
        <h2 style="margin-top:2.5em;border-top:1px solid #dcdcde;padding-top:1.5em;">
            <?php esc_html_e('3. Descargas de GitHub Releases', 'flavor-news-hub'); ?>
        </h2>
        <div class="notice notice-warning inline" style="margin:1em 0;max-width:640px;">
            <p>
                <?php esc_html_e('Contadores brutos que sirve GitHub: incluyen bots, mirrors y escáneres, y NO cuentan F-Droid/IzzyOnDroid. Son un número honesto de "peticiones servidas", no de usuarios ni de instalaciones. Para saber si la gente actualiza, fíjate en la sección 1.', 'flavor-news-hub'); ?>
            </p>
        </div>
        <?php
        EstadisticasPage::render();

        // Bloque "marcar como mía" debajo de la tabla por release.
        $offsetActual = self::offsetDescargasPropias();
        $totalOffset = array_sum($offsetActual);
        ?>
        <h3 style="margin-top:2em;"><?php esc_html_e('¿Has descargado tú una versión?', 'flavor-news-hub'); ?></h3>
        <p class="description">
            <?php esc_html_e('Si pruebas cada release recién publicada, tus propias descargas inflan los contadores. Aquí puedes registrarlas como propias para que se descuenten del total visible. La página de Estadísticas resta este offset a los download_count que devuelve GitHub.', 'flavor-news-hub'); ?>
        </p>
        <form method="post" style="display:flex;gap:.6em;align-items:center;flex-wrap:wrap;margin:1em 0;">
            <?php wp_nonce_field('fnh_marcar_descarga_propia'); ?>
            <label for="fnh_tag_descarga_propia"><?php esc_html_e('Tag de la release:', 'flavor-news-hub'); ?></label>
            <input type="text" id="fnh_tag_descarga_propia" name="tag" placeholder="v0.13.0" required style="font-family:monospace;" />
            <button type="submit" name="fnh_marcar_descarga_propia" value="1" class="button button-primary">
                <?php esc_html_e('Marcar como mía', 'flavor-news-hub'); ?>
            </button>
        </form>

        <?php if ($offsetActual !== []) : ?>
            <p style="margin-top:1em;">
                <strong><?php esc_html_e('Descargas marcadas como tuyas:', 'flavor-news-hub'); ?></strong>
                <?php echo esc_html((string) $totalOffset); ?>
            </p>
            <table class="widefat striped" style="max-width:500px;">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Release', 'flavor-news-hub'); ?></th>
                        <th style="text-align:right;"><?php esc_html_e('Marcadas', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($offsetActual as $tagRelease => $cantidad) : ?>
                        <tr>
                            <td><code><?php echo esc_html((string) $tagRelease); ?></code></td>
                            <td style="text-align:right;"><?php echo (int) $cantidad; ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <form method="post" style="margin-top:1em;">
                <?php wp_nonce_field('fnh_resetear_descargas_propias'); ?>
                <button type="submit" name="fnh_resetear_descargas_propias" value="1" class="button button-secondary">
                    <?php esc_html_e('Resetear offset a cero', 'flavor-news-hub'); ?>
                </button>
            </form>
        <?php endif; ?>
        <?php
    }

    /**
     * Tab "Actualizaciones app": el admin decide si dejar el anuncio en
     * automático (la app recibirá la última release con APK del repo —
     * comportamiento histórico) o fijar manualmente una versión concreta
     * (típico para retrasar un rollout, hacer rollback a una versión
     * estable previa, o marcar una versión como obligatoria).
     *
     * Estado guardado en `wp_options::fnh_anuncio_actualizacion_app`.
     * Si la opción está vacía o tiene `tag=''`, modo auto.
     */
    private static function renderTabActualizacionesApp(): void
    {
        // Procesar form ANTES de leer opción para que el render refleje
        // el cambio en este mismo request.
        if (
            isset($_POST['fnh_guardar_anuncio_actualizacion'], $_POST['_wpnonce'])
            && current_user_can('manage_options')
            && wp_verify_nonce((string) $_POST['_wpnonce'], 'fnh_anuncio_actualizacion')
        ) {
            $modoElegido = (string) ($_POST['modo'] ?? 'auto');
            if ($modoElegido === 'manual') {
                $tagSeleccionado = sanitize_text_field((string) ($_POST['tag'] ?? ''));
                $obligatoria = isset($_POST['es_obligatoria']);
                if ($tagSeleccionado === '') {
                    echo '<div class="notice notice-error is-dismissible"><p>'
                        . esc_html__('Tienes que seleccionar una versión para anunciar manualmente.', 'flavor-news-hub')
                        . '</p></div>';
                } else {
                    update_option(AppUpdateEndpoint::OPCION_ANUNCIO, [
                        'tag'            => $tagSeleccionado,
                        'es_obligatoria' => $obligatoria,
                        'anunciado_at'   => gmdate('c'),
                        'anunciado_por'  => get_current_user_id(),
                    ], false);
                    echo '<div class="notice notice-success is-dismissible"><p>'
                        . esc_html(sprintf(
                            /* translators: %1$s = tag de la versión, %2$s = "(obligatoria)" o "" */
                            __('Anuncio guardado: %1$s %2$s. Las apps lo verán en su próximo check (hasta 1h por cache).', 'flavor-news-hub'),
                            $tagSeleccionado,
                            $obligatoria ? __('(obligatoria)', 'flavor-news-hub') : ''
                        ))
                        . '</p></div>';
                }
            } else {
                // modo=auto → borramos la opción para que el endpoint
                // caiga al fallback (última release con APK).
                delete_option(AppUpdateEndpoint::OPCION_ANUNCIO);
                echo '<div class="notice notice-success is-dismissible"><p>'
                    . esc_html__('Modo automático activado: se anuncia la última release con APK del repo.', 'flavor-news-hub')
                    . '</p></div>';
            }
        }

        // Botón "Refrescar caché" — fuerza re-lectura de GitHub al
        // siguiente render (útil tras publicar una release nueva).
        if (
            isset($_POST['fnh_refrescar_releases'], $_POST['_wpnonce'])
            && current_user_can('manage_options')
            && wp_verify_nonce((string) $_POST['_wpnonce'], 'fnh_refrescar_releases')
        ) {
            global $wpdb;
            // Borra todos los transients del prefijo `fnh_app_update_cache`
            // (listado, beta, _tag_*, etc.). Más limpio que listar nombres.
            $wpdb->query(
                "DELETE FROM {$wpdb->options}
                 WHERE option_name LIKE '\\_transient\\_fnh\\_app\\_update\\_cache%'
                    OR option_name LIKE '\\_transient\\_timeout\\_fnh\\_app\\_update\\_cache%'"
            );
            echo '<div class="notice notice-success is-dismissible"><p>'
                . esc_html__('Caché de releases vaciada. La próxima carga consultará GitHub directamente.', 'flavor-news-hub')
                . '</p></div>';
        }

        $config = AppUpdateEndpoint::leerConfigAnuncio();
        $modoActual = $config['tag'] !== '' ? 'manual' : 'auto';
        $forzarRefresh = false; // ya lo hicimos arriba si tocaba.
        $releases = AppUpdateEndpoint::listarReleasesParaAdmin(15, $forzarRefresh);
        ?>
        <h2><?php esc_html_e('Anuncio de actualización en la app', 'flavor-news-hub'); ?></h2>
        <p class="description">
            <?php esc_html_e('Controla qué versión del APK se anuncia a las apps libre instaladas (las del flavor playstore se actualizan vía Google Play). Por defecto se anuncia la última release del repo con APK; si quieres retrasar un rollout o forzar a los usuarios a una versión concreta, fija una manualmente aquí.', 'flavor-news-hub'); ?>
        </p>

        <?php if ($modoActual === 'manual') : ?>
            <div class="notice notice-info inline" style="margin:1em 0;">
                <p>
                    <strong><?php esc_html_e('Anuncio activo:', 'flavor-news-hub'); ?></strong>
                    <code><?php echo esc_html($config['tag']); ?></code>
                    <?php if ($config['es_obligatoria']) : ?>
                        — <?php esc_html_e('marcada como obligatoria (la app no permitirá descartar el aviso).', 'flavor-news-hub'); ?>
                    <?php endif; ?>
                    <?php if ($config['anunciado_at'] !== '') : ?>
                        <br><small><?php
                            printf(
                                /* translators: %s = fecha ISO */
                                esc_html__('Última modificación: %s UTC', 'flavor-news-hub'),
                                esc_html($config['anunciado_at'])
                            );
                        ?></small>
                    <?php endif; ?>
                </p>
            </div>
        <?php endif; ?>

        <form method="post" style="margin:1em 0;">
            <?php wp_nonce_field('fnh_anuncio_actualizacion'); ?>

            <p>
                <label>
                    <input type="radio" name="modo" value="auto" <?php checked($modoActual === 'auto'); ?> />
                    <strong><?php esc_html_e('Auto', 'flavor-news-hub'); ?></strong>
                    — <?php esc_html_e('anunciar la última release del repo con APK (comportamiento por defecto).', 'flavor-news-hub'); ?>
                </label>
            </p>
            <p>
                <label>
                    <input type="radio" name="modo" value="manual" <?php checked($modoActual === 'manual'); ?> />
                    <strong><?php esc_html_e('Manual', 'flavor-news-hub'); ?></strong>
                    — <?php esc_html_e('fijar una versión concreta:', 'flavor-news-hub'); ?>
                </label>
            </p>
            <div style="margin:0 0 1em 2.2em;">
                <select name="tag" style="font-family:monospace;min-width:280px;">
                    <option value=""><?php esc_html_e('— elegir versión —', 'flavor-news-hub'); ?></option>
                    <?php foreach ($releases as $rel) :
                        $fecha = $rel['published_at'] !== ''
                            ? substr($rel['published_at'], 0, 10)
                            : ''; ?>
                        <option value="<?php echo esc_attr($rel['version']); ?>"
                                <?php selected($config['tag'], $rel['version']); ?>>
                            <?php echo esc_html($rel['version']); ?>
                            <?php if ($fecha !== '') : ?>
                                — <?php echo esc_html($fecha); ?>
                            <?php endif; ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <br>
                <label style="margin-top:.6em;display:inline-block;">
                    <input type="checkbox" name="es_obligatoria" value="1" <?php checked($config['es_obligatoria']); ?> />
                    <?php esc_html_e('Marcarla como obligatoria (el aviso no se podrá descartar)', 'flavor-news-hub'); ?>
                </label>
                <?php if ($releases === []) : ?>
                    <p class="description" style="color:#b32d2e;">
                        <?php esc_html_e('Aún no hay releases con APK detectables. Pulsa "Refrescar" si acabas de publicar una.', 'flavor-news-hub'); ?>
                    </p>
                <?php endif; ?>
            </div>

            <p>
                <button type="submit" name="fnh_guardar_anuncio_actualizacion" value="1" class="button button-primary">
                    <?php esc_html_e('Guardar', 'flavor-news-hub'); ?>
                </button>
            </p>
        </form>

        <hr>

        <form method="post" style="margin-top:1em;">
            <?php wp_nonce_field('fnh_refrescar_releases'); ?>
            <p class="description">
                <?php esc_html_e('Si acabas de publicar una release nueva en GitHub y aún no aparece arriba, vacía la caché (TTL 1h):', 'flavor-news-hub'); ?>
            </p>
            <button type="submit" name="fnh_refrescar_releases" value="1" class="button button-secondary">
                <?php esc_html_e('Refrescar caché de releases', 'flavor-news-hub'); ?>
            </button>
        </form>

        <p style="margin-top:2em;font-size:.9em;color:#666;">
            <?php esc_html_e('Las apps consultan este anuncio en cada arranque y respetan el aviso durante 30 min de cache cliente. En modo manual el aviso permanece hasta que cambies la versión o vuelvas a auto. La opción de “obligatoria” quita el botón “No ahora” del diálogo en la app.', 'flavor-news-hub'); ?>
        </p>
        <?php
    }

    /**
     * Lee el offset de descargas propias del wp_options. Devuelve un
     * mapa `tag => cantidad` (puede estar vacío).
     *
     * @return array<string,int>
     */
    public static function offsetDescargasPropias(): array
    {
        $valor = get_option('fnh_descargas_propias_offset', []);
        if (!is_array($valor)) {
            return [];
        }
        $resultado = [];
        foreach ($valor as $tagRelease => $cantidad) {
            $tagLimpio = (string) $tagRelease;
            $cantidadEntera = (int) $cantidad;
            if ($tagLimpio === '' || $cantidadEntera <= 0) {
                continue;
            }
            $resultado[$tagLimpio] = $cantidadEntera;
        }
        return $resultado;
    }

    /**
     * Incrementa en 1 el offset asociado al tag indicado. El tag se
     * sanitiza pero no se valida contra GitHub — si el admin escribe
     * un tag inexistente, el offset queda registrado sin efecto sobre
     * los contadores reales.
     */
    private static function incrementarOffsetDescargaPropia(string $tag): void
    {
        $tagSanitizado = sanitize_text_field($tag);
        if ($tagSanitizado === '') {
            return;
        }
        $offsetActual = self::offsetDescargasPropias();
        $offsetActual[$tagSanitizado] = ($offsetActual[$tagSanitizado] ?? 0) + 1;
        update_option('fnh_descargas_propias_offset', $offsetActual, false);
    }
}
