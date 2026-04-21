<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\Activation\Activator;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Ingest\FeedIngester;
use WP_UnitTestCase;
use WP_Error;

/**
 * Verifica el dedupe del ingester: la misma fuente ingestada dos veces no
 * genera items duplicados y la segunda ejecución los marca como descartados.
 *
 * Para no depender de la red, hookeamos `pre_http_request` y devolvemos el
 * contenido de un fixture RSS local. SimplePie en WordPress usa `WP_Http`
 * por debajo, así que este filter intercepta la descarga.
 */
final class FeedIngesterTest extends WP_UnitTestCase
{
    private const URL_FEED_FIXTURE = 'https://example.test/feed.xml';

    public function set_up(): void
    {
        parent::set_up();
        // WP_UnitTestCase revierte la base entre tests, así que las temáticas
        // precargadas en activación se pierden. Las reinsertamos aquí.
        Activator::precargarTematicasCanonicas();
        // Limpiar cualquier caché de SimplePie entre tests.
        delete_transient('feed_' . md5(self::URL_FEED_FIXTURE));
        delete_transient('feed_mod_' . md5(self::URL_FEED_FIXTURE));

        add_filter('pre_http_request', [$this, 'interceptarHttp'], 10, 3);
    }

    public function tear_down(): void
    {
        remove_filter('pre_http_request', [$this, 'interceptarHttp'], 10);
        parent::tear_down();
    }

    /**
     * @param false|array|WP_Error $respuestaPrevia
     * @param array<string,mixed> $argumentosHttp
     * @param string $urlSolicitada
     * @return false|array<string,mixed>
     */
    public function interceptarHttp($respuestaPrevia, array $argumentosHttp, string $urlSolicitada)
    {
        if ($urlSolicitada !== self::URL_FEED_FIXTURE) {
            return $respuestaPrevia;
        }
        $rutaFixture = __DIR__ . '/fixtures/sample-feed.xml';
        return [
            'headers'  => ['content-type' => 'application/rss+xml; charset=utf-8'],
            'body'     => (string) file_get_contents($rutaFixture),
            'response' => ['code' => 200, 'message' => 'OK'],
            'cookies'  => [],
            'filename' => null,
        ];
    }

    public function test_ingesta_crea_items_con_meta_y_hereda_topics(): void
    {
        $idFuente = self::crearFuenteActiva(self::URL_FEED_FIXTURE, ['internacional']);

        $resumen = FeedIngester::ingestarFuente($idFuente);

        $this->assertSame('', $resumen['error'], 'La ingesta no debería producir error.');
        $this->assertSame(3, $resumen['items_new'], 'El fixture tiene 3 items.');
        $this->assertSame(0, $resumen['items_skipped']);

        $itemsCreados = get_posts([
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
        ]);
        $this->assertCount(3, $itemsCreados);

        $primerItem = $itemsCreados[0];
        $this->assertSame($idFuente, (int) get_post_meta($primerItem->ID, '_fnh_source_id', true));
        $this->assertNotSame('', get_post_meta($primerItem->ID, '_fnh_guid', true));
        $this->assertStringStartsWith('https://example.test/articulo-', (string) get_post_meta($primerItem->ID, '_fnh_original_url', true));
        $this->assertNotSame('', get_post_meta($primerItem->ID, '_fnh_published_at', true));

        // El topic del source se hereda a cada item ingestado.
        $topicsItem = wp_get_object_terms($primerItem->ID, Topic::SLUG, ['fields' => 'slugs']);
        $this->assertContains('internacional', $topicsItem);
    }

    public function test_ingesta_repetida_no_duplica_y_descarta_por_dedupe(): void
    {
        $idFuente = self::crearFuenteActiva(self::URL_FEED_FIXTURE, ['vivienda']);

        $primerPase = FeedIngester::ingestarFuente($idFuente);
        $this->assertSame(3, $primerPase['items_new']);

        // Invalida caché de SimplePie para forzar segunda descarga.
        delete_transient('feed_' . md5(self::URL_FEED_FIXTURE));
        delete_transient('feed_mod_' . md5(self::URL_FEED_FIXTURE));

        $segundoPase = FeedIngester::ingestarFuente($idFuente);
        $this->assertSame(0, $segundoPase['items_new'], 'La segunda ingesta no debe crear items.');
        $this->assertSame(3, $segundoPase['items_skipped'], 'Los 3 items del fixture deben quedar descartados por dedupe.');

        $totalItems = (new \WP_Query([
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => false,
        ]))->found_posts;
        $this->assertSame(3, (int) $totalItems, 'Sólo debe haber 3 items en BD tras dos ingestas.');
    }

    /**
     * @param list<string> $slugsTopic
     */
    private static function crearFuenteActiva(string $urlFeed, array $slugsTopic): int
    {
        $idFuente = wp_insert_post([
            'post_type'    => Source::SLUG,
            'post_status'  => 'publish',
            'post_title'   => 'Fuente de test',
            'post_content' => '',
        ]);
        update_post_meta($idFuente, '_fnh_feed_url', $urlFeed);
        update_post_meta($idFuente, '_fnh_feed_type', 'rss');
        update_post_meta($idFuente, '_fnh_active', true);

        if (!empty($slugsTopic)) {
            $idsTopic = [];
            foreach ($slugsTopic as $slug) {
                $termino = get_term_by('slug', $slug, Topic::SLUG);
                if ($termino instanceof \WP_Term) {
                    $idsTopic[] = (int) $termino->term_id;
                }
            }
            if (!empty($idsTopic)) {
                wp_set_object_terms($idFuente, $idsTopic, Topic::SLUG, false);
            }
        }
        return (int) $idFuente;
    }
}
