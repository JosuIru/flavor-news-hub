<?php
declare(strict_types=1);

namespace FlavorNewsHub\Ingest;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Database\IngestLogTable;

/**
 * Ingesta de feeds: recorre fuentes activas, descarga sus feeds con
 * SimplePie (`fetch_feed()`) y crea items nuevos con dedupe por `guid`
 * (fallback a `original_url`).
 *
 * Usa un transient como lock global para evitar que dos ejecuciones
 * concurrentes (cron + WP-CLI, dos cron solapados…) se pisen.
 */
final class FeedIngester
{
    private const NOMBRE_LOCK_TRANSIENT = 'fnh_ingest_lock';
    private const DURACION_LOCK_SEGUNDOS = 5 * MINUTE_IN_SECONDS;

    /**
     * Punto de entrada para cron y para disparo manual sin argumentos.
     *
     * @return array{
     *   skipped?:bool,
     *   reason?:string,
     *   sources_processed?:int,
     *   items_new_total?:int,
     *   items_skipped_total?:int,
     *   errors?:list<array{source_id:int,message:string}>
     * }
     */
    public static function ingestarTodasLasFuentesActivas(): array
    {
        if (!self::adquirirLock()) {
            return [
                'skipped' => true,
                'reason'  => __('Otra ingesta está en curso; se cancela esta.', 'flavor-news-hub'),
            ];
        }

        try {
            $idsFuentesActivas = self::obtenerIdsFuentesActivas();
            $resumenGlobal = [
                'sources_processed'   => 0,
                'items_new_total'     => 0,
                'items_skipped_total' => 0,
                'errors'              => [],
            ];

            foreach ($idsFuentesActivas as $idFuente) {
                $resumenFuente = self::ingestarFuente($idFuente);
                $resumenGlobal['sources_processed']++;
                $resumenGlobal['items_new_total']     += $resumenFuente['items_new'];
                $resumenGlobal['items_skipped_total'] += $resumenFuente['items_skipped'];
                if ($resumenFuente['error'] !== '') {
                    $resumenGlobal['errors'][] = [
                        'source_id' => $idFuente,
                        'message'   => $resumenFuente['error'],
                    ];
                }
            }
            return $resumenGlobal;
        } finally {
            self::liberarLock();
        }
    }

