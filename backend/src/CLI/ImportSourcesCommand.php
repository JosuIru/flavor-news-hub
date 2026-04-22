<?php
declare(strict_types=1);

namespace FlavorNewsHub\CLI;

use FlavorNewsHub\Catalog\CatalogoPorDefecto;
use FlavorNewsHub\Catalog\ImportadorCatalogo;

/**
 * Importa el seed curado (bundleado en `seed/*.json` del plugin, o un
 * JSON externo vía `--file`) como posts reales de `fnh_source` /
 * `fnh_radio`. El plugin no se pre-puebla a propósito (cada instancia
 * decide qué activar), pero para empezar rápido se puede tomar como
 * base el catálogo bundleado que también usa la app Flutter.
 *
 * Uso:
 *   wp flavor-news import sources              # usa el seed bundleado
 *   wp flavor-news import sources --file=/ruta/sources.json
 *   wp flavor-news import sources --actualizar # sobreescribe metas existentes
 *   wp flavor-news import radios
 *   wp flavor-news import radios --file=/ruta/radios.json
 *
 * Idempotente: compara por slug. Sin `--actualizar` respeta los que
 * ya estén; con esa flag sobreescribe los metas.
 */
final class ImportSourcesCommand
{
    /**
     * Importa fuentes desde el catálogo bundleado o un JSON externo.
     *
     * ## OPTIONS
     *
     * [--file=<ruta>]
     * : Ruta a un JSON con la lista. Si se omite, usa el seed bundleado.
     *
     * [--actualizar]
     * : Sobreescribe metas de fuentes existentes (match por slug).
     *
     * ## EXAMPLES
     *
     *     wp flavor-news import sources
     *     wp flavor-news import sources --file=./sources.json --actualizar
     */
    public function sources(array $args, array $flags): void
    {
        $datos = self::cargarDatos((string) ($flags['file'] ?? ''), CatalogoPorDefecto::sources(...));
        $actualizar = isset($flags['actualizar']);

        $r = ImportadorCatalogo::importarSources($datos, $actualizar, null);
        self::reportar('fuentes', $r);
    }

    /**
     * Importa radios desde el catálogo bundleado o un JSON externo.
     *
     * ## OPTIONS
     *
     * [--file=<ruta>]
     * : Ruta a un JSON con la lista. Si se omite, usa el seed bundleado.
     *
     * [--actualizar]
     * : Sobreescribe metas de radios existentes (match por slug).
     */
    public function radios(array $args, array $flags): void
    {
        $datos = self::cargarDatos((string) ($flags['file'] ?? ''), CatalogoPorDefecto::radios(...));
        $actualizar = isset($flags['actualizar']);

        $r = ImportadorCatalogo::importarRadios($datos, $actualizar, null);
        self::reportar('radios', $r);
    }

    /**
     * @param callable():list<array<string,mixed>> $proveedorBundleado
     * @return list<array<string,mixed>>
     */
    private static function cargarDatos(string $ruta, callable $proveedorBundleado): array
    {
        if ($ruta === '') {
            return $proveedorBundleado();
        }
        if (!is_readable($ruta)) {
            \WP_CLI::error("Archivo no accesible: {$ruta}");
        }
        $decoded = json_decode((string) @file_get_contents($ruta), true);
        if (!is_array($decoded)) {
            \WP_CLI::error("JSON inválido en {$ruta}");
        }
        return array_values(array_filter($decoded, 'is_array'));
    }

    /**
     * @param array{creados:int,actualizados:int,saltados:int,errores:list<string>} $r
     */
    private static function reportar(string $tipo, array $r): void
    {
        \WP_CLI::success(sprintf(
            '%s: %d creadas, %d actualizadas, %d saltadas (ya existían).',
            ucfirst($tipo),
            $r['creados'],
            $r['actualizados'],
            $r['saltados']
        ));
        foreach ($r['errores'] as $err) {
            \WP_CLI::warning($err);
        }
    }
}
