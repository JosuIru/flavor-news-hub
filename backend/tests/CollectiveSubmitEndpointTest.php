<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\REST\CollectiveSubmitEndpoint;
use WP_REST_Request;
use WP_UnitTestCase;

/**
 * Verifica los tres caminos críticos de `POST /flavor-news/v1/collectives/submit`:
 *  - Alta válida → 202 Accepted + post pending con meta protegida.
 *  - Honeypot relleno → 400 invalid_submission, no crea nada.
 *  - Rate limit por IP: 3 aceptadas, 4ª rechazada con 429.
 */
final class CollectiveSubmitEndpointTest extends WP_UnitTestCase
{
    public function set_up(): void
    {
        parent::set_up();
        do_action('rest_api_init');
        self::resetearRateLimit();
        $_SERVER['REMOTE_ADDR'] = '203.0.113.7'; // IP de test, bloque reservado RFC 5737.
    }

    public function tear_down(): void
    {
        self::resetearRateLimit();
        parent::tear_down();
    }

    public function test_alta_valida_crea_pending_con_meta_protegida(): void
    {
        $respuesta = rest_do_request(self::construirPeticionValida());

        $this->assertSame(202, $respuesta->get_status());

        $datos = $respuesta->get_data();
        $this->assertTrue($datos['success']);
        $this->assertIsInt($datos['id']);
        $idCreado = (int) $datos['id'];

        $post = get_post($idCreado);
        $this->assertInstanceOf(\WP_Post::class, $post);
        $this->assertSame(Collective::SLUG, $post->post_type);
        $this->assertSame('pending', $post->post_status);

        $this->assertSame('test@ejemplo.org', (string) get_post_meta($idCreado, '_fnh_contact_email', true));
        $this->assertSame('test@ejemplo.org', (string) get_post_meta($idCreado, '_fnh_submitted_by_email', true));
        $this->assertSame('', (string) get_post_meta($idCreado, '_fnh_verified', true));
    }

    public function test_honeypot_relleno_devuelve_400_y_no_crea_nada(): void
    {
        $contadorPrevio = wp_count_posts(Collective::SLUG)->pending ?? 0;

        $peticion = self::construirPeticionValida();
        $peticion->set_param('website', 'https://bot.example/');

        $respuesta = rest_do_request($peticion);
        $this->assertSame(400, $respuesta->get_status());

        $contadorPosterior = wp_count_posts(Collective::SLUG)->pending ?? 0;
        $this->assertSame((int) $contadorPrevio, (int) $contadorPosterior, 'El honeypot no debe crear posts.');
    }

    public function test_rate_limit_rechaza_cuarta_peticion(): void
    {
        for ($iteracion = 1; $iteracion <= CollectiveSubmitEndpoint::MAX_ALTAS_POR_VENTANA; $iteracion++) {
            $respuesta = rest_do_request(self::construirPeticionValida('ok-' . $iteracion));
            $this->assertSame(202, $respuesta->get_status(), "Intento {$iteracion} debería aceptarse.");
        }

        $cuartoIntento = rest_do_request(self::construirPeticionValida('overflow'));
        $this->assertSame(429, $cuartoIntento->get_status());
        $datos = $cuartoIntento->get_data();
        $this->assertSame('rate_limited', $datos['error']);
    }

    private static function construirPeticionValida(string $sufijoNombre = ''): WP_REST_Request
    {
        $peticion = new WP_REST_Request('POST', '/flavor-news/v1/collectives/submit');
        $peticion->set_header('Content-Type', 'application/json');
        $peticion->set_body_params([
            'name'          => 'Colectivo de test ' . $sufijoNombre,
            'description'   => 'Descripción del colectivo de test.',
            'contact_email' => 'test@ejemplo.org',
            'territory'     => 'Bizkaia',
            'topics'        => ['vivienda'],
        ]);
        return $peticion;
    }

    private static function resetearRateLimit(): void
    {
        $ipActual = $_SERVER['REMOTE_ADDR'] ?? '203.0.113.7';
        $claveTransient = 'fnh_rl_' . CollectiveSubmitEndpoint::NOMBRE_ZONA_RATELIMIT . '_' . md5($ipActual);
        delete_transient($claveTransient);
    }
}
