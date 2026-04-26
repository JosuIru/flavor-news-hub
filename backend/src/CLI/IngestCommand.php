<?php
declare(strict_types=1);

namespace FlavorNewsHub\CLI;

use FlavorNewsHub\Ingest\FeedIngester;
use FlavorNewsHub\Ingest\FeedItemParser;
use FlavorNewsHub\CPT\Source;

/**
 * Comandos WP-CLI del plugin. Registrado en Plugin::arrancar() únicamente
 * cuando la constante `WP_CLI` está definida (ejecución desde CLI).
 *
 * Ejemplos:
 *   wp flavor-news ingest
 *   wp flavor-news ingest --source=42
 */
final class IngestCommand
{
    /**
     * Ingesta feeds ahora mismo, sin esperar al cron.
     *
     * ## OPTIONS
     *
     * [--source=<id>]
     * : ID de la fuente a ingestar. Si no se indica, procesa todas las activas.
     *
     * ## EXAMPLES
     *
     *     wp flavor-news ingest
     *     wp flavor-news ingest --source=42
     *
     * @param array<int,string>    $argumentosPosicionales
     * @param array<string,string> $argumentosConNombre
     */
    public function ingest($argumentosPosicionales, $argumentosConNombre): void
    {
        if (isset($argumentosConNombre['source'])) {
            $this->ingestarUnaFuente((int) $argumentosConNombre['source']);
            return;
        }
        $this->ingestarTodas();
    }

    private function ingestarUnaFuente(int $idFuente): void
    {
        if ($idFuente <= 0) {
            \WP_CLI::error('--source debe ser un ID positivo.');
        }
        $postFuente = get_post($idFuente);
        if (!$postFuente || $postFuente->post_type !== Source::SLUG) {
            \WP_CLI::error("La fuente #{$idFuente} no existe.");
        }

        \WP_CLI::log("Ingestando fuente #{$idFuente}: {$postFuente->post_title}");
        $resumen = FeedIngester::ingestarFuente($idFuente);

        if ($resumen['error'] !== '') {
            \WP_CLI::error($resumen['error']);
        }
        \WP_CLI::success(sprintf(
            'Ingesta OK. Nuevos: %d. Descartados por dedupe: %d. Log ID: %d.',
            $resumen['items_new'],
            $resumen['items_skipped'],
            $resumen['log_id']
        ));
    }

    private function ingestarTodas(): void
    {
        \WP_CLI::log('Ingestando todas las fuentes activas…');
        $resumen = FeedIngester::ingestarTodasLasFuentesActivas();

        if (!empty($resumen['skipped'])) {
            \WP_CLI::warning($resumen['reason']);
            return;
        }

        \WP_CLI::success(sprintf(
            'Procesadas %d fuentes. Nuevos: %d. Descartados: %d. Errores: %d.',
            $resumen['sources_processed'],
            $resumen['items_new_total'],
            $resumen['items_skipped_total'],
            count($resumen['errors'])
        ));
        foreach ($resumen['errors'] as $detalleError) {
            \WP_CLI::log(sprintf(' - Fuente #%d: %s', $detalleError['source_id'], $detalleError['message']));
        }
    }

    /**
     * Detecta sources publicadas con el mismo `_fnh_feed_url`. Útil
     * para diagnosticar el ruido de duplicados que aparece en la
     * pantalla "Estado de fuentes" cuando un import antiguo dejó
     * varios posts apuntando al mismo RSS.
     *
     * Por defecto sólo lista. Con `--desactivar` mantiene activa la
     * fuente con más items totales en cada grupo y desactiva el resto
     * (`_fnh_active=0`). No borra nada — los posts duplicados se
     * pueden recuperar editando el meta a mano si hace falta.
     *
     * ## OPTIONS
     *
     * [--desactivar]
     * : Si se pasa, desactiva los duplicados (mantiene el más activo).
     *
     * ## EXAMPLES
     *
     *     wp flavor-news duplicates
     *     wp flavor-news duplicates --desactivar
     *
     * @param array<int,string>    $argumentosPosicionales
     * @param array<string,string> $argumentosConNombre
     */
    public function duplicates($argumentosPosicionales, $argumentosConNombre): void
    {
        $debeDesactivar = isset($argumentosConNombre['desactivar']);
        global $wpdb;
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT pm.meta_value AS feed_url, p.ID AS source_id, p.post_title AS nombre,
                    (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                       INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                       WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                         AND pi.post_status = 'publish'
                    ) AS total_items
             FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_fnh_feed_url'
               AND pm.meta_value <> ''
               AND p.post_type = %s
               AND p.post_status = 'publish'
             ORDER BY pm.meta_value, total_items DESC, p.ID ASC",
            Source::SLUG
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];

