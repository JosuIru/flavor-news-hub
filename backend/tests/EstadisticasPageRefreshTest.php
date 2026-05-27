<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\Admin\Pages\EstadisticasPage;
use WP_UnitTestCase;

/**
 * Verifica dos aspectos de la pantalla de estadísticas:
 *
 *  1. El fix del botón "Refrescar ya" (v0.9.70): antes hacía
 *     `wp_safe_redirect` y, si algo imprimía output antes, la pantalla
 *     quedaba en blanco. Ahora refresca inline (síncrono) y pinta un
 *     `notice-success`.
 *  2. El render no bloqueante: la carga normal nunca espera a
 *     api.github.com. Sirve el caché si existe y, en frío, pinta el
 *     estado "calculando" y encola el refresco en segundo plano.
 *
 * Mockeamos la API de GitHub vía `pre_http_request` para no salir a
 * Internet desde el test y, de paso, contar cuántas veces el render
 * habría pegado a GitHub.
 */
final class EstadisticasPageRefreshTest extends WP_UnitTestCase
{
    private const TRANSIENT = 'fnh_stats_descargas';
    private const OPTION_HISTORICO = 'fnh_descargas_historico';

    /** Nº de peticiones a api.github.com interceptadas en el test actual. */
    private int $llamadasGithub = 0;

    public function set_up(): void
    {
        parent::set_up();
        // Usuario admin con `edit_posts`.
        $idAdmin = self::factory()->user->create(['role' => 'administrator']);
        wp_set_current_user($idAdmin);

        $this->llamadasGithub = 0;
        delete_transient(self::TRANSIENT);
        delete_option(self::OPTION_HISTORICO);
        wp_clear_scheduled_hook(EstadisticasPage::HOOK_REFRESCO_BG);
        add_filter('pre_http_request', [$this, 'mockGithubRespuesta'], 10, 3);
    }

    public function tear_down(): void
    {
        remove_filter('pre_http_request', [$this, 'mockGithubRespuesta'], 10);
        delete_transient(self::TRANSIENT);
        delete_option(self::OPTION_HISTORICO);
        wp_clear_scheduled_hook(EstadisticasPage::HOOK_REFRESCO_BG);
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
        $this->llamadasGithub++;
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
        // Pre-cargamos el caché para que la carga normal sirva datos y no
        // entre en el estado "calculando".
        set_transient(self::TRANSIENT, [
            'total_apk'      => 1,
            'total_zip'      => 0,
            'total_releases' => 1,
            'filas'          => [['tag' => 'v1', 'nombre' => 'x.apk', 'descargas' => 1]],
            'ts_lectura'     => time(),
        ], HOUR_IN_SECONDS);

        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        $this->assertStringContainsString('Estadísticas de descargas', $html);
        $this->assertStringNotContainsString('notice-success', $html, 'Sin ?refrescar=1, no se pinta el notice.');
    }

    /**
     * Carga normal con el caché frío: el render NO debe bloquear contra
     * api.github.com. Muestra el estado "calculando" y encola el evento
     * WP-Cron one-off que rehace el bundle en segundo plano.
     */
    public function test_carga_normal_cache_frio_no_bloquea_y_programa_refresco(): void
    {
        // set_up ya borró el transient: estamos en frío.
        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        $this->assertSame(0, $this->llamadasGithub, 'El render en frío no debe pegarse a GitHub.');
        $this->assertStringContainsString('Calculando las descargas', $html, 'Debe pintar el estado "calculando".');
        $this->assertNotFalse(
            wp_next_scheduled(EstadisticasPage::HOOK_REFRESCO_BG),
            'Debe encolarse el refresco en segundo plano.'
        );
    }

    /**
     * Carga normal con el caché caliente: sirve el transient tal cual,
     * sin ninguna petición a GitHub.
     */
    public function test_carga_normal_cache_caliente_sirve_sin_http(): void
    {
        set_transient(self::TRANSIENT, [
            'total_apk'      => 42,
            'total_zip'      => 7,
            'total_releases' => 3,
            'filas'          => [['tag' => 'v1', 'nombre' => 'x.apk', 'descargas' => 42]],
            'ts_lectura'     => time(),
        ], HOUR_IN_SECONDS);

        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        $this->assertSame(0, $this->llamadasGithub, 'Con caché caliente no se llama a GitHub.');
        $this->assertStringContainsString('>42</div>', $html, 'Debe pintar el total cacheado.');
        $this->assertStringNotContainsString('Calculando las descargas', $html);
    }

    /**
     * El refresco registra un snapshot del acumulado CRUDO del día (el
     * mock devuelve un APK con download_count=5), base de la serie diaria.
     */
    public function test_refrescar_registra_snapshot_diario_crudo(): void
    {
        $_GET['refrescar'] = '1';
        $nonce = wp_create_nonce('fnh_stats_refrescar');
        $_GET['_wpnonce'] = $nonce;
        $_REQUEST['_wpnonce'] = $nonce;

        ob_start();
        EstadisticasPage::render();
        ob_get_clean();

        $historico = get_option(self::OPTION_HISTORICO);
        $hoy = current_time('Y-m-d');
        $this->assertIsArray($historico);
        $this->assertArrayHasKey($hoy, $historico, 'Debe guardarse el snapshot del día actual.');
        $this->assertSame(5, $historico[$hoy]['apk'], 'Guarda el acumulado crudo de APK del mock.');
        $this->assertSame(0, $historico[$hoy]['zip']);
    }

    /**
     * La sección "Descargas por día" deriva los deltas entre snapshots
     * acumulados y omite el primer día (sin referencia previa).
     */
    public function test_seccion_por_dia_pinta_deltas_y_omite_primer_dia(): void
    {
        update_option(self::OPTION_HISTORICO, [
            '2026-05-20' => ['apk' => 100, 'zip' => 10], // primer día: sin delta
            '2026-05-21' => ['apk' => 108, 'zip' => 12], // delta total = 8 + 2 = 10
            '2026-05-22' => ['apk' => 111, 'zip' => 14], // delta total = 3 + 2 = 5
        ], false);
        // Caché caliente para entrar en la rama de datos (donde se pinta
        // la sección por día) sin pegar a GitHub.
        set_transient(self::TRANSIENT, [
            'total_apk'      => 1,
            'total_zip'      => 0,
            'total_releases' => 1,
            'filas'          => [['tag' => 'v1', 'nombre' => 'x.apk', 'descargas' => 1]],
            'ts_lectura'     => time(),
        ], HOUR_IN_SECONDS);

        ob_start();
        EstadisticasPage::render();
        $html = (string) ob_get_clean();

        $this->assertStringContainsString('Descargas por día', $html);
        $this->assertStringContainsString('2026-05-22', $html);
        $this->assertStringContainsString('2026-05-21', $html);
        $this->assertStringNotContainsString('2026-05-20', $html, 'El primer día no tiene delta y no se lista.');
        // Totales diarios en la celda <strong>: 10 (día 21) y 5 (día 22).
        $this->assertStringContainsString('<strong>10</strong>', $html);
        $this->assertStringContainsString('<strong>5</strong>', $html);
    }
}
