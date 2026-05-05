<?php
declare(strict_types=1);

namespace FlavorNewsHub\Ingest;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Support\Transients;

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

    /**
     * Intervalo mínimo entre dos peticiones consecutivas al mismo host
     * dentro de una ingesta global (microsegundos). Evita que servicios
     * con anti-scraping (YouTube `feeds/videos.xml`, WAFs tipo Cloudflare
     * o mod_security en hostings compartidos) respondan 404/403 a una
     * ráfaga de peticiones desde la misma IP. Es una causa frecuente de
     * errores espurios en el log: el feed_url está bien y el canal
     * responde a peticiones individuales, pero la ingesta los pide tan
     * seguidos que el servidor remoto los rechaza.
     *
     * 1.5 s funciona en YouTube; ajustable por host vía filtro
     * `fnh_intervalo_minimo_host_microseg`.
     */
    private const INTERVALO_MINIMO_HOST_MICROSEG = 1_500_000;

    /**
     * Mapa host => micro-timestamp de la última petición. Vive durante
     * la ingesta y se usa para el throttle reactivo. Reset al inicio de
     * `ingestarTodasLasFuentesActivas()`.
     *
     * @var array<string, float>
     */
    private static array $ultimoRequestPorHost = [];

    /**
     * Dominios cuyo certificado TLS está mal configurado del lado del
     * servidor (cadena incompleta, autofirmado, expirado…) y que
     * fallan con `cURL error 60: SSL certificate problem` aunque el
     * feed sea legítimo y público. Para estos saltamos la verificación
     * SSL — el riesgo de MITM es bajo en feeds RSS sin auth y la
     * alternativa es renunciar al contenido.
     *
     * Lista mantenida a mano. El admin puede ampliar via filtro
     * `fnh_dominios_ssl_bypass`.
     */
    private const DOMINIOS_SSL_BYPASS = [
        // Cadena incompleta: las 5 radios indígenas mexicanas del INPI
        // (Voz de la Mixteca, de la Montaña, de las Huastecas, del
        // Valle, de los Vientos, de los Mayas, de los Vientos…).
        'ecos.inpi.gob.mx',
    ];

    /**
     * Cabeceras condicionales: meta donde guardamos el ETag y el
     * Last-Modified que devolvió el servidor en el último fetch
     * exitoso. En la siguiente ronda los mandamos como If-None-Match
     * e If-Modified-Since para que el origen pueda devolver
     * `304 Not Modified` (sin cuerpo) si nada ha cambiado.
     *
     * Beneficio doble:
     *  - Reducimos drásticamente el ancho de banda consumido (la
     *    inmensa mayoría de feeds no cambian entre cron y cron).
     *  - Algunos WAFs (Sucuri, Cloudflare) usan "respeta cabeceras
     *    condicionales" como heurística de cliente legítimo: dejar
     *    de bajar el feed entero cuando devuelven 304 nos saca de
     *    listas de "scrapers agresivos" y reduce el riesgo de que
     *    nuestra IP acabe en blacklist colectiva.
     */
    public const META_ETAG = '_fnh_etag';
    public const META_LAST_MODIFIED = '_fnh_last_modified';

    /**
     * Circuit breaker: cuando una fuente acumula errores consecutivos
     * (DNS muerto, 403/486 anti-bot, timeouts persistentes…), en
     * lugar de seguir golpeándola en cada ciclo la ponemos en
     * cuarentena. Reduce el ruido del log de ingesta y, sobre todo,
     * deja de gastar peticiones contra orígenes que ya nos rechazan
     * — lo que es señal de "buen ciudadano" para WAFs heurísticos.
     *
     * Política escalonada por número de fallos:
     *  - <5 errores → reintento normal en cada cron.
     *  - 5-9         → cuarentena 1h ±25%.
     *  - 10-19       → cuarentena 6h ±25%.
     *  - 20+         → cuarentena 24h ±25%.
     *
     * El jitter ±25% evita que cientos de fuentes que cayeron en la
     * misma ronda salgan de cuarentena a la vez (thundering herd).
     */
    public const META_ERRORES_CONSECUTIVOS = '_fnh_consecutive_errors';
    public const META_PROXIMO_INTENTO_TRAS = '_fnh_next_attempt_after';
    private const UMBRAL_CUARENTENA_1H = 5;
    private const UMBRAL_CUARENTENA_6H = 10;
    private const UMBRAL_CUARENTENA_24H = 20;

    /**
     * Jitter entre fuentes en una ingesta global (microsegundos).
     * El throttle por host (`INTERVALO_MINIMO_HOST_MICROSEG`) sólo
     * pausa cuando la siguiente fuente comparte host con la anterior;
     * entre dominios distintos la cola corría sin pausa, lo que
     * convertía 280+ fuentes en una ráfaga concentrada de pocos
     * minutos — patrón clásico que disparan los anti-bot heurísticos
     * tipo Sucuri (que devolvían 486 a una porción significativa de
     * fuentes desde nuestra IP de salida).
     *
     * Con un jitter aleatorio entre 200 y 600 ms, el ciclo se alarga
     * de ~5 a ~12 min — irrelevante para un cron, decisivo para
     * dejar de parecer un scraper.
     */
    private const JITTER_MIN_MICROSEG = 200_000;
    private const JITTER_MAX_MICROSEG = 600_000;

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
            // Reset del registro de peticiones por host: cada ingesta
            // global es una "ronda" independiente. Sin este reset, una
            // segunda ingesta en el mismo proceso PHP heredaría
            // timestamps obsoletos y aplicaría throttles innecesarios.
            self::$ultimoRequestPorHost = [];

            // Recuperación de logs huérfanos: si en rondas anteriores el
            // proceso PHP murió por `max_execution_time` antes de cerrar
            // el log de la fuente que tocaba, ese log queda en `running`
            // para siempre y la fuente se reintenta cada ronda con el
            // mismo desenlace. Aquí marcamos como `error` cualquier log
            // `running` con >umbral de antigüedad. El lock global
            // garantiza que no pisamos un log legítimo de una ronda en
            // curso.
            self::recuperarLogsHuerfanos();

            $idsFuentesActivas = self::obtenerIdsFuentesActivas();
            $resumenGlobal = [
                'sources_processed'   => 0,
                'items_new_total'     => 0,
                'items_skipped_total' => 0,
                'errors'              => [],
            ];

            $totalFuentes = count($idsFuentesActivas);
            foreach ($idsFuentesActivas as $indice => $idFuente) {
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
                // Jitter entre fuentes (no después de la última, que no
                // sirve de nada). Default 0: el throttle por host
                // (1.5s entre peticiones al mismo host) ya cubre
                // YouTube/Cloudflare; añadir jitter global empuja el
                // cron por encima de `max_execution_time`. Lo dejamos
                // detrás de filtro por si en algún sitio concreto
                // vuelve a hacer falta.
                if ($indice < $totalFuentes - 1) {
                    $microsegEspera = (int) apply_filters(
                        'fnh_jitter_entre_fuentes_microseg',
                        0
                    );
                    if ($microsegEspera > 0) {
                        usleep($microsegEspera);
                    }
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
        // Circuit breaker: si la fuente está en cuarentena por errores
        // consecutivos previos, salimos en silencio antes de crear el
        // log. NO loggeamos el skip — si lo hiciéramos, una fuente
        // muerta inundaría la tabla de logs con cientos de "skipped
        // por cuarentena" inútiles. El admin ve la cuarentena
        // indirectamente: la fuente no aparece en los logs recientes
        // hasta que pasa el plazo o resetea manualmente.
        if (self::estaEnCuarentena($idFuente)) {
            return self::resumenFuente(0, 0, '', 0);
        }

        $idLog = self::crearLogInicial($idFuente);
        $contadorNuevos = 0;
        $contadorDescartados = 0;
        $mensajeError = '';

        $urlFeed = (string) get_post_meta($idFuente, '_fnh_feed_url', true);
        if ($urlFeed === '') {
            $mensajeError = __('La fuente no tiene feed_url configurado.', 'flavor-news-hub');
            self::cerrarLog($idLog, 'error', $contadorNuevos, $contadorDescartados, $mensajeError);
            self::registrarErrorYProgramarReintento($idFuente);
            return self::resumenFuente(0, 0, $mensajeError, $idLog);
        }

        // Rama federación: si la fuente declara tipo `flavor_platform`,
        // la URL apunta a una instancia de Flavor Platform y no a un RSS.
        // Delegamos a un ingester especializado que habla con
        // `/flavor-network/v1/*` en lugar de con SimplePie.
        $tipoFeed = (string) get_post_meta($idFuente, '_fnh_feed_type', true);
        if ($tipoFeed === 'flavor_platform') {
            $resumenFlavor = FlavorPlatformIngester::ingestarDeInstancia($idFuente, $urlFeed);
            $huboError = $resumenFlavor['error'] !== '';
            self::cerrarLog(
                $idLog,
                $huboError ? 'error' : 'success',
                $resumenFlavor['items_new'],
                $resumenFlavor['items_skipped'],
                $resumenFlavor['error']
            );
            if ($huboError) {
                self::registrarErrorYProgramarReintento($idFuente);
            } else {
                self::resetearContadorErrores($idFuente);
            }
            return self::resumenFuente(
                $resumenFlavor['items_new'],
                $resumenFlavor['items_skipped'],
                $resumenFlavor['error'],
                $idLog
            );
        }

        require_once ABSPATH . WPINC . '/feed.php';

        // Throttle reactivo por host: si ya pedimos al mismo host hace
        // <1.5s, dormimos la diferencia. Evita que YouTube/WAFs
        // devuelvan 404/403 espurios cuando hay 50+ canales seguidos en
        // la cola. No pausa cuando el host es nuevo en la ronda actual.
        $hostFeed = strtolower((string) wp_parse_url($urlFeed, PHP_URL_HOST));
        self::aplicarThrottlePorHost($hostFeed);

        // Fetch HTTP propio (en lugar de `fetch_feed`) por dos motivos:
        //   1) Permite mandar `If-None-Match` / `If-Modified-Since`
        //      con los valores que guardamos del último éxito, así el
        //      servidor puede responder `304 Not Modified` (sin cuerpo)
        //      cuando el feed no ha cambiado. Esto reduce ancho de
        //      banda ~80% y nos saca de listas de "scrapers agresivos"
        //      en WAFs heurísticos.
        //   2) Da control total sobre cabeceras y SSL bypass; SimplePie
        //      sólo se encarga del parseo (vía `set_raw_data`), no del
        //      transporte.
        $resultadoHttp = self::fetchFeedHttp($idFuente, $urlFeed, $hostFeed);
        if (isset($resultadoHttp['not_modified'])) {
            // 304: feed inalterado desde la última ronda. Cerramos el
            // log como "success" con 0 items y un aviso explícito para
            // que el admin entienda por qué no hay nuevos.
            self::cerrarLog(
                $idLog,
                'success',
                0,
                0,
                'Feed no modificado desde el último fetch (304).'
            );
            self::resetearContadorErrores($idFuente);
            return self::resumenFuente(0, 0, '', $idLog);
        }
        if (isset($resultadoHttp['error'])) {
            $mensajeError = $resultadoHttp['error'];
            self::cerrarLog($idLog, 'error', 0, 0, $mensajeError);
            self::registrarErrorYProgramarReintento($idFuente);
            return self::resumenFuente(0, 0, $mensajeError, $idLog);
        }

        // Persistimos los validadores que devolvió el origen para la
        // próxima ronda. Si el origen no manda ETag pero sí
        // Last-Modified (o al revés), usaremos sólo el que tengamos.
        update_post_meta($idFuente, self::META_ETAG, (string) $resultadoHttp['etag']);
        update_post_meta($idFuente, self::META_LAST_MODIFIED, (string) $resultadoHttp['last_modified']);

        // Pasamos el cuerpo crudo a SimplePie. `init()` parsea sin
        // hacer HTTP — todo el transporte ya lo hicimos en `fetchFeedHttp`.
        // El charset se detecta del XML declaration o del BOM, no del
        // Content-Type del response (que tampoco tendríamos aquí).
        $feedDescargado = new \SimplePie();
        $feedDescargado->set_raw_data((string) $resultadoHttp['body']);
        $feedDescargado->init();
        if ($feedDescargado->error()) {
            $mensajeError = (string) $feedDescargado->error();
            self::cerrarLog($idLog, 'error', 0, 0, $mensajeError);
            self::registrarErrorYProgramarReintento($idFuente);
            return self::resumenFuente(0, 0, $mensajeError, $idLog);
        }

        $idsTematicasHeredadas = wp_get_object_terms($idFuente, Topic::SLUG, ['fields' => 'ids']);
        if (is_wp_error($idsTematicasHeredadas)) {
            $idsTematicasHeredadas = [];
        }
        $idsTematicasHeredadas = array_map('intval', $idsTematicasHeredadas);

        $maximoItemsPorEjecucion = (int) apply_filters('fnh_max_items_per_ingest', 50);
        $itemsDelFeed = $feedDescargado->get_items(0, $maximoItemsPorEjecucion);

        // Pre-parseo: normalizamos y filtramos vacíos primero, después
        // consultamos en UNA sola query qué GUIDs/permalinks de este
        // batch ya existen en BD. Antes hacíamos 2 SELECT por item
        // (yaExisteItem → existeItemConMeta dos veces) — para 50 items
        // y 12K items en BD eran 100 queries cada una con meta_query
        // y JOIN. Con prefetch baja a 1 query.
        $contadorErroresParseo = 0;
        $muestraErroresParseo = [];
        $itemsPreparados = [];
        $guidsBatch = [];
        $permalinksBatch = [];
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
            $itemsPreparados[] = $datosNormalizados;
            if ($datosNormalizados['guid'] !== '') {
                $guidsBatch[] = $datosNormalizados['guid'];
            }
            if ($datosNormalizados['permalink'] !== '') {
                $permalinksBatch[] = $datosNormalizados['permalink'];
            }
        }

        $guidsExistentes = self::prefetchValoresMetaExistentes('_fnh_guid', $guidsBatch);
        $permalinksExistentes = self::prefetchValoresMetaExistentes('_fnh_original_url', $permalinksBatch);

        foreach ($itemsPreparados as $datosNormalizados) {
            $existeGuid = $datosNormalizados['guid'] !== ''
                && isset($guidsExistentes[$datosNormalizados['guid']]);
            $existePermalink = $datosNormalizados['permalink'] !== ''
                && isset($permalinksExistentes[$datosNormalizados['permalink']]);
            if ($existeGuid || $existePermalink) {
                $contadorDescartados++;
                continue;
            }
            $idItemCreado = self::insertarItem($idFuente, $datosNormalizados, $idsTematicasHeredadas);
            if ($idItemCreado > 0) {
                $contadorNuevos++;
                // Añadimos al set para evitar duplicados intra-batch:
                // dos items del mismo feed pueden compartir GUID por
                // bug de la fuente y no queremos insertar dos veces.
                if ($datosNormalizados['guid'] !== '') {
                    $guidsExistentes[$datosNormalizados['guid']] = true;
                }
                if ($datosNormalizados['permalink'] !== '') {
                    $permalinksExistentes[$datosNormalizados['permalink']] = true;
                }
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
        self::resetearContadorErrores($idFuente);
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
    /**
     * Throttle reactivo por host: si la última petición a este host se
     * hizo dentro del intervalo mínimo configurado, duerme el resto.
     * No registra timestamps de hosts vacíos (URLs malformadas) — esos
     * fallan en otra capa.
     *
     * Filtro `fnh_intervalo_minimo_host_microseg` para ajustar por host
     * (recibe `int $microseg` y `string $host`); devolver 0 desactiva
     * el throttle (útil en tests, donde las peticiones están mockeadas
     * y el sleep no aporta nada).
     */
    private static function aplicarThrottlePorHost(string $host): void
    {
        if ($host === '') {
            return;
        }
        $intervaloMin = (int) apply_filters(
            'fnh_intervalo_minimo_host_microseg',
            self::INTERVALO_MINIMO_HOST_MICROSEG,
            $host
        );
        if ($intervaloMin <= 0) {
            self::$ultimoRequestPorHost[$host] = microtime(true);
            return;
        }
        $ahoraMicro = microtime(true);
        $ultimoMicro = self::$ultimoRequestPorHost[$host] ?? 0.0;
        if ($ultimoMicro > 0.0) {
            $transcurridoMicroseg = (int) (($ahoraMicro - $ultimoMicro) * 1_000_000);
            $faltanMicroseg = $intervaloMin - $transcurridoMicroseg;
            if ($faltanMicroseg > 0) {
                usleep($faltanMicroseg);
                $ahoraMicro = microtime(true);
            }
        }
        self::$ultimoRequestPorHost[$host] = $ahoraMicro;
    }

    /**
     * Decide si un host concreto debe saltarse la verificación TLS.
     * Match exacto o por sufijo (`.dominio`) — así un subdominio nuevo
     * de un host ya conocido se cubre sin tocar la lista. Filtrable
     * para que un sitio pueda ampliar la lista sin parchear el código.
     */
    private static function dominioRequiereBypassSsl(string $host): bool
    {
        $host = trim($host, '.');
        if ($host === '') {
            return false;
        }
        $dominios = (array) apply_filters('fnh_dominios_ssl_bypass', self::DOMINIOS_SSL_BYPASS);
        foreach ($dominios as $dominio) {
            $dominio = strtolower(trim((string) $dominio, '.'));
            if ($dominio === '') continue;
            if ($host === $dominio) return true;
            if (str_ends_with($host, '.' . $dominio)) return true;
        }
        return false;
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

    /**
     * Devuelve un mapa [valor => true] con los meta_value de la lista
     * que YA existen en `wp_postmeta` para la clave dada y posts del
     * tipo Item. Una sola query con IN(...) en lugar de N consultas
     * individuales. Usado por la ingesta para dedupe en bloque por
     * lote (típicamente 50 items por feed).
     *
     * @param string[] $valoresBuscados
     * @return array<string,bool>
     */
    private static function prefetchValoresMetaExistentes(string $claveMeta, array $valoresBuscados): array
    {
        if (empty($valoresBuscados)) {
            return [];
        }
        global $wpdb;
        // Limpieza y dedupe local antes del IN(...).
        $valoresUnicos = array_values(array_unique(array_filter(
            $valoresBuscados,
            static fn(string $v): bool => $v !== ''
        )));
        if (empty($valoresUnicos)) {
            return [];
        }
        $placeholders = implode(',', array_fill(0, count($valoresUnicos), '%s'));
        $sql = $wpdb->prepare(
            "SELECT pm.meta_value
             FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = %s
               AND pm.meta_value IN ({$placeholders})
               AND p.post_type = %s",
            array_merge([$claveMeta], $valoresUnicos, [Item::SLUG])
        );
        $valoresEncontrados = $wpdb->get_col($sql);
        $mapa = [];
        foreach ($valoresEncontrados as $valor) {
            $mapa[(string) $valor] = true;
        }
        return $mapa;
    }

    /**
     * IDs de las fuentes activas (post_status=publish y meta `_fnh_active`
     * a '1' o ausente). Las que tienen el meta a '0' se excluyen.
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

    /**
     * Marca como `error` los logs en `running` con más de N minutos de
     * antigüedad (default 5). Para cada uno, incrementa el contador de
     * errores consecutivos de la fuente para activar la cuarentena
     * progresiva (5/10/20 errores → 1h/6h/24h). Sin esto, una fuente
     * que siempre hace timeout se reintentaría cada ronda y mantendría
     * el cron al borde del `max_execution_time` indefinidamente.
     */
    private static function recuperarLogsHuerfanos(): void
    {
        global $wpdb;
        // Umbral conservador: si el lock global expiró pero el proceso
        // PHP del cron previo sigue vivo (típico cuando el worker tarda
        // entre 3-7 minutos en una ronda), mi código no debe marcar
        // su log como huérfano — sería un falso positivo que dispararía
        // cuarentena innecesaria. 10 min cubre el peor caso esperado
        // de un cron lento sin matar logs todavía vivos.
        $minutosUmbral = (int) apply_filters('fnh_log_huerfano_minutos', 10);
        $nombreTabla = IngestLogTable::nombreCompleto();

        $filasHuerfanas = $wpdb->get_results($wpdb->prepare(
            "SELECT id, source_id FROM {$nombreTabla}
             WHERE status = 'running'
               AND started_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d MINUTE)",
            $minutosUmbral
        ));
        if (!is_array($filasHuerfanas) || empty($filasHuerfanas)) {
            return;
        }

        $mensajeRecuperacion = sprintf(
            /* translators: %d = minutos */
            __('Log huérfano recuperado: el proceso anterior superó el timeout (%d min) sin cerrar el log. Probable timeout HTTP o exceso de max_execution_time.', 'flavor-news-hub'),
            $minutosUmbral
        );

        foreach ($filasHuerfanas as $filaHuerfana) {
            $wpdb->update(
                $nombreTabla,
                [
                    'status'        => 'error',
                    'finished_at'   => current_time('mysql', 1),
                    'error_message' => $mensajeRecuperacion,
                ],
                ['id' => (int) $filaHuerfana->id],
                ['%s', '%s', '%s'],
                ['%d']
            );
            // NO incrementamos el contador de errores consecutivos
            // de la fuente: el huérfano puede ser falso positivo (otro
            // worker PHP del cron previo aún vivo cuyo lock expiró), y
            // penalizar a la fuente con cuarentena por una incidencia
            // de infra es injusto. Si la fuente realmente falla, lo
            // hará en su próximo intento real con un error HTTP
            // legítimo y entrará en cuarentena por su propio mérito.
        }
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
        if ($previo > 0 && ($ahora - $previo) < Transients::LOCK_INGESTA_FEED) {
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

    /**
     * Devuelve true si la fuente está en cuarentena: tiene un
     * timestamp de "próximo intento" en el futuro tras haber
     * acumulado errores consecutivos. El meta se borra solo cuando
     * una ingesta posterior tiene éxito (ver `resetearContadorErrores`).
     */
    private static function estaEnCuarentena(int $idFuente): bool
    {
        $proximoIntentoTras = (int) get_post_meta($idFuente, self::META_PROXIMO_INTENTO_TRAS, true);
        return $proximoIntentoTras > 0 && $proximoIntentoTras > time();
    }

    /**
     * Suma uno al contador de errores consecutivos y, si supera los
     * umbrales, planta una fecha de "próximo intento" futura. Política
     * escalonada con jitter ±25% para evitar thundering herd cuando
     * docenas de fuentes caen en la misma ronda.
     */
    private static function registrarErrorYProgramarReintento(int $idFuente): void
    {
        $contadorActual = (int) get_post_meta($idFuente, self::META_ERRORES_CONSECUTIVOS, true);
        $contadorActual++;
        update_post_meta($idFuente, self::META_ERRORES_CONSECUTIVOS, $contadorActual);

        if ($contadorActual < self::UMBRAL_CUARENTENA_1H) {
            // Aún no merece cuarentena: borramos cualquier "próximo
            // intento" que pudiera haber quedado de un ciclo anterior.
            delete_post_meta($idFuente, self::META_PROXIMO_INTENTO_TRAS);
            return;
        }
        if ($contadorActual < self::UMBRAL_CUARENTENA_6H) {
            $cuarentenaSegBase = HOUR_IN_SECONDS;
        } elseif ($contadorActual < self::UMBRAL_CUARENTENA_24H) {
            $cuarentenaSegBase = 6 * HOUR_IN_SECONDS;
        } else {
            $cuarentenaSegBase = DAY_IN_SECONDS;
        }
        $factorJitter = random_int(75, 125) / 100;
        $cuarentenaSegFinal = (int) ($cuarentenaSegBase * $factorJitter);
        update_post_meta(
            $idFuente,
            self::META_PROXIMO_INTENTO_TRAS,
            time() + $cuarentenaSegFinal
        );
    }

    /**
     * Reset del breaker tras una ingesta exitosa (incluye 304: si el
     * origen responde "no hay cambios", la fuente está sana). Borra
     * tanto el contador como la fecha de próximo intento.
     */
    private static function resetearContadorErrores(int $idFuente): void
    {
        delete_post_meta($idFuente, self::META_ERRORES_CONSECUTIVOS);
        delete_post_meta($idFuente, self::META_PROXIMO_INTENTO_TRAS);
    }

    /**
     * Hace la petición HTTP del feed con cabeceras condicionales y
     * todas las cabeceras "de navegador real" que ya teníamos. La
     * llama `ingestarFuente` directamente — antes era SimplePie quien
     * hacía la petición vía `fetch_feed`.
     *
     * @return array{not_modified: true}
     *       | array{error: string}
     *       | array{body: string, etag: string, last_modified: string}
     */
    private static function fetchFeedHttp(int $idFuente, string $urlFeed, string $hostFeed): array
    {
        // Mismo UA y headers que ya enviábamos por el filtro
        // `http_request_args` de la versión anterior. Razones documentadas
        // en la rama eliminada: WP-default UA bloqueado por CEAR/NDTV;
        // "Bot" en UA bloqueado por Cloudflare; Sec-Fetch-* esperados por
        // WAFs heurísticos como Sucuri.
        $uaNavegador = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
        $cabeceras = [
            'From'           => 'flavor.gailu.it (Flavor News Hub agregator)',
            'Accept'         => 'application/rss+xml,application/atom+xml,application/xml;q=0.9,text/xml;q=0.8,*/*;q=0.5',
            'Accept-Language' => 'es,en;q=0.8',
            'Sec-Fetch-Dest' => 'document',
            'Sec-Fetch-Mode' => 'navigate',
            'Sec-Fetch-Site' => 'none',
        ];
        // Cabeceras condicionales: si las tenemos, las mandamos. El
        // origen responderá 304 si no hay cambios.
        $etagPrevio = (string) get_post_meta($idFuente, self::META_ETAG, true);
        $lastModPrevio = (string) get_post_meta($idFuente, self::META_LAST_MODIFIED, true);
        if ($etagPrevio !== '') {
            $cabeceras['If-None-Match'] = $etagPrevio;
        }
        if ($lastModPrevio !== '') {
            $cabeceras['If-Modified-Since'] = $lastModPrevio;
        }

        $bypassSsl = self::dominioRequiereBypassSsl($hostFeed);
        // Timeout corto (12s): orígenes lentos (Misión Verdad, España XR
        // Tube vía PeerTube) podían tardar >25s y empujar el cron por
        // encima de `max_execution_time`, dejando el log de la fuente en
        // `running` para siempre. Con 12s, ni siquiera dos fuentes lentas
        // seguidas alcanzan los 30s típicos del PHP-FPM. La fuente queda
        // marcada como error y entra en cuarentena progresiva.
        $timeoutFeed = (int) apply_filters('fnh_feed_http_timeout_seg', 8);
        $args = [
            'timeout'     => $timeoutFeed,
            'redirection' => 5,
            'user-agent'  => $uaNavegador,
            'sslverify'   => !$bypassSsl,
            'headers'     => $cabeceras,
        ];

        $respuesta = wp_remote_get($urlFeed, $args);
        if (is_wp_error($respuesta)) {
            return ['error' => $respuesta->get_error_message()];
        }

        $codigoHttp = (int) wp_remote_retrieve_response_code($respuesta);
        if ($codigoHttp === 304) {
            return ['not_modified' => true];
        }
        if ($codigoHttp >= 400 || $codigoHttp < 200) {
            return ['error' => sprintf(
                /* translators: %d = código HTTP */
                __('HTTP %d devuelto por el origen del feed.', 'flavor-news-hub'),
                $codigoHttp
            )];
        }

        $cuerpo = (string) wp_remote_retrieve_body($respuesta);
        if ($cuerpo === '') {
            return ['error' => __('El origen devolvió 200 pero con cuerpo vacío.', 'flavor-news-hub')];
        }

        return [
            'body'          => $cuerpo,
            'etag'          => (string) wp_remote_retrieve_header($respuesta, 'etag'),
            'last_modified' => (string) wp_remote_retrieve_header($respuesta, 'last-modified'),
        ];
    }
}
