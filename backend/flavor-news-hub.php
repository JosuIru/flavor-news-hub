<?php
/**
 * Plugin Name:       Flavor News Hub
 * Plugin URI:        https://github.com/JosuIru/flavor-news-hub
 * Description:       Backend headless para agregar medios alternativos y listar colectivos organizados. CPTs, ingesta RSS, REST pública y admin de verificación. Complementario a Flavor Platform.
 * Version:           0.9.36
 * Requires at least: 6.4
 * Requires PHP:      8.1
 * Author:            Flavor News Hub contributors
 * License:           AGPL-3.0-or-later
 * License URI:       https://www.gnu.org/licenses/agpl-3.0.html
 * Text Domain:       flavor-news-hub
 * Domain Path:       /languages
 *
 * @package FlavorNewsHub
 */

declare(strict_types=1);

// Guardia contra acceso directo al archivo.
if (!defined('ABSPATH')) {
    exit;
}

// Constantes básicas del plugin, referenciadas por el resto de clases.
define('FNH_VERSION', '0.9.36');
define('FNH_PLUGIN_VERSION', FNH_VERSION);
define('FNH_PLUGIN_FILE', __FILE__);
define('FNH_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('FNH_PLUGIN_URL', plugin_dir_url(__FILE__));

/*
 * Autoloader PSR-4 manual. Evita una dependencia dura de `composer install`
 * en producción: el plugin es funcional recién descomprimido, sin build step.
 * Composer se usa sólo para dependencias de desarrollo (PHPUnit, polyfills).
 */
spl_autoload_register(static function (string $nombreClaseCompleto): void {
    $prefijoNamespace = 'FlavorNewsHub\\';
    $directorioBaseClases = FNH_PLUGIN_DIR . 'src/';
    $longitudPrefijo = strlen($prefijoNamespace);

    if (strncmp($prefijoNamespace, $nombreClaseCompleto, $longitudPrefijo) !== 0) {
        return;
    }

    $rutaRelativaClase = substr($nombreClaseCompleto, $longitudPrefijo);
    $rutaArchivoClase = $directorioBaseClases . str_replace('\\', '/', $rutaRelativaClase) . '.php';

    if (is_readable($rutaArchivoClase)) {
        require_once $rutaArchivoClase;
    }
});

// Hooks de ciclo de vida del plugin.
register_activation_hook(__FILE__, ['FlavorNewsHub\\Activation\\Activator', 'activate']);
register_deactivation_hook(__FILE__, ['FlavorNewsHub\\Activation\\Deactivator', 'deactivate']);

/*
 * Auto-update del plugin vía GitHub Releases, usando plugin-update-checker
 * (PUC). Con esto, WordPress muestra "Hay una actualización disponible"
 * en la pantalla de Plugins y la admin puede actualizar con un clic,
 * sin pasar por "Añadir nuevo → Subir zip".
 *
 * Cada release de GitHub debe llevar adjunto un zip del plugin (no el
 * zip auto-generado del repo, que incluye el monorepo entero): el
 * `enableReleaseAssets()` de abajo le dice a PUC que coja el primer
 * asset `.zip` de la release, no el código fuente.
 *
 * Cargamos PUC vía el autoloader de Composer (está en vendor/ por la
 * dep en composer.json). Si vendor/ no existe (dev con plugin sin
 * composer install), simplemente no se activa el checker — el plugin
 * funciona igual, sólo sin auto-update.
 */
if (is_readable(FNH_PLUGIN_DIR . 'vendor/autoload.php')) {
    require_once FNH_PLUGIN_DIR . 'vendor/autoload.php';
    $fnhUpdateChecker = \YahnisElsts\PluginUpdateChecker\v5\PucFactory::buildUpdateChecker(
        'https://github.com/JosuIru/flavor-news-hub',
        FNH_PLUGIN_FILE,
        'flavor-news-hub'
    );
    $fnhUpdateChecker->setBranch('main');
    // Filtramos por nombre: las releases llevan tanto el APK de la app
    // Flutter (`app-release.apk`) como el zip del plugin
    // (`flavor-news-hub-plugin-*.zip`). Si no especificamos nada, PUC
    // puede coger el primero que encuentre — y descargar el APK
    // creyéndolo un plugin provoca "No se ha podido descomprimir".
    $fnhUpdateChecker->getVcsApi()->enableReleaseAssets('/flavor-news-hub-plugin-.*\.zip$/i');
}

// Arranque tras cargar todos los plugins, para que las traducciones y otros
// plugins estén disponibles si hiciera falta.
add_action('plugins_loaded', static function (): void {
    \FlavorNewsHub\Plugin::instancia()->arrancar();
});