    /**
     * Ingesta una única fuente. No exige el lock global: se puede llamar
     * en paralelo para fuentes distintas si hiciera falta en el futuro.
     *
     * @return array{items_new:int,items_skipped:int,error:string,log_id:int}
     */
    public static function ingestarFuente(int $idFuente): array
    {
        $idLog = self::crearLogInicial($idFuente);
        $contadorNuevos = 0;
        $contadorDescartados = 0;
        $mensajeError = '';

        $urlFeed = (string) get_post_meta($idFuente, '_fnh_feed_url', true);
        if ($urlFeed === '') {
            $mensajeError = __('La fuente no tiene feed_url configurado.', 'flavor-news-hub');
            self::cerrarLog($idLog, 'error', $contadorNuevos, $contadorDescartados, $mensajeError);
            return self::resumenFuente(0, 0, $mensajeError, $idLog);
        }

        // Rama federación: si la fuente declara tipo `flavor_platform`,
        // la URL apunta a una instancia de Flavor Platform y no a un RSS.
        // Delegamos a un ingester especializado que habla con
        // `/flavor-network/v1/*` en lugar de con SimplePie.
        $tipoFeed = (string) get_post_meta($idFuente, '_fnh_feed_type', true);
        if ($tipoFeed === 'flavor_platform') {
            $resumenFlavor = FlavorPlatformIngester::ingestarDeInstancia($idFuente, $urlFeed);
            self::cerrarLog(
                $idLog,
                $resumenFlavor['error'] === '' ? 'success' : 'error',
                $resumenFlavor['items_new'],
                $resumenFlavor['items_skipped'],
                $resumenFlavor['error']
            );
            return self::resumenFuente(
                $resumenFlavor['items_new'],
                $resumenFlavor['items_skipped'],
                $resumenFlavor['error'],
                $idLog
            );
        }

        require_once ABSPATH . WPINC . '/feed.php';

        // SimplePie por defecto envía un UA genérico que servicios como EFF
        // bloquean con HTTP 400. Ponemos uno identificable mientras corre
        // fetch_feed y lo retiramos justo después para no afectar a otros
        // plugins que también usen `fetch_feed` durante la misma request.
        // Timeout 25s (antes 15s): muchos servidores latinoamericanos y
        // de webs autohospedadas tardan más de 10s en handshake TLS y
        // caían sistemáticamente con "cURL error 28" antes de que diera
        // tiempo a leer el feed. 25s sigue siendo razonable para no
        // bloquear la ingesta global cuando un dominio está caído.
        $filtroAjustesFeed = static function (\SimplePie $feed): void {
            $feed->set_useragent('FlavorNewsHubBot/0.2 (+https://flavor.gailu.it)');
            $feed->set_timeout(25);
        };
        // Algunas rutas internas de SimplePie / WordPress usan `WP_Http`
        // y NO el timeout de SimplePie (head request, image probing). Para
        // que esas también respeten el límite generoso, subimos el
        // timeout de `WP_Http` durante la ingesta y lo restauramos
        // después en el `finally`.
        $filtroTimeoutHttp = static function (array $args): array {
            if (!isset($args['timeout']) || (int) $args['timeout'] < 25) {
                $args['timeout'] = 25;
            }
            return $args;
        };
        // WordPress cachea los feeds 12h por defecto (vía
        // wp_feed_cache_transient_lifetime), lo que para un agregador de
        // noticias en vivo es inaceptable: aunque el cron dispare cada
        // 30 min, fetch_feed devuelve el mismo contenido cacheado 12h,
        // y no vemos publicaciones nuevas hasta que expira. Reducimos
        // a 10 min — suficientemente fresco para captar novedades del
        // día, suficientemente largo para no machacar los servidores
        // de los medios si dos ingestas se solapan por cualquier razón.
        $filtroTtlCache = static fn(int $segundos): int => 10 * MINUTE_IN_SECONDS;
        add_action('wp_feed_options', $filtroAjustesFeed);
        add_filter('wp_feed_cache_transient_lifetime', $filtroTtlCache);
        add_filter('http_request_args', $filtroTimeoutHttp);
        // Invalida el transient específico de este feed antes de
        // descargarlo. Crítico en sitios con object-cache externo
        // (Redis, Memcached) donde el transient vive fuera de wp_options
        // y nuestro DELETE global no lo toca. `delete_transient` usa la
        // API correcta que maneja DB + object cache.
        $hashFeed = md5($urlFeed);
        // WordPress guarda el cuerpo cacheado como `feed_{hash}` y la
        // marca de modificación como `feed_mod_{hash}` — prefijo
        // `feed_mod_` delante del hash, no sufijo `_mod` detrás.
        // El sufijo _mod que había aquí nunca borraba nada.
        delete_transient('feed_' . $hashFeed);
        delete_transient('feed_mod_' . $hashFeed);
        $feedDescargado = fetch_feed($urlFeed);
        remove_filter('http_request_args', $filtroTimeoutHttp);
        remove_filter('wp_feed_cache_transient_lifetime', $filtroTtlCache);
        remove_action('wp_feed_options', $filtroAjustesFeed);
        if (is_wp_error($feedDescargado)) {
            $mensajeError = $feedDescargado->get_error_message();
            self::cerrarLog($idLog, 'error', $contadorNuevos, $contadorDescartados, $mensajeError);
            return self::resumenFuente(0, 0, $mensajeError, $idLog);
        }

        $idsTematicasHeredadas = wp_get_object_terms($idFuente, Topic::SLUG, ['fields' => 'ids']);
        if (is_wp_error($idsTematicasHeredadas)) {
            $idsTematicasHeredadas = [];
        }
        $idsTematicasHeredadas = array_map('intval', $idsTematicasHeredadas);

        $maximoItemsPorEjecucion = (int) apply_filters('fnh_max_items_per_ingest', 50);
        $itemsDelFeed = $feedDescargado->get_items(0, $maximoItemsPorEjecucion);

        // Errores de parseo: contamos cuántos items malformados saltamos
        // y guardamos los primeros 3 mensajes para que el log dé pista
        // sobre por qué se descartaron. Antes el catch silenciaba todo
        // y un feed con 49/50 items malos parecía "ingesta exitosa, 1
        // item nuevo" sin avisar al admin.
        $contadorErroresParseo = 0;
        $muestraErroresParseo = [];
        foreach ($itemsDelFeed as $itemFeed) {
            try {
                $datosNormalizados = FeedItemParser::parsear($itemFeed);
            } catch (\Throwable $errorParseo) {
                $contadorErroresParseo++;
                if (count($muestraErroresParseo) < 3) {
                    $muestraErroresParseo[] = $errorParseo->getMessage();
                }
                continue;
            }
            if ($datosNormalizados['title'] === '' || $datosNormalizados['permalink'] === '') {
                continue;
            }
            if (self::yaExisteItem($datosNormalizados['guid'], $datosNormalizados['permalink'])) {
                $contadorDescartados++;
                continue;
            }
            $idItemCreado = self::insertarItem($idFuente, $datosNormalizados, $idsTematicasHeredadas);
            if ($idItemCreado > 0) {
                $contadorNuevos++;
            }
        }

        $mensajeAviso = '';
        if ($contadorErroresParseo > 0) {
            $mensajeAviso = sprintf(
                'Items con error de parseo: %d. Muestra: %s',
                $contadorErroresParseo,
                implode(' | ', $muestraErroresParseo)
            );
        }
        self::cerrarLog($idLog, 'success', $contadorNuevos, $contadorDescartados, $mensajeAviso);
        return self::resumenFuente($contadorNuevos, $contadorDescartados, $mensajeAviso, $idLog);
    }

