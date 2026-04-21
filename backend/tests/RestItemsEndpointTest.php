<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Taxonomy\Topic;
use WP_REST_Request;
use WP_REST_Server;
use WP_UnitTestCase;

/**
 * Verifica el contrato mínimo de la API REST de lectura:
 *  - `GET /flavor-news/v1/items` devuelve 200 y un array paginado.
 *  - El orden es cronológico inverso según `_fnh_published_at`.
 *  - El filtro por topic se aplica correctamente.
 *  - La source embebida incluye los campos esperados en snake_case.
 */
final class RestItemsEndpointTest extends WP_UnitTestCase
{
    public function set_up(): void
    {
        parent::set_up();
        // Fuerza el registro de rutas si aún no están.
        do_action('rest_api_init');
    }

    public function test_get_items_devuelve_200_y_lista_ordenada_por_fecha_desc(): void
    {
        $idFuente = self::crearFuente('Medio de test');

        $idItemAntiguo = self::crearItem($idFuente, 'Noticia antigua', '2026-04-01T10:00:00+00:00');
        $idItemReciente = self::crearItem($idFuente, 'Noticia reciente', '2026-04-15T10:00:00+00:00');
        $idItemMedio = self::crearItem($idFuente, 'Noticia media', '2026-04-07T10:00:00+00:00');

        $request = new WP_REST_Request('GET', '/flavor-news/v1/items');
        $respuesta = rest_do_request($request);

        $this->assertSame(200, $respuesta->get_status());
        $datos = $respuesta->get_data();
        $this->assertIsArray($datos);
        $this->assertCount(3, $datos);

        $idsOrdenadosEsperados = [$idItemReciente, $idItemMedio, $idItemAntiguo];
        $idsOrdenadosObtenidos = array_map(static fn(array $item): int => (int) $item['id'], $datos);
        $this->assertSame($idsOrdenadosEsperados, $idsOrdenadosObtenidos);

        // Estructura de un item y de la source embebida.
        $primerItem = $datos[0];
        foreach (['id', 'slug', 'title', 'excerpt', 'url', 'original_url', 'published_at', 'media_url', 'source', 'topics'] as $clave) {
            $this->assertArrayHasKey($clave, $primerItem);
        }
        $this->assertIsArray($primerItem['source']);
        $this->assertSame($idFuente, (int) $primerItem['source']['id']);
        $this->assertSame('Medio de test', $primerItem['source']['name']);
    }

    public function test_get_items_filtra_por_topic(): void
    {
        $idFuente = self::crearFuente('Fuente topic test');

        $terminoVivienda = get_term_by('slug', 'vivienda', Topic::SLUG);
        $terminoInternacional = get_term_by('slug', 'internacional', Topic::SLUG);
        $this->assertInstanceOf(\WP_Term::class, $terminoVivienda);
        $this->assertInstanceOf(\WP_Term::class, $terminoInternacional);

        $idItemV1 = self::crearItem($idFuente, 'Vivienda uno', '2026-04-10T00:00:00+00:00');
        wp_set_object_terms($idItemV1, [(int) $terminoVivienda->term_id], Topic::SLUG);

        $idItemV2 = self::crearItem($idFuente, 'Vivienda dos', '2026-04-11T00:00:00+00:00');
        wp_set_object_terms($idItemV2, [(int) $terminoVivienda->term_id], Topic::SLUG);

        $idItemI = self::crearItem($idFuente, 'Internacional uno', '2026-04-12T00:00:00+00:00');
        wp_set_object_terms($idItemI, [(int) $terminoInternacional->term_id], Topic::SLUG);

        $request = new WP_REST_Request('GET', '/flavor-news/v1/items');
        $request->set_query_params(['topic' => 'vivienda']);
        $respuesta = rest_do_request($request);

        $this->assertSame(200, $respuesta->get_status());
        $datos = $respuesta->get_data();
        $this->assertCount(2, $datos);
        foreach ($datos as $item) {
            $slugsTopic = array_map(static fn(array $t): string => (string) $t['slug'], $item['topics']);
            $this->assertContains('vivienda', $slugsTopic);
        }
    }

    public function test_get_item_inexistente_devuelve_404(): void
    {
        $request = new WP_REST_Request('GET', '/flavor-news/v1/items/999999');
        $respuesta = rest_do_request($request);
        $this->assertSame(404, $respuesta->get_status());
    }

    private static function crearFuente(string $nombreMedio): int
    {
        $id = wp_insert_post([
            'post_type'   => Source::SLUG,
            'post_status' => 'publish',
            'post_title'  => $nombreMedio,
        ]);
        update_post_meta($id, '_fnh_active', true);
        update_post_meta($id, '_fnh_website_url', 'https://ejemplo.test');
        return (int) $id;
    }

    private static function crearItem(int $idFuente, string $titulo, string $fechaIso): int
    {
        $timestampUnix = strtotime($fechaIso);
        $fechaGmt = gmdate('Y-m-d H:i:s', $timestampUnix);
        $fechaLocal = get_date_from_gmt($fechaGmt);

        $id = wp_insert_post([
            'post_type'     => Item::SLUG,
            'post_status'   => 'publish',
            'post_title'    => $titulo,
            'post_content'  => 'Contenido de ' . $titulo,
            'post_date'     => $fechaLocal,
            'post_date_gmt' => $fechaGmt,
        ]);
        update_post_meta($id, '_fnh_source_id', $idFuente);
        update_post_meta($id, '_fnh_original_url', 'https://ejemplo.test/' . sanitize_title($titulo));
        update_post_meta($id, '_fnh_published_at', $fechaIso);
        update_post_meta($id, '_fnh_guid', 'guid-' . sanitize_title($titulo));
        return (int) $id;
    }
}
