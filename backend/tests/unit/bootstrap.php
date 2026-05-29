<?php
/**
 * Bootstrap para tests UNITARIOS puros del plugin: lógica que no toca la
 * base de datos ni el ciclo de vida de WordPress. A diferencia de
 * tests/bootstrap.php (que exige la WP test-lib + MySQL), aquí solo
 * cargamos el autoload de Composer y stubeamos las pocas funciones de
 * WordPress de las que depende la lógica bajo prueba.
 *
 * Ejecutar: vendor/bin/phpunit -c phpunit-unit.xml.dist
 */

declare(strict_types=1);

require_once dirname(__DIR__, 2) . '/vendor/autoload.php';

// `remove_accents` de WordPress: translitera caracteres latinos acentuados a
// ASCII (incluida ñ→n). Reproducimos su comportamiento para el subconjunto
// que usa TerritoryNormalizer, sin arrastrar todo WordPress.
if (!function_exists('remove_accents')) {
    function remove_accents(string $cadena): string
    {
        $equivalencias = [
            'á' => 'a', 'à' => 'a', 'ä' => 'a', 'â' => 'a', 'ã' => 'a', 'å' => 'a',
            'é' => 'e', 'è' => 'e', 'ë' => 'e', 'ê' => 'e',
            'í' => 'i', 'ì' => 'i', 'ï' => 'i', 'î' => 'i',
            'ó' => 'o', 'ò' => 'o', 'ö' => 'o', 'ô' => 'o', 'õ' => 'o',
            'ú' => 'u', 'ù' => 'u', 'ü' => 'u', 'û' => 'u',
            'ñ' => 'n', 'ç' => 'c',
            'Á' => 'A', 'À' => 'A', 'É' => 'E', 'Í' => 'I', 'Ó' => 'O', 'Ú' => 'U',
            'Ñ' => 'N', 'Ç' => 'C',
        ];
        return strtr($cadena, $equivalencias);
    }
}
