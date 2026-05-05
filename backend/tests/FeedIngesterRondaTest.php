<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\Activation\Activator;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\FeedIngester;
use WP_UnitTestCase;
use WP_Error;

/**
 * Tests de la ronda completa (`ingestarTodasLasFuentesActivas`).
 *
 * `FeedIngesterTest` cubre el flujo de una sola fuente. Esta suite
 * cubre el bucle de la ronda — el camino donde se nos coló en
 * producción el bug del SimplePie no precargado: el test de fuente
 * individual pasaba en CI pero la ronda real moría en wp-cron porque
 * la clase no estaba autoloaded en ese contexto. Si esos casos
 * hubieran existido aquí, la regresión se habría detectado antes
 * del deploy.
 */
final class FeedIngesterRondaTest extends WP_UnitTestCase
{
    public function set_up(): void
    {
        parent::set_up();
        Activator::precargarTematicasCanonicas();

        // Throttle desactivado en tests: con varias fuentes en la ronda
        // no queremos esperar 1.5s entre llamadas a hosts mock.
        add_filter('fnh_intervalo_minimo_host_microseg', '__return_zero');

        add_filter('pre_http_request', [$this, 'interceptarHttp'], 10, 3);
    }

    public function tear_down(): void
    {
        remove_filter('pre_http_request', [$this, 'interceptarHttp'], 10);
        remove_all_filters('fnh_max_seg_por_ronda');
        parent::tear_down();
    }

    /**
     * Mapa URL → comportamiento para el mock HTTP. Cada test poblará
     * este array con las URLs que usa.
     *
     * @var array<string, array{type:string, status?:int, body?:string}>
     */
    private array $rutasMock = [];

    /**
     * @param false|array|WP_Error $respuestaPrevia
     * @param array<string,mixed> $argumentosHttp
     * @param string $urlSolicitada
     * @return false|array<string,mixed>|WP_Error
     */
    public function interceptarHttp($respuestaPrevia, array $argumentosHttp, string $urlSolicitada)
    {
        if (!isset($this->rutasMock[$urlSolicitada])) {
            return $respuestaPrevia;
        }
        $config = $this->rutasMock[$urlSolicitada];

        if ($config['type'] === 'wp_error') {
            return new WP_Error('http_request_failed', 'cURL error 28: timeout simulado');
        }
        if ($config['type'] === 'not_modified') {
            return [
                'headers'  => [],
                'body'     => '',
                'response' => ['code' => 304, 'message' => 'Not Modified'],
                'cookies'  => [],
                'filename' => null,
            ];
        }
        if ($config['type'] === 'http_error') {
            $codigo = (int) ($config['status'] ?? 500);
            return [
                'headers'  => [],
                'body'     => '',
                'response' => ['code' => $codigo, 'message' => 'Error simulado'],
                'cookies'  => [],
                'filename' => null,
            ];
        }
        // ok: 200 con body XML
        return [
            'headers'  => ['content-type' => 'application/rss+xml; charset=utf-8'],
            'body'     => (string) ($config['body'] ?? ''),
            'response' => ['code' => 200, 'message' => 'OK'],
            'cookies'  => [],
            'filename' => null,
        ];
    }

    public function test_ronda_con_3_fuentes_mock_inserta_items_de_todas(): void
    {
        $idFuenteA = self::crearFuenteActiva('https://example.test/feed-a.xml');
        $idFuenteB = self::crearFuenteActiva('https://example.test/feed-b.xml');
        $idFuenteC = self::crearFuenteActiva('https://example.test/feed-c.xml');

        $this->rutasMock = [
            'https://example.test/feed-a.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('a')],
            'https://example.test/feed-b.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('b')],
            'https://example.test/feed-c.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('c')],
        ];

        $resumen = FeedIngester::ingestarTodasLasFuentesActivas();

        $this->assertSame(3, $resumen['sources_processed'], 'La ronda debe procesar las 3 fuentes.');
        $this->assertSame(9, $resumen['items_new_total'], 'Cada fixture aporta 3 items, 3×3=9.');
        $this->assertSame(0, $resumen['items_skipped_total']);
        $this->assertSame([], $resumen['errors']);

        $itemsTotales = (new \WP_Query([
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
        ]))->found_posts;
        $this->assertSame(9, (int) $itemsTotales);

        // Cada fuente debe tener exactamente 3 items asociados — sin
        // contaminación cruzada por GUIDs o permalinks.
        foreach ([$idFuenteA, $idFuenteB, $idFuenteC] as $idFuente) {
            $itemsDeFuente = get_posts([
                'post_type'      => Item::SLUG,
                'posts_per_page' => -1,
                'meta_query'     => [['key' => '_fnh_source_id', 'value' => $idFuente]],
            ]);
            $this->assertCount(3, $itemsDeFuente, "La fuente {$idFuente} debe tener 3 items propios.");
        }
    }

