<?php

declare(strict_types=1);

namespace FlavorNewsHub\Tests\Unit;

use FlavorNewsHub\Support\TerritoryNormalizer;
use PHPUnit\Framework\TestCase;

/**
 * Tests unitarios puros de TerritoryNormalizer::desglosar — la pieza que
 * convierte el `territory` libre del catálogo en país/región/ciudad/red.
 * Alimenta el filtrado y ordenación territorial; sin WordPress de por medio.
 */
final class TerritoryNormalizerTest extends TestCase
{
    public function testCadenaVaciaDevuelveTodoVacio(): void
    {
        $resultado = TerritoryNormalizer::desglosar('');
        self::assertSame('', $resultado['country']);
        self::assertSame('', $resultado['region']);
        self::assertSame('', $resultado['city']);
        self::assertSame('', $resultado['network']);
    }

    public function testRedTransnacional(): void
    {
        self::assertSame('Internacional', TerritoryNormalizer::desglosar('Internacional')['network']);
    }

    public function testPaisViaAliasSinTilde(): void
    {
        // 'spain' y 'estado espanol' son claves sin acentos, alcanzables.
        self::assertSame('España', TerritoryNormalizer::desglosar('spain')['country']);
        self::assertSame('España', TerritoryNormalizer::desglosar('Estado Español')['country']);
    }

    public function testRegionConPaisAsociado(): void
    {
        $catalunya = TerritoryNormalizer::desglosar('Catalunya');
        self::assertSame('España', $catalunya['country']);
        self::assertSame('Catalunya', $catalunya['region']);
    }

    public function testCiudad(): void
    {
        $bsas = TerritoryNormalizer::desglosar('Buenos Aires');
        self::assertSame('Argentina', $bsas['country']);
        self::assertSame('Buenos Aires', $bsas['city']);
    }

    public function testFormatoCompuestoPorComas(): void
    {
        // "Ciudad desconocida, Región conocida" → cae al segundo segmento.
        $resultado = TerritoryNormalizer::desglosar('Barrio X, Euskadi');
        self::assertSame('Euskadi', $resultado['region']);
        self::assertSame('España', $resultado['country']);
    }

    public function testNormalizaMayusculasYGuiones(): void
    {
        // strtolower + guiones→espacios deben llevar 'PAIS-VASCO' a 'pais vasco'.
        $resultado = TerritoryNormalizer::desglosar('PAIS-VASCO');
        self::assertSame('País Vasco', $resultado['region']);
    }

    /**
     * Bug documentado: remove_accents pasa la ñ a 'n' ('España'→'espana'),
     * pero la clave del mapa es 'españa' (con ñ), así que esa entrada es
     * inalcanzable y "España" tal cual NO resuelve a país. Solo funcionan los
     * alias sin tilde ('spain', 'estado espanol'). Mismo bug que en la app
     * (lib/core/utils/territory_normalizer.dart). Este test fija el
     * comportamiento actual; arreglar el normalizador lo hará fallar y
     * obligará a actualizarlo.
     */
    public function testBugEspanaConEnyeNoResuelve(): void
    {
        $resultado = TerritoryNormalizer::desglosar('España');
        self::assertSame('', $resultado['country'], 'Si esto falla: el bug de la ñ se arregló, actualiza el test.');
    }
}
