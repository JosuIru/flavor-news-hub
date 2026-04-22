<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

/**
 * Lector del catálogo por defecto bundleado en `seed/*.json`. Lo usan
 * tanto el admin (pantalla "Catálogo") como los comandos WP-CLI para
 * activar fuentes/radios/colectivos sin tener que escribir URLs a mano.
 *
 * El contenido es el mismo seed que viaja con la app Flutter, así el
 * plugin y la app quedan alineados de serie. Re-importar es idempotente:
 * se compara por slug y sólo se crean los que aún no existen como post.
 */
final class CatalogoPorDefecto
{
    /**
     * @return list<array<string,mixed>>
     */
    public static function sources(): array
    {
        return self::leer('sources.json');
    }

    /**
     * @return list<array<string,mixed>>
     */
    public static function radios(): array
    {
        return self::leer('radios.json');
    }

    /**
     * @return list<array<string,mixed>>
     */
    public static function collectives(): array
    {
        return self::leer('collectives.json');
    }

    /**
     * @return list<array<string,mixed>>
     */
    private static function leer(string $fichero): array
    {
        $ruta = self::rutaBase() . '/' . $fichero;
        if (!is_readable($ruta)) {
            return [];
        }
        $raw = @file_get_contents($ruta);
        $decoded = json_decode((string) $raw, true);
        if (!is_array($decoded)) {
            return [];
        }
        return array_values(array_filter(
            $decoded,
            static fn($entry) => is_array($entry)
        ));
    }

    public static function rutaBase(): string
    {
        // FNH_PLUGIN_FILE está definida en el bootstrap `flavor-news-hub.php`.
        // Nos lleva al directorio raíz del plugin.
        $base = defined('FNH_PLUGIN_FILE')
            ? dirname((string) FNH_PLUGIN_FILE)
            : dirname(__DIR__, 2);
        return $base . '/seed';
    }
}
