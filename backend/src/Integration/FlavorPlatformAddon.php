<?php
declare(strict_types=1);

namespace FlavorNewsHub\Integration;

use FlavorNewsHub\Admin\Menu;

/**
 * Integración opcional con Flavor Platform.
 *
 * Si el plugin "Flavor Platform" está activo en la misma instalación,
 * registramos `flavor-news-hub` como uno de sus addons para que aparezca
 * en su dashboard unificado y herede la shell de admin (cabecera, estilo,
 * navegación de módulos). Si no está activo, ESTE ARCHIVO NO HACE NADA —
 * el plugin sigue funcionando en modo standalone con su propio menú en
 * el sidebar estándar de WP.
 *
 * Principio rector: **zero impact en Flavor Platform**. Todo el acoplamiento
 * vive aquí; si Flavor Platform desaparece, basta con no engancharse al
 * hook y el plugin sigue igual.
 */
final class FlavorPlatformAddon
{
    /**
     * Identificador del addon dentro de Flavor Platform. Coincide con el
     * slug del menú principal del plugin para que la shell lo absorba por
     * prefijo `flavor-*` sin renombrados.
     */
    private const SLUG_ADDON = 'flavor-news-hub';

    public static function arrancar(): void
    {
        // `flavor_register_addons` se dispara en `plugins_loaded` prio 5.
        // Si Flavor Platform no está presente, el hook simplemente nunca
        // se ejecuta — no hace falta `class_exists` aquí.
        add_action('flavor_register_addons', [self::class, 'registrar']);
    }

    /**
     * Callback del hook. Flavor Platform llama a todos los addons
     * listos para registrarse. Si el `Addon_Manager` no está disponible
     * (por ejemplo en un orden de carga extraño) abortamos silenciosamente.
     */
    public static function registrar(): void
    {
        if (!class_exists('Flavor_Addon_Manager')) {
            return;
        }

        $version = defined('FNH_PLUGIN_VERSION') ? FNH_PLUGIN_VERSION : '0.1.0';
        $archivo = defined('FNH_PLUGIN_FILE') ? FNH_PLUGIN_FILE : __FILE__;

        \Flavor_Addon_Manager::register_addon(self::SLUG_ADDON, [
            'name'              => __('Flavor News Hub', 'flavor-news-hub'),
            'version'           => $version,
            'description'       => __(
                'Agregador headless de medios alternativos, colectivos y radios libres. Proporciona la API REST y el backend para la app Flavor News Hub.',
                'flavor-news-hub'
            ),
            'author'            => 'Josu Iru',
            'icon'              => 'dashicons-rss',
            // Dirigimos a la pantalla de Ajustes, que es donde un admin
            // espera configurar un addon. El dashboard propio del plugin
            // sigue accesible desde el menú principal `flavor-news-hub`.
            'settings_page'     => 'admin.php?page=fnh-settings',
            'file'              => $archivo,
            // El plugin sigue siendo independiente: no exigimos versión
            // de core porque puede ejecutarse standalone.
            'requires_core'     => '0.0.0',
            'is_premium'        => false,
            'documentation_url' => 'https://github.com/JosuIru/flavor-news-hub',
        ]);

        // Auto-update vía GitHub Releases: Flavor Platform expone esta
        // helper para que los addons deleguen el update checking en su
        // infraestructura (cache 12h, tokens, hooks WP estándar). Si no
        // está, el admin actualiza manualmente subiendo el ZIP.
        if (function_exists('flavor_register_addon_updates')) {
            \flavor_register_addon_updates(self::SLUG_ADDON, $archivo, $version, [
                'github_repo'    => 'JosuIru/flavor-news-hub',
                'name'           => 'Flavor News Hub',
                'tested'         => '6.7',
                'requires_php'   => '8.1',
                'beta'           => false,
            ]);
        }
    }

    /**
     * Devuelve true si Flavor Platform está cargado en este request.
     * Útil para que otras partes del plugin (p. ej. widgets de
     * dashboard) decidan si renderizar o no.
     */
    public static function estaFlavorPlatformActivo(): bool
    {
        return class_exists('Flavor_Addon_Manager');
    }
}