    /** @return array{items_new:int,items_skipped:int,error:string,log_id:int} */
    private static function resumenFuente(int $nuevos, int $descartados, string $error, int $idLog): array
    {
        return [
            'items_new'     => $nuevos,
            'items_skipped' => $descartados,
            'error'         => $error,
            'log_id'        => $idLog,
        ];
    }

    /**
     * Fuentes activas: las que tienen `_fnh_active = 1` *o* no tienen el
     * meta escrito (coherente con el default `true` de register_post_meta).
     *
     * @return list<int>
     */
    private static function obtenerIdsFuentesActivas(): array
    {
        $consulta = new \WP_Query([
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [
                'relation' => 'OR',
                [
                    'key'     => '_fnh_active',
                    'value'   => '1',
                    'compare' => '=',
                ],
                [
                    'key'     => '_fnh_active',
                    'compare' => 'NOT EXISTS',
                ],
            ],
        ]);
        return array_map('intval', $consulta->posts);
    }

    /**
     * Dedupe: primero por GUID (identificador canónico del feed) y, si no,
     * por URL original del artículo.
     *
     * Público porque `FlavorPlatformIngester` lo reutiliza para deduplicar
     * publicaciones federadas con el mismo contrato.
     */
    public static function yaExisteItem(string $guid, string $permalink): bool
    {
        if ($guid !== '' && self::existeItemConMeta('_fnh_guid', $guid)) {
            return true;
        }
        if ($permalink !== '' && self::existeItemConMeta('_fnh_original_url', $permalink)) {
            return true;
        }
        return false;
    }