    public function test_ronda_marca_fuente_en_cuarentena_tras_5_errores_consecutivos(): void
    {
        $idFuente = self::crearFuenteActiva('https://example.test/feed-roto.xml');
        $this->rutasMock = [
            'https://example.test/feed-roto.xml' => ['type' => 'wp_error'],
        ];

        // 5 rondas con la misma fuente fallando: cada ronda incrementa
        // META_ERRORES_CONSECUTIVOS hasta llegar al UMBRAL_CUARENTENA_1H (5).
        for ($i = 0; $i < 5; $i++) {
            FeedIngester::ingestarTodasLasFuentesActivas();
        }

        $contadorErrores = (int) get_post_meta($idFuente, FeedIngester::META_ERRORES_CONSECUTIVOS, true);
        $proximoIntentoTras = (int) get_post_meta($idFuente, FeedIngester::META_PROXIMO_INTENTO_TRAS, true);

        $this->assertSame(5, $contadorErrores, 'El contador debe estar en 5 tras 5 fallos consecutivos.');
        $this->assertGreaterThan(time(), $proximoIntentoTras, 'La fuente debe estar en cuarentena (próximo intento futuro).');

        // En la sexta ronda la fuente está en cuarentena: el bucle de
        // la ronda sí cuenta `sources_processed++`, pero
        // `estaEnCuarentena` cortocircuita ANTES de `crearLogInicial`.
        // Verificamos por la tabla de logs: tras la sexta ronda no
        // debe haber filas nuevas de esta fuente.
        global $wpdb;
        $tablaLogs = IngestLogTable::nombreCompleto();
        $logsAntes = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$tablaLogs} WHERE source_id = %d",
            $idFuente
        ));
        FeedIngester::ingestarTodasLasFuentesActivas();
        $logsDespues = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM {$tablaLogs} WHERE source_id = %d",
            $idFuente
        ));
        $this->assertSame($logsAntes, $logsDespues, 'La fuente cuarentenada no debe generar nuevo log en la siguiente ronda.');
    }

    public function test_ronda_corta_por_max_seg_por_ronda_y_reporta_budget_exceeded(): void
    {
        self::crearFuenteActiva('https://example.test/feed-presupuesto-1.xml');
        self::crearFuenteActiva('https://example.test/feed-presupuesto-2.xml');
        self::crearFuenteActiva('https://example.test/feed-presupuesto-3.xml');

        $this->rutasMock = [
            'https://example.test/feed-presupuesto-1.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('p1')],
            'https://example.test/feed-presupuesto-2.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('p2')],
            'https://example.test/feed-presupuesto-3.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('p3')],
        ];

        // Budget a 0s: el bucle revisa el tiempo ANTES de procesar cada
        // fuente; con 0s nunca entra al cuerpo y todas quedan
        // pendientes para la próxima ronda.
        add_filter('fnh_max_seg_por_ronda', static fn() => 0);

        $resumen = FeedIngester::ingestarTodasLasFuentesActivas();

        $this->assertSame(0, $resumen['sources_processed']);
        $this->assertArrayHasKey('budget_exceeded', $resumen);
        $this->assertTrue($resumen['budget_exceeded']);
        $this->assertSame(3, $resumen['sources_skipped']);
    }

    public function test_ronda_ordena_fuentes_por_ultima_ingesta_ascendente(): void
    {
        global $wpdb;

        $idFuenteVieja   = self::crearFuenteActiva('https://example.test/feed-vieja.xml');
        $idFuenteReciente = self::crearFuenteActiva('https://example.test/feed-reciente.xml');
        $idFuenteNueva   = self::crearFuenteActiva('https://example.test/feed-nueva.xml');

        // Inyectamos historial sintético en la tabla de logs para
        // forzar el orden esperado en `obtenerIdsFuentesActivas`:
        //   - VIEJA: ingestada hace mucho → debe ir primera
        //   - RECIENTE: ingestada hace poco → segunda
        //   - NUEVA: sin historial → última (NULL ASC va al final
        //     gracias al `IS NULL DESC` invertido del SQL)
        $tablaLogs = IngestLogTable::nombreCompleto();
        $wpdb->insert($tablaLogs, [
            'source_id'    => $idFuenteVieja,
            'started_at'   => gmdate('Y-m-d H:i:s', time() - 7200),
            'finished_at'  => gmdate('Y-m-d H:i:s', time() - 7195),
            'status'       => 'success',
            'items_new'    => 0,
            'items_skipped'=> 0,
        ]);
        $wpdb->insert($tablaLogs, [
            'source_id'    => $idFuenteReciente,
            'started_at'   => gmdate('Y-m-d H:i:s', time() - 600),
            'finished_at'  => gmdate('Y-m-d H:i:s', time() - 595),
            'status'       => 'success',
            'items_new'    => 0,
            'items_skipped'=> 0,
        ]);

        $this->rutasMock = [
            'https://example.test/feed-vieja.xml'   => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('vja')],
            'https://example.test/feed-reciente.xml'=> ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('rec')],
            'https://example.test/feed-nueva.xml'   => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('nva')],
        ];

        FeedIngester::ingestarTodasLasFuentesActivas();

        // Recuperamos la secuencia de logs creados POR esta ronda
        // (los del setup tienen finished_at en el pasado lejano; los
        // de la ronda son de los últimos segundos). Ordenamos por
        // started_at ASC porque eso refleja el orden real de
        // procesamiento.
        $secuenciaIds = $wpdb->get_col(
            "SELECT source_id FROM {$tablaLogs}
             WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 60 SECOND)
             ORDER BY started_at ASC, id ASC"
        );
        $secuenciaIds = array_map('intval', $secuenciaIds);

        // El orden esperado: NULL (NUEVA) primero, luego VIEJA, luego RECIENTE.
        // El SQL usa `lst.ultimo IS NULL DESC, lst.ultimo ASC` — fuentes
        // sin historial van DELANTE para que estrenen ronda; entre las
        // que tienen historial, la más antigua va antes que la reciente.
        $this->assertSame(
            [$idFuenteNueva, $idFuenteVieja, $idFuenteReciente],
            $secuenciaIds,
            'La ronda debe procesar las fuentes en orden: sin-historial → ASC por última ingesta.'
        );
    }

    public function test_fuente_marcada_degraded_va_al_final_del_orden(): void
    {
        global $wpdb;

        // Tres fuentes, todas con historial similar (sin diferenciar por
        // antigüedad de ingesta), pero una está marcada como degraded:
        // debe procesarse la última aunque por antigüedad de ingesta
        // empataría con las otras dos.
        $idRapidaA = self::crearFuenteActiva('https://example.test/feed-rap-a.xml');
        $idLenta   = self::crearFuenteActiva('https://example.test/feed-lenta.xml');
        $idRapidaB = self::crearFuenteActiva('https://example.test/feed-rap-b.xml');

        update_post_meta($idLenta, FeedIngester::META_DEGRADED, '1');

        $tablaLogs = IngestLogTable::nombreCompleto();
        // Para que las tres tengan misma "última ingesta" (no nula),
        // inyectamos un log antiguo y con timestamp idéntico para las tres.
        $tsBase = gmdate('Y-m-d H:i:s', time() - 600);
        foreach ([$idRapidaA, $idLenta, $idRapidaB] as $id) {
            $wpdb->insert($tablaLogs, [
                'source_id'    => $id,
                'started_at'   => $tsBase,
                'finished_at'  => $tsBase,
                'status'       => 'success',
                'items_new'    => 0,
                'items_skipped'=> 0,
            ]);
        }

        $this->rutasMock = [
            'https://example.test/feed-rap-a.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('rapa')],
            'https://example.test/feed-lenta.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('lent')],
            'https://example.test/feed-rap-b.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('rapb')],
        ];

        FeedIngester::ingestarTodasLasFuentesActivas();

        // Logs creados por esta ronda (los del setup tienen timestamp
        // 10 min en el pasado).
        $secuencia = $wpdb->get_col(
            "SELECT source_id FROM {$tablaLogs}
             WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 60 SECOND)
             ORDER BY started_at ASC, id ASC"
        );
        $secuencia = array_map('intval', $secuencia);

        $this->assertCount(3, $secuencia);
        $this->assertSame($idLenta, end($secuencia), 'La fuente degraded debe procesarse la ÚLTIMA en la ronda.');
    }

    public function test_actualiza_latencia_ewma_y_marca_degraded_tras_ingesta(): void
    {
        $idFuente = self::crearFuenteActiva('https://example.test/feed-ewma.xml');
        $this->rutasMock = [
            'https://example.test/feed-ewma.xml' => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('ewma')],
        ];

        // Tras una ingesta normal, la EWMA debe haberse poblado con
        // algún valor > 0 y la fuente NO debe estar degraded.
        FeedIngester::ingestarTodasLasFuentesActivas();
        $latencia = (int) get_post_meta($idFuente, FeedIngester::META_LATENCIA_EWMA_MS, true);
        $this->assertGreaterThan(0, $latencia, 'La EWMA debe haberse persistido con un valor positivo.');
        $degraded = (string) get_post_meta($idFuente, FeedIngester::META_DEGRADED, true);
        $this->assertSame('', $degraded, 'Una fuente rápida con mock instantáneo no debe marcarse degraded.');

        // Forzamos la transición a degraded simulando una latencia
        // previa alta (cerca del umbral): tras la siguiente ingesta
        // la EWMA debería seguir alta y marcar degraded. Como no
        // podemos sleep en tests, simulamos directamente el meta.
        update_post_meta($idFuente, FeedIngester::META_LATENCIA_EWMA_MS, 9000);

        // Reseteamos el throttle del host (`$ultimoRequestPorHost` es
        // estático). Una segunda ingesta sobre el mismo mock debe
        // recalcular EWMA: 9000ms previo + ~poca latencia actual, con
        // alfa=0.3 → ~9000*0.7 + ~latencia_real*0.3 ≈ 6300+, sigue
        // por encima del umbral (6000), así que se marca degraded.
        FeedIngester::ingestarTodasLasFuentesActivas();
        $degradedTras = (string) get_post_meta($idFuente, FeedIngester::META_DEGRADED, true);
        $this->assertSame('1', $degradedTras, 'Con EWMA previo alto la fuente debe quedar marcada degraded.');
    }

    public function test_http_status_se_persiste_en_log_segun_respuesta_del_origen(): void
    {
        global $wpdb;
        $tablaLogs = IngestLogTable::nombreCompleto();

        $idFuente200 = self::crearFuenteActiva('https://example.test/feed-200.xml');
        $idFuente304 = self::crearFuenteActiva('https://example.test/feed-304b.xml');
        $idFuente500 = self::crearFuenteActiva('https://example.test/feed-500.xml');
        $idFuenteTimeout = self::crearFuenteActiva('https://example.test/feed-timeout.xml');

        $this->rutasMock = [
            'https://example.test/feed-200.xml'    => ['type' => 'ok', 'body' => self::cuerpoFeedConSufijo('h200')],
            'https://example.test/feed-304b.xml'   => ['type' => 'not_modified'],
            'https://example.test/feed-500.xml'    => ['type' => 'http_error', 'status' => 500],
            'https://example.test/feed-timeout.xml'=> ['type' => 'wp_error'],
        ];

        FeedIngester::ingestarTodasLasFuentesActivas();

        $codigoPorFuente = static function (int $idFuente) use ($wpdb, $tablaLogs): int {
            $val = $wpdb->get_var($wpdb->prepare(
                "SELECT http_status FROM {$tablaLogs}
                 WHERE source_id = %d AND finished_at IS NOT NULL
                 ORDER BY started_at DESC LIMIT 1",
                $idFuente
            ));
            return (int) $val;
        };

        $this->assertSame(200, $codigoPorFuente($idFuente200), 'Una respuesta 200 debe persistir 200 en http_status.');
        $this->assertSame(304, $codigoPorFuente($idFuente304), 'Una respuesta 304 debe persistir 304 en http_status.');
        $this->assertSame(500, $codigoPorFuente($idFuente500), 'Una respuesta 500 debe persistir 500 en http_status.');
        $this->assertSame(0,   $codigoPorFuente($idFuenteTimeout), 'Un timeout/WP_Error sin respuesta HTTP debe persistir 0.');
    }

    public function test_304_resetea_breaker_y_no_crea_items(): void
    {
        $idFuente = self::crearFuenteActiva('https://example.test/feed-304.xml');

        // Estado previo: la fuente venía con 3 errores acumulados de
        // rondas anteriores. Un 304 (origen sano que dice "sin cambios")
        // debe limpiar el contador — esa es la semántica documentada de
        // `resetearContadorErrores` en `FeedIngester::ingestarFuente`.
        update_post_meta($idFuente, FeedIngester::META_ERRORES_CONSECUTIVOS, 3);

        $this->rutasMock = [
            'https://example.test/feed-304.xml' => ['type' => 'not_modified'],
        ];

        $resumen = FeedIngester::ingestarTodasLasFuentesActivas();

        $this->assertSame(1, $resumen['sources_processed']);
        $this->assertSame(0, $resumen['items_new_total'], 'Un 304 no debe crear items.');
        $this->assertSame([], $resumen['errors'], 'Un 304 cierra como success, no como error.');

        $contadorPosterior = get_post_meta($idFuente, FeedIngester::META_ERRORES_CONSECUTIVOS, true);
        $this->assertSame('', $contadorPosterior, 'El 304 debe haber borrado el contador de errores previo.');
    }

    private static function crearFuenteActiva(string $urlFeed): int
    {
        $idFuente = wp_insert_post([
            'post_type'    => Source::SLUG,
            'post_status'  => 'publish',
            'post_title'   => 'Fuente test ' . md5($urlFeed),
            'post_content' => '',
        ]);
        update_post_meta($idFuente, '_fnh_feed_url', $urlFeed);
        update_post_meta($idFuente, '_fnh_feed_type', 'rss');
        update_post_meta($idFuente, '_fnh_active', true);
        return (int) $idFuente;
    }

    /**
     * Genera un cuerpo de feed RSS basado en el fixture compartido,
     * sustituyendo GUIDs y permalinks para que cada fuente del test
     * tenga items distintos y no se solapen vía dedupe global.
     */
    private static function cuerpoFeedConSufijo(string $sufijo): string
    {
        $base = (string) file_get_contents(__DIR__ . '/fixtures/sample-feed.xml');
        return str_replace(
            [
                'fnh-fixture-guid-001',
                'fnh-fixture-guid-002',
                'fnh-fixture-guid-003',
                'https://example.test/articulo-uno',
                'https://example.test/articulo-dos',
                'https://example.test/articulo-tres',
            ],
            [
                "fnh-{$sufijo}-001",
                "fnh-{$sufijo}-002",
                "fnh-{$sufijo}-003",
                "https://example.test/{$sufijo}/articulo-uno",
                "https://example.test/{$sufijo}/articulo-dos",
                "https://example.test/{$sufijo}/articulo-tres",
            ],
            $base
        );
    }
}
