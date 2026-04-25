<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\Admin\Pages\EstadisticasPage;
use WP_UnitTestCase;

/**
 * Verifica el fix del botón "Refrescar ya" de la pantalla de estadísticas
 * (v0.9.70). Antes hacía `wp_safe_redirect` tras `delete_transient` y, si
 * cualquier plugin/tema imprimía output antes, los headers ya estaban
 * enviados y la pantalla quedaba en blanco. Ahora refresca inline y
 * pinta un `notice-success`.
 *
 * Mockeamos la API de GitHub vía `pre_http_request` para no salir a
 * Internet desde el test.
 */
final class EstadisticasPageRefreshTest extends WP_UnitTestCase
{
    private const TRANSIENT = 'fnh_stats_descargas';

    public function set_up(): void
    {
        parent::set_up();
        // Usuario admin con `edit_posts`.
        $idAdmin = self::factory()->user->create(['role' => 'administrator']);
        wp_set_current_user($idAdmin);

        delete_transient(self::TRANSIENT);
        add_filter('pre_http_request', [$this, 'mockGithubRespuesta'], 10, 3);
    }

    public function tear_down(): void
    {
        remove_filter('pre_http_request', [$this, 'mockGithubRespuesta'], 10);
        delete_transient(self::TRANSIENT);
        unset($_GET['refrescar'], $_GET['_wpnonce'], $_REQUEST['_wpnonce']);
        parent::tear_down();
    }

    /**
     * @param false|array|\WP_Error $previa
     * @param array<string,mixed> $args
     * @return array<string,mixed>|false
     */
    public function mockGithubRespuesta($previa, array $args, string $url)
    {
        if (strpos($url, 'api.github.com') === false) {
            return $previa;
        }
        $cuerpoFalso = [[
            'tag_name' => 'v0.9.70',
            'assets'   => [[
                'name'           => 'flavor-news-hub-v0.9.70-app.apk',
                'download_count' => 5,
            ]],
        ]];
        return [
            'headers'  => ['content-type' => 'application/json'],
            'body'     => json_encode($cuerpoFalso),
            'response' => ['code' => 200, 'message' => 'OK'],
            'cookies'  => [],
            'filename' => null,
        ];
    }

    public function test_refrescar_borra_transient_y_pinta_notice_sin_redirect(): void
    {
        // Pre-cargamos el transient con datos viejos.
        set_transient(self::TRANSIENT, [
            'total_apk'      => 999,
            'total_zip'      => 999,
            'total_releases' => 999,
            'filas'          => [['tag' => 'viejo', 'nombre' => 'old.apk', 'descargas' => 999]],
            'ts_lectura'     => time() - 3600,
        ], HOUR_IN_SECONDS);
        $this->assertNotFalse(get_transient(self::TRANSIENT), 'Pre-condición: transient existe.');

        // Simulamos el click del botón "Refrescar ya".
        $_GET['refrescar'] = '1';
        $nonce = wp_create_nonce('fnh_stats_refrescar');
        $_GET['_wpnonce'] = $nonce;
        $_REQUEST['_wpnonce'] = $nonce;

        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        // El render debe haber pintado la página completa (no morir como
        // hacía antes el `wp_safe_redirect` con headers enviados).
        $this->assertStringContainsString('Estadísticas de descargas', $html);
        $this->assertStringContainsString('notice-success', $html, 'Debe pintar el aviso de refresco exitoso.');
        // Los datos visibles deben venir del mock (5), no del transient viejo (999).
        $this->assertStringContainsString('>5</div>', $html, 'El total de APKs debe venir del mock fresco.');
        $this->assertStringNotContainsString('>999</div>', $html, 'El total viejo del transient no debe aparecer.');
    }

    public function test_render_normal_sin_refrescar_no_pinta_notice(): void
    {
        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        $this->assertStringContainsString('Estadísticas de descargas', $html);
        $this->assertStringNotContainsString('notice-success', $html, 'Sin ?refrescar=1, no se pinta el notice.');
    }
}