    private static function existeItemConMeta(string $claveMeta, string $valorBuscado): bool
    {
        $consulta = new \WP_Query([
            'post_type'      => Item::SLUG,
            'post_status'    => 'any',
            'posts_per_page' => 1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [
                [
                    'key'     => $claveMeta,
                    'value'   => $valorBuscado,
                    'compare' => '=',
                ],
            ],
        ]);
        return !empty($consulta->posts);
    }

    /**
     * @param array{title:string,excerpt:string,permalink:string,published_at:string,guid:string,media_url:string,audio_url?:string} $datosNormalizados
     * @param list<int> $idsTematicas
     *
     * Público porque `FlavorPlatformIngester` también persiste items con
     * este mismo contrato. `audio_url` es opcional porque
     * FlavorPlatformIngester aún no lo provee; los feeds RSS sí.
     */
    public static function insertarItem(int $idFuente, array $datosNormalizados, array $idsTematicas): int
    {
        $timestampPublicacion = $datosNormalizados['published_at'] !== ''
            ? (int) strtotime($datosNormalizados['published_at'])
            : time();
        if ($timestampPublicacion <= 0) {
            $timestampPublicacion = time();
        }
        $fechaPublicacionGmt = gmdate('Y-m-d H:i:s', $timestampPublicacion);
        $fechaPublicacionLocal = get_date_from_gmt($fechaPublicacionGmt);

        $idItemNuevo = wp_insert_post([
            'post_type'     => Item::SLUG,
            'post_status'   => 'publish',
            'post_title'    => $datosNormalizados['title'],
            'post_content'  => $datosNormalizados['excerpt'],
            'post_date'     => $fechaPublicacionLocal,
            'post_date_gmt' => $fechaPublicacionGmt,
            // `tax_input` en wp_insert_post exige capacidades del usuario
            // (en cron no hay usuario). Asignamos después con wp_set_object_terms.
        ], true);

        if (is_wp_error($idItemNuevo) || $idItemNuevo === 0) {
            return 0;
        }

        update_post_meta($idItemNuevo, '_fnh_source_id', $idFuente);
        update_post_meta($idItemNuevo, '_fnh_original_url', $datosNormalizados['permalink']);
        update_post_meta($idItemNuevo, '_fnh_published_at', $datosNormalizados['published_at']);
        // Timestamp Unix como índice numérico. La ISO string puede venir
        // con offsets distintos (Z, +00:00, +02:00…) y ordenar
        // lexicográficamente da resultados incorrectos. El orden por
        // timestamp numérico es siempre correcto y el `since` compara
        // con `NUMERIC` sin ambigüedades de huso.
        update_post_meta($idItemNuevo, '_fnh_published_at_ts', $timestampPublicacion);
        update_post_meta($idItemNuevo, '_fnh_guid', $datosNormalizados['guid']);
        update_post_meta($idItemNuevo, '_fnh_media_url', $datosNormalizados['media_url']);
        // `audio_url` viene del enclosure con MIME audio/* en feeds de
        // podcast. Sin esto, la pestaña Podcasts lista episodios pero
        // el reproductor no tiene nada que sonar.
        $urlAudio = (string) ($datosNormalizados['audio_url'] ?? '');
        if ($urlAudio !== '') {
            update_post_meta($idItemNuevo, '_fnh_audio_url', $urlAudio);
        }

        $segundosDuracion = self::extraerDuracionVideoSiAplica($datosNormalizados['permalink']);
        if ($segundosDuracion > 0) {
            update_post_meta($idItemNuevo, '_fnh_duration_seconds', $segundosDuracion);
        }

        if (!empty($idsTematicas)) {
            wp_set_object_terms($idItemNuevo, $idsTematicas, Topic::SLUG, false);
        }

        return (int) $idItemNuevo;
    }