        $grupos = [];
        foreach ($filas as $fila) {
            $url = (string) $fila['feed_url'];
            $grupos[$url][] = $fila;
        }
        $grupos = array_filter($grupos, static fn(array $g): bool => count($g) > 1);

        if (empty($grupos)) {
            \WP_CLI::success('No hay duplicados por feed_url.');
            return;
        }

        \WP_CLI::log(sprintf('Encontrados %d grupos de duplicados:', count($grupos)));
        $totalDesactivados = 0;
        foreach ($grupos as $url => $grupo) {
            \WP_CLI::log('');
            \WP_CLI::log('  ' . $url);
            foreach ($grupo as $indice => $fila) {
                $marca = $indice === 0 ? '★' : ' ';
                \WP_CLI::log(sprintf(
                    '    %s #%d  %s  (items: %d)',
                    $marca,
                    (int) $fila['source_id'],
                    $fila['nombre'],
                    (int) $fila['total_items']
                ));
            }
            if ($debeDesactivar) {
                // Mantener el primero (más items) y desactivar el resto.
                foreach (array_slice($grupo, 1) as $fila) {
                    update_post_meta((int) $fila['source_id'], '_fnh_active', false);
                    $totalDesactivados++;
                }
            }
        }

        if ($debeDesactivar) {
            \WP_CLI::success(sprintf(
                'Desactivadas %d fuentes duplicadas. La principal (★) de cada grupo queda activa.',
                $totalDesactivados
            ));
        } else {
            \WP_CLI::log('');
            \WP_CLI::log('Vuelve a ejecutar con --desactivar para desactivar las duplicadas.');
        }
    }

    /**
     * Diagnostica por qué una fuente no aporta items: descarga el feed
     * en vivo, muestra status HTTP/size/content-type y clasifica cada
     * item del feed en NUEVO / DEDUPE / INVÁLIDO. Útil para entender
     * fuentes "muertas" (sin items en 30d) que no tienen error explícito
     * — pueden estar dándonos siempre los mismos items viejos
     * (descartados por dedupe) o items sin pubDate / title.
     *
     * ## OPTIONS
     *
     * <source>
     * : ID de la fuente a diagnosticar.
     *
     * ## EXAMPLES
     *
     *     wp flavor-news diagnose --source=42
     *
     * @param array<int,string>    $argumentosPosicionales
     * @param array<string,string> $argumentosConNombre
     */
    public function diagnose($argumentosPosicionales, $argumentosConNombre): void
    {
        $idSource = isset($argumentosConNombre['source']) ? (int) $argumentosConNombre['source'] : 0;
        if ($idSource <= 0) {
            \WP_CLI::error('--source=ID es obligatorio.');
        }
        $post = get_post($idSource);
        if (!$post || $post->post_type !== Source::SLUG) {
            \WP_CLI::error("La fuente #{$idSource} no existe.");
        }
        $urlFeed = (string) get_post_meta($idSource, '_fnh_feed_url', true);
        if ($urlFeed === '') {
            \WP_CLI::error('La fuente no tiene feed_url configurado.');
        }

        \WP_CLI::log('Fuente #' . $idSource . ': ' . $post->post_title);
        \WP_CLI::log('Feed URL: ' . $urlFeed);
        \WP_CLI::log('');

        // Petición HTTP cruda — sin pasar por SimplePie — para ver
        // exactamente qué devuelve el servidor.
        $respuesta = wp_remote_get($urlFeed, [
            'timeout' => 25,
            'user-agent' => 'FlavorNewsHubBot/0.2 (+https://flavor.gailu.it)',
            'sslverify' => true,
        ]);
        if (is_wp_error($respuesta)) {
            \WP_CLI::warning('HTTP error: ' . $respuesta->get_error_message());
            \WP_CLI::log('Reintentando con sslverify=false…');
            $respuesta = wp_remote_get($urlFeed, [
                'timeout' => 25,
                'user-agent' => 'FlavorNewsHubBot/0.2 (+https://flavor.gailu.it)',
                'sslverify' => false,
            ]);
            if (is_wp_error($respuesta)) {
                \WP_CLI::error('Tampoco con sslverify=false: ' . $respuesta->get_error_message());
            }
            \WP_CLI::log('  ✓ Funciona sin verificar SSL — añade el dominio a DOMINIOS_SSL_BYPASS.');
        }
        $codigoHttp = (int) wp_remote_retrieve_response_code($respuesta);
        $contentType = wp_remote_retrieve_header($respuesta, 'content-type');
        $cuerpo = (string) wp_remote_retrieve_body($respuesta);
        \WP_CLI::log('HTTP status:  ' . $codigoHttp);
        \WP_CLI::log('Content-type: ' . (is_string($contentType) ? $contentType : '(no header)'));
        \WP_CLI::log('Body size:    ' . strlen($cuerpo) . ' bytes');
        \WP_CLI::log('');

        if ($codigoHttp !== 200) {
            \WP_CLI::error('El servidor no devuelve 200 — el feed está caído o la URL es incorrecta.');
        }
        if (stripos((string) $contentType, 'html') !== false && stripos($cuerpo, '<rss') === false && stripos($cuerpo, '<feed') === false) {
            \WP_CLI::warning('El servidor devuelve HTML, no XML. El feed se ha movido o ya no existe.');
            \WP_CLI::log('Busca <link rel="alternate" type="application/rss+xml"> en el HTML para encontrar la URL nueva.');
            return;
        }

        // Ahora pedimos el feed con SimplePie igual que hace la ingesta.
        require_once ABSPATH . WPINC . '/feed.php';
        $hashFeed = md5($urlFeed);
        delete_transient('feed_' . $hashFeed);
        delete_transient('feed_mod_' . $hashFeed);
        $filtroUa = static function (\SimplePie $feed): void {
            $feed->set_useragent('FlavorNewsHubBot/0.2 (+https://flavor.gailu.it)');
            $feed->set_timeout(25);
        };
        add_action('wp_feed_options', $filtroUa);
        $feed = fetch_feed($urlFeed);
        remove_action('wp_feed_options', $filtroUa);

        if (is_wp_error($feed)) {
            \WP_CLI::error('SimplePie no parseó el feed: ' . $feed->get_error_message());
        }

        $items = $feed->get_items(0, 50);
        \WP_CLI::log(sprintf('Items parseados por SimplePie: %d', count($items)));
        \WP_CLI::log('');

        $contadores = ['nuevo' => 0, 'dedupe' => 0, 'invalido' => 0];
        $detalles = [];
        foreach ($items as $itemFeed) {
            try {
                $datos = FeedItemParser::parsear($itemFeed);
            } catch (\Throwable $error) {
                $contadores['invalido']++;
                $detalles[] = ['estado' => 'INVÁLIDO (parse error)', 'titulo' => '(error: ' . $error->getMessage() . ')', 'fecha' => '-'];
                continue;
            }
            if ($datos['title'] === '' || $datos['permalink'] === '') {
                $contadores['invalido']++;
                $detalles[] = [
                    'estado' => 'INVÁLIDO',
                    'titulo' => $datos['title'] !== '' ? $datos['title'] : '(sin title)',
                    'fecha'  => $datos['published_at'] ?: '(sin fecha)',
                ];
                continue;
            }
            $existe = FeedIngester::yaExisteItem($datos['guid'], $datos['permalink']);
            if ($existe) {
                $contadores['dedupe']++;
                $detalles[] = [
                    'estado' => 'DEDUPE',
                    'titulo' => $datos['title'],
                    'fecha'  => $datos['published_at'] ?: '(sin fecha)',
                ];
            } else {
                $contadores['nuevo']++;
                $detalles[] = [
                    'estado' => 'NUEVO',
                    'titulo' => $datos['title'],
                    'fecha'  => $datos['published_at'] ?: '(sin fecha)',
                ];
            }
        }

        foreach ($detalles as $detalle) {
            \WP_CLI::log(sprintf(
                '  [%-9s] %s · %s',
                $detalle['estado'],
                substr($detalle['fecha'], 0, 19),
                substr($detalle['titulo'], 0, 80)
            ));
        }
        \WP_CLI::log('');
        \WP_CLI::log(sprintf(
            'Resumen: %d nuevos · %d dedupe · %d inválidos',
            $contadores['nuevo'], $contadores['dedupe'], $contadores['invalido']
        ));

        if ($contadores['nuevo'] === 0 && $contadores['dedupe'] > 0) {
            \WP_CLI::log('');
            \WP_CLI::log('Diagnóstico: el feed nos da SIEMPRE los mismos items que ya tenemos.');
            \WP_CLI::log('Posibles causas: el medio dejó de publicar, o el feed sólo expone un');
            \WP_CLI::log('histórico fijo y los items nuevos viven en otra URL. Mira manualmente');
            \WP_CLI::log('la web del medio para ver si publica y compara con el contenido del RSS.');
        }
        if ($contadores['invalido'] > 0) {
            \WP_CLI::log('');
            \WP_CLI::log('Hay items INVÁLIDOS (sin title/permalink). Probable: el feed devuelve');
            \WP_CLI::log('XML mal formado o entradas vacías. Si todos los items son inválidos, el');
            \WP_CLI::log('feed está roto del lado del medio aunque devuelva 200.');
        }
    }
}
