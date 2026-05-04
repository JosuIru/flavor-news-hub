<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Admin\Actions\EstadoFuentesActions;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\FeedIngester;

/**
 * Pantalla de admin "Estado de fuentes": una fila por cada fuente
 * activa con su actividad real (última ingesta, items creados en 7/30
 * días, total histórico, último error si lo hubiera).
 *
 * Pensada para encontrar rápidamente:
 *  - Fuentes muertas (sin items nuevos en semanas) → candidatas a quitar.
 *  - Fuentes con errores recurrentes → feed roto o URL caducada.
 *  - Oligopolios en el feed (unos pocos medios dominando los últimos
 *    días) → señal de que otros deberían revisarse.
 */
final class EstadoFuentesPage
{
    public const SLUG = 'fnh-estado-fuentes';

    /**
     * Render de la pantalla. Cuando se invoca desde `SistemaPage`
     * (tabs unificadas), `$conWrap` debe ser false para que el
     * contenedor `.wrap` y el `<h1>` los aporte la página padre y no
     * se dupliquen.
     */
    public static function render(bool $conWrap = true): void
    {
        // Esta pantalla muestra acciones de mutación (desactivar fuente,
        // aplicar URLs, auto-descubrir feeds) que los handlers exigen con
        // `manage_options`. Si dejáramos `edit_posts` aquí, un editor
        // vería la pantalla pero al pulsar cualquier botón recibiría 403.
        if (!current_user_can('manage_options')) {
            return;
        }

        global $wpdb;
        $logsTabla = IngestLogTable::nombreCompleto();

        // Sources activas ordenadas por actividad descendente. Una sola
        // query con subconsultas correlacionadas — no es bonito pero
        // cabe en pantalla y evita N+1 a 110 fuentes.
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT
                p.ID AS source_id,
                p.post_title AS nombre,
                (SELECT pm2.meta_value FROM {$wpdb->postmeta} pm2
                    WHERE pm2.post_id = p.ID AND pm2.meta_key = '_fnh_feed_url' LIMIT 1) AS feed_url,
                (SELECT pm3.meta_value FROM {$wpdb->postmeta} pm3
                    WHERE pm3.post_id = p.ID AND pm3.meta_key = '_fnh_feed_type' LIMIT 1) AS feed_type,
                (SELECT pm4.meta_value FROM {$wpdb->postmeta} pm4
                    WHERE pm4.post_id = p.ID AND pm4.meta_key = '_fnh_territory' LIMIT 1) AS territorio,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                ) AS total_items,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                ) AS items_7d,
                (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                    INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                    WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                      AND pi.post_type = %s AND pi.post_status = 'publish'
                      AND pi.post_date_gmt >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                ) AS items_30d,
                (SELECT MAX(il.started_at) FROM {$logsTabla} il WHERE il.source_id = p.ID) AS ultima_ingesta,
                (SELECT il2.status FROM {$logsTabla} il2 WHERE il2.source_id = p.ID
                    ORDER BY il2.started_at DESC LIMIT 1) AS ultimo_status,
                (SELECT il3.error_message FROM {$logsTabla} il3 WHERE il3.source_id = p.ID
                    AND il3.error_message IS NOT NULL AND il3.error_message != ''
                    ORDER BY il3.started_at DESC LIMIT 1) AS ultimo_error
             FROM {$wpdb->posts} p
             INNER JOIN {$wpdb->postmeta} pma ON pma.post_id = p.ID
                AND pma.meta_key = '_fnh_active' AND pma.meta_value = '1'
             WHERE p.post_type = %s AND p.post_status = 'publish'
             ORDER BY items_7d DESC, nombre ASC",
            Item::SLUG, Item::SLUG, Item::SLUG, Source::SLUG
        ), ARRAY_A);

        $filas = is_array($filas) ? $filas : [];

        // Clasificar en tres categorías visuales. De paso, leemos para
        // cada fila el estado del circuit breaker (errores acumulados +
        // timestamp de "próximo intento") para que la tabla pueda
        // renderizar el badge de cuarentena y el botón de reset. Es 2
        // get_post_meta por fuente — irrelevante para 200-300 filas.
        $ahora = time();
        $muertas = []; $inactivas = []; $sanas = []; $conErrores = [];
        foreach ($filas as $f) {
            $idSourceFila = (int) ($f['source_id'] ?? 0);
            $f['cuarentena_hasta'] = (int) get_post_meta(
                $idSourceFila,
                FeedIngester::META_PROXIMO_INTENTO_TRAS,
                true
            );
            $f['errores_consecutivos'] = (int) get_post_meta(
                $idSourceFila,
                FeedIngester::META_ERRORES_CONSECUTIVOS,
                true
            );
            $itemsSiete = (int) ($f['items_7d'] ?? 0);
            $itemsTreinta = (int) ($f['items_30d'] ?? 0);
            $status = (string) ($f['ultimo_status'] ?? '');
            if ($status === 'error') {
                $conErrores[] = $f;
            } elseif ($itemsSiete > 0) {
                $sanas[] = $f;
            } elseif ($itemsTreinta > 0) {
                $inactivas[] = $f;
            } else {
                $muertas[] = $f;
            }
        }

        ?>
        <?php if ($conWrap) : ?>
        <div class="wrap">
            <h1><?php esc_html_e('Estado de las fuentes', 'flavor-news-hub'); ?></h1>
        <?php endif; ?>
            <p class="description">
                <?php printf(
                    /* translators: %1$d total, %2$d sanas, %3$d inactivas, %4$d muertas, %5$d con errores */
                    esc_html__('Total: %1$d fuentes activas · %2$d sanas (items últimos 7d) · %3$d inactivas (sin items en 7d pero sí en 30d) · %4$d muertas (sin items en 30d) · %5$d con errores en la última ingesta.', 'flavor-news-hub'),
                    count($filas),
                    count($sanas),
                    count($inactivas),
                    count($muertas),
                    count($conErrores)
                ); ?>
            </p>

            <div style="display:flex; gap:12px; margin:16px 0 24px; flex-wrap:wrap">
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:0">
                    <input type="hidden" name="action" value="fnh_aplicar_urls_conocidas" />
                    <?php wp_nonce_field('fnh_aplicar_urls_conocidas'); ?>
                    <?php submit_button(__('Aplicar URLs corregidas (CTXT, Cuarto Poder)', 'flavor-news-hub'), 'secondary', 'submit', false); ?>
                </form>
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:0"
                      onsubmit="return confirm('<?php echo esc_js(__('Se descargará la URL de cada fuente con error o muerta para buscar &lt;link rel=&quot;alternate&quot;&gt;. Puede tardar 30-60s. ¿Continuar?', 'flavor-news-hub')); ?>');">
                    <input type="hidden" name="action" value="fnh_detectar_feeds" />
                    <?php wp_nonce_field('fnh_detectar_feeds'); ?>
                    <?php submit_button(__('Auto-descubrir feeds rotos', 'flavor-news-hub'), 'primary', 'submit', false); ?>
                </form>
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:0"
                      onsubmit="return confirm('<?php echo esc_js(__('Se desactivarán todas las fuentes con error y sin items históricos. ¿Continuar?', 'flavor-news-hub')); ?>');">
                    <input type="hidden" name="action" value="fnh_desactivar_caidas" />
                    <?php wp_nonce_field('fnh_desactivar_caidas'); ?>
                    <?php submit_button(__('Desactivar todas las caídas', 'flavor-news-hub'), 'delete', 'submit', false); ?>
                </form>
            </div>

            <?php self::renderPropuestasFeedsDetectados(); ?>
            <?php self::renderDuplicadosDetectados(); ?>

            <?php if ($conErrores !== []) : ?>
                <h2 style="color:#dc3232; margin-top:2em"><?php esc_html_e('Con errores en la última ingesta', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($conErrores, true); ?>
            <?php endif; ?>

            <?php if ($muertas !== []) : ?>
                <h2 style="color:#dc3232; margin-top:2em"><?php esc_html_e('Muertas (sin items en 30 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($muertas, false); ?>
            <?php endif; ?>

            <?php if ($inactivas !== []) : ?>
                <h2 style="color:#dba617; margin-top:2em"><?php esc_html_e('Inactivas (sin items en 7 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($inactivas, false); ?>
            <?php endif; ?>

            <?php if ($sanas !== []) : ?>
                <h2 style="color:#46b450; margin-top:2em"><?php esc_html_e('Sanas (activas últimos 7 días)', 'flavor-news-hub'); ?></h2>
                <?php self::renderTabla($sanas, false); ?>
            <?php endif; ?>
        <?php if ($conWrap) : ?>
        </div>
        <?php endif; ?>
        <?php
    }

    /** @param list<array<string,mixed>> $filas */
    private static function renderTabla(array $filas, bool $mostrarError): void
    {
        ?>
        <table class="widefat striped" style="max-width:1200px">
            <thead>
                <tr>
                    <th><?php esc_html_e('Medio', 'flavor-news-hub'); ?></th>
                    <th style="width:60px"><?php esc_html_e('Tipo', 'flavor-news-hub'); ?></th>
                    <th style="width:80px; text-align:right"><?php esc_html_e('7d', 'flavor-news-hub'); ?></th>
                    <th style="width:80px; text-align:right"><?php esc_html_e('30d', 'flavor-news-hub'); ?></th>
                    <th style="width:90px; text-align:right"><?php esc_html_e('Total', 'flavor-news-hub'); ?></th>
                    <th style="width:160px"><?php esc_html_e('Última ingesta', 'flavor-news-hub'); ?></th>
                    <?php if ($mostrarError) : ?><th><?php esc_html_e('Error', 'flavor-news-hub'); ?></th><?php endif; ?>
                    <th style="width:80px"><?php esc_html_e('Acciones', 'flavor-news-hub'); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($filas as $f) :
                    $idSource = (int) $f['source_id'];
                    $editUrl = get_edit_post_link($idSource);
                    $feedUrl = (string) ($f['feed_url'] ?? '');
                    $ultima = (string) ($f['ultima_ingesta'] ?? '');
                    $ultimaHumana = $ultima !== ''
                        ? human_time_diff(strtotime($ultima . ' UTC'), time()) . ' atrás'
                        : '—';
                    $cuarentenaHasta = (int) ($f['cuarentena_hasta'] ?? 0);
                    $erroresConsecutivos = (int) ($f['errores_consecutivos'] ?? 0);
                    $enCuarentena = $cuarentenaHasta > 0 && $cuarentenaHasta > time();
                ?>
                <tr>
                    <td>
                        <strong><?php echo esc_html((string) $f['nombre']); ?></strong>
                        <?php if (!empty($f['territorio'])) : ?>
                            <br><span style="color:#888; font-size:.85em"><?php echo esc_html((string) $f['territorio']); ?></span>
                        <?php endif; ?>
                        <?php if ($feedUrl !== '') : ?>
                            <br><a href="<?php echo esc_url($feedUrl); ?>" target="_blank" style="font-size:.8em; color:#999" rel="noopener"><?php echo esc_html(wp_parse_url($feedUrl, PHP_URL_HOST) ?: $feedUrl); ?></a>
                        <?php endif; ?>
                        <?php if ($enCuarentena) : ?>
                            <br><span title="<?php echo esc_attr(sprintf(
                                /* translators: %d errores consecutivos acumulados */
                                __('%d errores consecutivos acumulados antes de entrar en cuarentena', 'flavor-news-hub'),
                                $erroresConsecutivos
                            )); ?>"
                                  style="display:inline-block; margin-top:4px; padding:2px 8px; background:#fcf0f1; color:#a00; border-radius:3px; font-size:.75em">
                                <?php printf(
                                    /* translators: %s tiempo humano hasta el próximo intento (p.ej. "en 1 hora") */
                                    esc_html__('🔒 en cuarentena · próximo intento %s', 'flavor-news-hub'),
                                    esc_html(human_time_diff(time(), $cuarentenaHasta))
                                ); ?>
                            </span>
                        <?php elseif ($erroresConsecutivos > 0) : ?>
                            <br><span style="display:inline-block; margin-top:4px; padding:2px 8px; background:#fff8e5; color:#8a5a00; border-radius:3px; font-size:.75em">
                                <?php printf(
                                    /* translators: %d errores consecutivos */
                                    esc_html(_n('%d error consecutivo', '%d errores consecutivos', $erroresConsecutivos, 'flavor-news-hub')),
                                    $erroresConsecutivos
                                ); ?>
                            </span>
                        <?php endif; ?>
                    </td>
                    <td><code style="font-size:.75em"><?php echo esc_html((string) ($f['feed_type'] ?? '?')); ?></code></td>
                    <td style="text-align:right"><?php echo (int) ($f['items_7d'] ?? 0); ?></td>
                    <td style="text-align:right"><?php echo (int) ($f['items_30d'] ?? 0); ?></td>
                    <td style="text-align:right"><?php echo (int) ($f['total_items'] ?? 0); ?></td>
                    <td style="font-size:.85em"><?php echo esc_html($ultimaHumana); ?></td>
                    <?php if ($mostrarError) : ?>
                        <td style="font-size:.8em; color:#c33;"><?php echo esc_html(mb_substr((string) ($f['ultimo_error'] ?? ''), 0, 200)); ?></td>
                    <?php endif; ?>
                    <td>
                        <?php if ($editUrl) : ?>
                            <a href="<?php echo esc_url($editUrl); ?>"><?php esc_html_e('Editar', 'flavor-news-hub'); ?></a>
                        <?php endif; ?>
                        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="display:inline; margin-left:6px"
                              onsubmit="return confirm('<?php echo esc_js(__('¿Desactivar esta fuente?', 'flavor-news-hub')); ?>');">
                            <input type="hidden" name="action" value="fnh_desactivar_fuente" />
                            <input type="hidden" name="source_id" value="<?php echo esc_attr((string) $idSource); ?>" />
                            <?php wp_nonce_field('fnh_desactivar_fuente_' . $idSource); ?>
                            <button type="submit" class="button-link" style="color:#c33; padding:0"><?php esc_html_e('Desactivar', 'flavor-news-hub'); ?></button>
                        </form>
                        <?php if ($enCuarentena) : ?>
                            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="display:block; margin-top:4px">
                                <input type="hidden" name="action" value="fnh_resetear_cuarentena" />
                                <input type="hidden" name="source_id" value="<?php echo esc_attr((string) $idSource); ?>" />
                                <?php wp_nonce_field('fnh_resetear_cuarentena_' . $idSource); ?>
                                <button type="submit" class="button-link" style="color:#2271b1; padding:0; font-size:.85em">
                                    <?php esc_html_e('Resetear cuarentena', 'flavor-news-hub'); ?>
                                </button>
                            </form>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <?php
    }

    /**
     * Renderiza la sección de "Feeds detectados automáticamente" si hay
     * propuestas guardadas en transient. Cada fila propone una URL nueva
     * extraída del `<link rel="alternate">` de la web del medio y permite
     * aplicarla con un click (que también reactiva la fuente).
     */
    private static function renderPropuestasFeedsDetectados(): void
    {
        $propuestas = get_transient(EstadoFuentesActions::TRANSIENT_PROPUESTAS);
        if (!is_array($propuestas) || $propuestas === []) {
            return;
        }
        ?>
        <h2 style="color:#2271b1; margin-top:2em">
            <?php esc_html_e('Feeds detectados automáticamente', 'flavor-news-hub'); ?>
            <span style="font-size:.6em; font-weight:normal; color:#666; margin-left:.5em">
                <?php printf(
                    /* translators: %d propuestas pendientes */
                    esc_html(_n('%d propuesta pendiente', '%d propuestas pendientes', count($propuestas), 'flavor-news-hub')),
                    count($propuestas)
                ); ?>
            </span>
        </h2>
        <p class="description" style="max-width:800px">
            <?php esc_html_e('Estas URLs fueron detectadas leyendo la etiqueta <link rel="alternate" type="application/rss+xml"> de la página del medio. Antes de aplicar verifica que la URL nueva tiene sentido.', 'flavor-news-hub'); ?>
        </p>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:0 0 1em" onsubmit="return confirm('<?php echo esc_js(__('¿Aplicar TODAS las propuestas listadas? Esta acción actualiza la URL de cada medio y reactiva la fuente.', 'flavor-news-hub')); ?>');">
            <input type="hidden" name="action" value="fnh_aplicar_feeds_todos" />
            <?php wp_nonce_field('fnh_aplicar_feeds_todos'); ?>
            <button type="submit" class="button button-primary">
                <?php printf(
                    /* translators: %d propuestas en bloque */
                    esc_html__('Aplicar todas las propuestas (%d)', 'flavor-news-hub'),
                    count($propuestas)
                ); ?>
            </button>
            <span class="description" style="margin-left:.5em">
                <?php esc_html_e('o revísalas una por una más abajo.', 'flavor-news-hub'); ?>
            </span>
        </form>
        <table class="widefat striped" style="max-width:1200px">
            <thead>
                <tr>
                    <th><?php esc_html_e('Medio', 'flavor-news-hub'); ?></th>
                    <th><?php esc_html_e('URL actual (rota)', 'flavor-news-hub'); ?></th>
                    <th><?php esc_html_e('URL detectada', 'flavor-news-hub'); ?></th>
                    <th style="width:60px"><?php esc_html_e('Tipo', 'flavor-news-hub'); ?></th>
                    <th style="width:140px"><?php esc_html_e('Última publicación', 'flavor-news-hub'); ?></th>
                    <th style="width:120px"><?php esc_html_e('Acciones', 'flavor-news-hub'); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($propuestas as $propuesta) :
                    $idSource = (int) ($propuesta['source_id'] ?? 0);
                    if ($idSource <= 0) continue;
                    $urlActual         = (string) ($propuesta['url_actual'] ?? '');
                    $urlDetectada      = (string) ($propuesta['url_detectada'] ?? '');
                    $tipoFeed          = (string) ($propuesta['tipo_detectado'] ?? '');
                    $nombre            = (string) ($propuesta['nombre'] ?? '');
                    $timestampUltimoItem = isset($propuesta['ultimo_item_ts']) ? (int) $propuesta['ultimo_item_ts'] : 0;

                    // Código de color por antigüedad: <30d verde, 30-180d
                    // amarillo, >180d rojo, desconocido gris. La idea es que
                    // el admin pueda barrer la columna y aplicar a ojo.
                    $textoFrescura = '';
                    $colorFondoFrescura = '';
                    if ($timestampUltimoItem > 0) {
                        $segundosDesdeUltimoItem = max(0, time() - $timestampUltimoItem);
                        $diasDesdeUltimoItem = (int) floor($segundosDesdeUltimoItem / DAY_IN_SECONDS);
                        $textoFrescura = sprintf(
                            /* translators: %d días desde última publicación */
                            _n('hace %d día', 'hace %d días', max(1, $diasDesdeUltimoItem), 'flavor-news-hub'),
                            max(1, $diasDesdeUltimoItem)
                        );
                        if ($diasDesdeUltimoItem <= 30) {
                            $colorFondoFrescura = '#d4edda; color:#155724';
                        } elseif ($diasDesdeUltimoItem <= 180) {
                            $colorFondoFrescura = '#fff3cd; color:#856404';
                        } else {
                            $colorFondoFrescura = '#f8d7da; color:#721c24';
                        }
                    } else {
                        $textoFrescura = __('desconocida', 'flavor-news-hub');
                        $colorFondoFrescura = '#e2e3e5; color:#6c757d';
                    }
                ?>
                <tr>
                    <td><strong><?php echo esc_html($nombre); ?></strong></td>
                    <td style="font-family:monospace; font-size:.8em; color:#888; word-break:break-all">
                        <?php echo esc_html($urlActual); ?>
                    </td>
                    <td style="font-family:monospace; font-size:.8em; word-break:break-all">
                        <a href="<?php echo esc_url($urlDetectada); ?>" target="_blank" rel="noopener">
                            <?php echo esc_html($urlDetectada); ?>
                        </a>
                    </td>
                    <td><code style="font-size:.75em"><?php echo esc_html($tipoFeed); ?></code></td>
                    <td>
                        <span style="display:inline-block; padding:2px 8px; border-radius:3px; font-size:.85em; background:<?php echo esc_attr($colorFondoFrescura); ?>">
                            <?php echo esc_html($textoFrescura); ?>
                        </span>
                    </td>
                    <td>
                        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:0">
                            <input type="hidden" name="action" value="fnh_aplicar_feed_detectado" />
                            <input type="hidden" name="source_id" value="<?php echo esc_attr((string) $idSource); ?>" />
                            <?php wp_nonce_field('fnh_aplicar_feed_detectado_' . $idSource); ?>
                            <button type="submit" class="button button-primary"><?php esc_html_e('Aplicar', 'flavor-news-hub'); ?></button>
                        </form>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
        <?php
    }

    /**
     * Lista pares de fuentes que parecen duplicadas — mismo feed_url
     * exacto o mismo título exacto. Sólo informa, no borra: el admin
     * decide cuál de cada par eliminar manualmente.
     *
     * Bug observado en la pantalla: tras varias importaciones del seed
     * algunas fuentes aparecen 2 veces como posts distintos, lo que
     * dispara la ingesta dos veces para el mismo medio y duplica items.
     */
    private static function renderDuplicadosDetectados(): void
    {
        global $wpdb;

        // Pares con mismo feed_url. Filtramos por feed_url no vacío y
        // post_status publish para descartar borrados/borradores.
        $duplicadosPorUrl = $wpdb->get_results($wpdb->prepare(
            "SELECT pm.meta_value AS feed_url, GROUP_CONCAT(p.ID ORDER BY p.ID ASC) AS ids
             FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_fnh_feed_url'
               AND pm.meta_value != ''
               AND p.post_type = %s AND p.post_status = 'publish'
             GROUP BY pm.meta_value
             HAVING COUNT(*) > 1",
            \FlavorNewsHub\CPT\Source::SLUG
        ), ARRAY_A);

        // Pares con mismo título — sirven para detectar duplicados que
        // tengan feed_urls ligeramente distintos (con/sin www, http vs
        // https) pero son el mismo medio.
        $duplicadosPorTitulo = $wpdb->get_results($wpdb->prepare(
            "SELECT post_title AS titulo, GROUP_CONCAT(ID ORDER BY ID ASC) AS ids
             FROM {$wpdb->posts}
             WHERE post_type = %s AND post_status = 'publish'
             GROUP BY post_title
             HAVING COUNT(*) > 1",
            \FlavorNewsHub\CPT\Source::SLUG
        ), ARRAY_A);

        $duplicadosPorUrl = is_array($duplicadosPorUrl) ? $duplicadosPorUrl : [];
        $duplicadosPorTitulo = is_array($duplicadosPorTitulo) ? $duplicadosPorTitulo : [];
        if ($duplicadosPorUrl === [] && $duplicadosPorTitulo === []) {
            return;
        }

        ?>
        <h2 style="color:#dba617; margin-top:2em">
            <?php esc_html_e('Duplicados detectados', 'flavor-news-hub'); ?>
        </h2>
        <p class="description" style="max-width:800px">
            <?php esc_html_e('Estas fuentes están registradas dos o más veces — lo que duplica la ingesta y los items en el feed.', 'flavor-news-hub'); ?>
        </p>

        <?php if ($duplicadosPorUrl !== []) : ?>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin:8px 0 16px"
                  onsubmit="return confirm('<?php echo esc_js(__('Se mandarán a papelera los duplicados con misma feed_url, manteniendo el más antiguo de cada par. ¿Continuar?', 'flavor-news-hub')); ?>');">
                <input type="hidden" name="action" value="fnh_eliminar_duplicados" />
                <?php wp_nonce_field('fnh_eliminar_duplicados'); ?>
                <?php submit_button(__('Eliminar duplicados (mantener el más antiguo)', 'flavor-news-hub'), 'delete', 'submit', false); ?>
            </form>
        <?php endif; ?>

        <?php if ($duplicadosPorUrl !== []) : ?>
            <h3 style="margin-top:1.5em"><?php esc_html_e('Mismo feed_url', 'flavor-news-hub'); ?></h3>
            <table class="widefat striped" style="max-width:1200px">
                <thead>
                    <tr>
                        <th><?php esc_html_e('feed_url compartida', 'flavor-news-hub'); ?></th>
                        <th style="width:240px"><?php esc_html_e('Posts duplicados (clic para editar)', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($duplicadosPorUrl as $par) :
                    $listaIds = array_filter(array_map('intval', explode(',', (string) $par['ids'])));
                ?>
                    <tr>
                        <td style="font-family:monospace; font-size:.8em; word-break:break-all">
                            <?php echo esc_html((string) $par['feed_url']); ?>
                        </td>
                        <td>
                            <?php foreach ($listaIds as $idDuplicado) :
                                $tituloDuplicado = get_the_title($idDuplicado);
                                $urlEditar = get_edit_post_link($idDuplicado);
                            ?>
                                <a href="<?php echo $urlEditar ? esc_url($urlEditar) : '#'; ?>" style="display:inline-block; margin-right:8px">
                                    #<?php echo esc_html((string) $idDuplicado); ?> <?php echo esc_html($tituloDuplicado); ?>
                                </a>
                            <?php endforeach; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>

        <?php if ($duplicadosPorTitulo !== []) : ?>
            <h3 style="margin-top:1.5em"><?php esc_html_e('Mismo título', 'flavor-news-hub'); ?></h3>
            <table class="widefat striped" style="max-width:1200px">
                <thead>
                    <tr>
                        <th><?php esc_html_e('Título compartido', 'flavor-news-hub'); ?></th>
                        <th style="width:240px"><?php esc_html_e('Posts duplicados (clic para editar)', 'flavor-news-hub'); ?></th>
                    </tr>
                </thead>
                <tbody>
                <?php foreach ($duplicadosPorTitulo as $par) :
                    $listaIds = array_filter(array_map('intval', explode(',', (string) $par['ids'])));
                ?>
                    <tr>
                        <td><strong><?php echo esc_html((string) $par['titulo']); ?></strong></td>
                        <td>
                            <?php foreach ($listaIds as $idDuplicado) :
                                $urlEditar = get_edit_post_link($idDuplicado);
                                $urlFeed = (string) get_post_meta($idDuplicado, '_fnh_feed_url', true);
                            ?>
                                <div style="margin-bottom:4px">
                                    <a href="<?php echo $urlEditar ? esc_url($urlEditar) : '#'; ?>">
                                        #<?php echo esc_html((string) $idDuplicado); ?>
                                    </a>
                                    <span style="color:#888; font-size:.8em; margin-left:6px">
                                        <?php echo esc_html($urlFeed); ?>
                                    </span>
                                </div>
                            <?php endforeach; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
        <?php
    }
}