    /**
     * Si la URL del item apunta a una instancia PeerTube, consulta su API
     * pública (`/api/v1/videos/<uuid>`) para obtener la duración. No hay
     * key, no hay tracking: PeerTube es software libre y expone metadata
     * abiertamente.
     *
     * YouTube no se consulta: su feed RSS no expone duración y la Data API
     * de Google envía cada petición a sus servidores con API key. Rompería
     * el principio "sin terceros" del manifiesto.
     */
    public static function extraerDuracionVideoSiAplica(string $urlOriginal): int
    {
        // Delimitador `~` para no chocar con `#` dentro de la character class.
        if (!preg_match('~^https?://([^/]+)/(?:w/|videos/watch/)([^/?#]+)~', $urlOriginal, $coincidencias)) {
            return 0;
        }
        $instancia = $coincidencias[1];
        $uuid = $coincidencias[2];
        $urlApi = "https://{$instancia}/api/v1/videos/{$uuid}";
        $respuesta = wp_remote_get($urlApi, [
            'timeout' => 8,
            'headers' => ['Accept' => 'application/json'],
        ]);
        if (is_wp_error($respuesta)) {
            return 0;
        }
        if ((int) wp_remote_retrieve_response_code($respuesta) !== 200) {
            return 0;
        }
        $datos = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        if (!is_array($datos)) {
            return 0;
        }
        return max(0, (int) ($datos['duration'] ?? 0));
    }

    private static function crearLogInicial(int $idFuente): int
    {
        global $wpdb;
        $wpdb->insert(
            IngestLogTable::nombreCompleto(),
            [
                'source_id'  => $idFuente,
                'status'     => 'running',
                'started_at' => current_time('mysql', 1),
            ],
            ['%d', '%s', '%s']
        );
        return (int) $wpdb->insert_id;
    }

    private static function cerrarLog(
        int $idLog,
        string $estadoFinal,
        int $contadorNuevos,
        int $contadorDescartados,
        string $mensajeError
    ): void {
        if ($idLog === 0) {
            return;
        }
        global $wpdb;
        $wpdb->update(
            IngestLogTable::nombreCompleto(),
            [
                'status'        => $estadoFinal,
                'finished_at'   => current_time('mysql', 1),
                'items_new'     => $contadorNuevos,
                'items_skipped' => $contadorDescartados,
                'error_message' => $mensajeError === '' ? null : $mensajeError,
            ],
            ['id' => $idLog],
            ['%s', '%s', '%d', '%d', '%s'],
            ['%d']
        );
    }

    /**
     * Lock atómico vía `add_option()` con autoload='no'. `add_option()`
     * hace INSERT en `wp_options` con UNIQUE KEY sobre `option_name` —
     * MySQL garantiza que sólo uno de N procesos concurrentes tiene
     * éxito. El transient antes (`get_transient` + `set_transient`) era
     * un patrón de read-then-write que permitía races: dos procesos
     * podían leer "no existe" antes de escribir.
     *
     * Expiración: guardamos la hora de adquisición y, si al intentar
     * adquirir ya existe pero el timestamp es más viejo que el TTL, lo
     * consideramos stale y lo sobreescribimos (el proceso original
     * murió sin limpiar).
     */
    private static function adquirirLock(): bool
    {
        $ahora = time();
        $ok = add_option(self::NOMBRE_LOCK_TRANSIENT, (string) $ahora, '', 'no');
        if ($ok) {
            return true;
        }
        // Ya existe. Comprobamos si está stale.
        $previo = (int) get_option(self::NOMBRE_LOCK_TRANSIENT, '0');
        if ($previo > 0 && ($ahora - $previo) < self::DURACION_LOCK_SEGUNDOS) {
            return false;
        }
        // Stale: lo robamos. Es un race residual mínimo (dos procesos
        // leyendo stale a la vez), pero para ingesta periódica de feeds
        // es aceptable y cubre el 99% del problema.
        update_option(self::NOMBRE_LOCK_TRANSIENT, (string) $ahora, 'no');
        return true;
    }

    private static function liberarLock(): void
    {
        delete_option(self::NOMBRE_LOCK_TRANSIENT);
    }
}
