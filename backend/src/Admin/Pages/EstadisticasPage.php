<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

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
    private const TTL_CACHE_SEGUNDOS = 1 * HOUR_IN_SECONDS;

    public static function render(): void
    {
        if (!current_user_can('edit_posts')) {
            return;
        }

        // Botón "Refrescar ya": borra el transient y refresca en línea.
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
            delete_transient(self::TRANSIENT_CACHE);
            $refrescoForzado = true;
        }

        $datos = self::obtenerDatos();

        ?>
        <div class="wrap">
            <h1><?php esc_html_e('Estadísticas de descargas', 'flavor-news-hub'); ?></h1>
            <p class="description">
                <?php esc_html_e('Contadores leídos de GitHub Releases. La app y el plugin no envían telemetría — sólo se cuenta lo que GitHub registra al servir el asset.', 'flavor-news-hub'); ?>
            </p>

            <?php if ($refrescoForzado && !isset($datos['error'])) : ?>
                <div class="notice notice-success is-dismissible"><p>
                    <?php esc_html_e('Datos refrescados desde GitHub.', 'flavor-news-hub'); ?>
                </p></div>
            <?php endif; ?>

            <?php if (isset($datos['error'])) : ?>
                <div class="notice notice-error"><p><?php echo esc_html($datos['error']); ?></p></div>
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
            <?php endif; ?>
        </div>
        <?php
    }

    /**
     * @return array{
     *   total_apk:int,total_zip:int,total_releases:int,
     *   filas:list<array{tag:string,nombre:string,descargas:int}>,
     *   ts_lectura:int
     * }|array{error:string}
     */
    private static function obtenerDatos(): array
    {
        $cache = get_transient(self::TRANSIENT_CACHE);
        if (is_array($cache) && isset($cache['filas'])) {
            return $cache;
        }

        $url = 'https://api.github.com/repos/' . self::REPO_GITHUB . '/releases?per_page=30';
        $headers = ['Accept' => 'application/vnd.github+json'];
        if (defined('FLAVOR_GH_TOKEN') && FLAVOR_GH_TOKEN !== '') {
            $headers['Authorization'] = 'Bearer ' . FLAVOR_GH_TOKEN;
        }
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
        $cuerpo = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        if (!is_array($cuerpo)) {
            return ['error' => __('Respuesta inesperada de GitHub.', 'flavor-news-hub')];
        }

        $totalApk = 0;
        $totalZip = 0;
        $filas = [];
        foreach ($cuerpo as $release) {
            if (!is_array($release)) continue;
            $tag = (string) ($release['tag_name'] ?? '');
            foreach (($release['assets'] ?? []) as $asset) {
                if (!is_array($asset)) continue;
                $nombre = (string) ($asset['name'] ?? '');
                $descargas = (int) ($asset['download_count'] ?? 0);
                if ($descargas <= 0) continue;
                $extension = strtolower((string) pathinfo($nombre, PATHINFO_EXTENSION));
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

        $datos = [
            'total_apk'      => $totalApk,
            'total_zip'      => $totalZip,
            'total_releases' => count($cuerpo),
            'filas'          => $filas,
            'ts_lectura'     => time(),
        ];
        set_transient(self::TRANSIENT_CACHE, $datos, self::TTL_CACHE_SEGUNDOS);
        return $datos;
    }
}
