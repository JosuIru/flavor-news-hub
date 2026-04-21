<?php
/**
 * Bootstrap de PHPUnit para el plugin.
 *
 * Requiere que el entorno tenga preparada la test-lib de WordPress:
 *
 *   bin/install-wp-tests.sh <db_name> <db_user> <db_pass> <db_host> <wp_version>
 *
 * El script la descarga a `/tmp/wordpress-tests-lib/` y genera un wp-tests-config
 * apuntando a una base de datos de pruebas desechable. La variable de entorno
 * `WP_TESTS_DIR` permite apuntar a otra ubicación.
 */

declare(strict_types=1);

$rutaTestsLib = getenv('WP_TESTS_DIR');
if ($rutaTestsLib === false || $rutaTestsLib === '') {
    $rutaTestsLib = rtrim(sys_get_temp_dir(), '/\\') . '/wordpress-tests-lib';
}
$rutaTestsLib = rtrim($rutaTestsLib, '/\\');

if (!file_exists($rutaTestsLib . '/includes/functions.php')) {
    fwrite(
        STDERR,
        "No se encuentra la test-lib de WordPress en {$rutaTestsLib}.\n" .
        "Ejecuta primero: bin/install-wp-tests.sh <db> <user> <pass> <host> <version>\n"
    );
    exit(1);
}

// Polyfills Yoast para uniformar la API de PHPUnit entre versiones.
$polyfillAutoload = __DIR__ . '/../vendor/yoast/phpunit-polyfills/phpunitpolyfills-autoload.php';
if (file_exists($polyfillAutoload)) {
    require_once $polyfillAutoload;
}

require_once $rutaTestsLib . '/includes/functions.php';

/**
 * Cargamos el plugin justo antes de que WordPress inicie el ciclo de tests,
 * para que los hooks de `init`, `rest_api_init`, etc. queden registrados.
 */
tests_add_filter('muplugins_loaded', static function (): void {
    require dirname(__DIR__) . '/flavor-news-hub.php';
});

/**
 * Activamos el plugin programáticamente en cada test run para que el activator
 * cree la tabla de logs y precargue las temáticas.
 */
tests_add_filter('setup_theme', static function (): void {
    if (class_exists(\FlavorNewsHub\Activation\Activator::class)) {
        \FlavorNewsHub\Activation\Activator::activate();
    }
});

require $rutaTestsLib . '/includes/bootstrap.php';
