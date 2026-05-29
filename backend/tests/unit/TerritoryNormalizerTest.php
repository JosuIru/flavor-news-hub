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
     * El normalizador reindexa el mapa por su clave normalizada, así que las
     * entradas con tilde/ñ ('españa', 'andalucía'…) vuelven a ser alcanzables.
     * Antes "España" no resolvía (la clave 'españa' quedaba inaccesible porque
     * el lookup normaliza la ñ a 'n').
     */
    public function testEspanaConEnyeResuelveAPais(): void
    {
        self::assertSame('España', TerritoryNormalizer::desglosar('España')['country']);
        self::assertSame('Andalucía', TerritoryNormalizer::desglosar('Andalucía')['region']);
    }

    /**
     * Regresión de la resolución de colisiones: 'valencia' (región "Valencia")
     * y 'valència' ("València") normalizan ambas a 'valencia'. Debe ganar la
     * clave que ya estaba normalizada, conservando "Valencia".
     */
    public function testColisionValenciaConservaGrafiaPrevia(): void
    {
        self::assertSame('Valencia', TerritoryNormalizer::desglosar('Valencia')['region']);
    }
}
