<?php

declare(strict_types=1);

namespace FlavorNewsHub\Tests\Unit;

use FlavorNewsHub\Admin\Pages\CatalogoPage;
use PHPUnit\Framework\TestCase;
use ReflectionMethod;

/**
 * Tests de `CatalogoPage::compararConInstalado`, la lógica que decide
 * qué entradas del catálogo aparecen marcadas como divergentes en el
 * panel (y, por tanto, cuáles selecciona el filtro "Sólo las que
 * difieren").
 *
 * Importa acertar aquí: marcar de más lleva a re-importar con
 * "Sobrescribir metas" fuentes que no tocaba, y como el importador
 * aplica `active` cuando el seed lo declara, eso desactiva medios
 * vivos. El caso que motivó estos tests: 19 fuentes del seed con
 * `active: false` que en producción estaban activas, cinco de ellas
 * publicando a diario.
 */
final class CatalogoComparacionTest extends TestCase
{
    /** @param array<string,mixed> $entrada */
    private function comparar(array $entrada, ?array $instalado, string $tab = 'sources'): array
    {
        $metodo = new ReflectionMethod(CatalogoPage::class, 'compararConInstalado');
        $metodo->setAccessible(true);
        return $metodo->invoke(null, $entrada, $instalado, $tab);
    }

    private function instalado(string $feedUrl, bool $activa = true): array
    {
        return ['feed_url' => $feedUrl, 'stream_url' => '', 'active' => $activa];
    }

    public function testEntradaNoInstaladaEsPendiente(): void
    {
        $r = $this->comparar(['feed_url' => 'https://a.example/feed/'], null);
        self::assertSame('pendiente', $r['estado']);
    }

    public function testMismaUrlYSinActiveEnElSeedNoDifiere(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://a.example/feed/'],
            $this->instalado('https://a.example/feed/')
        );
        self::assertSame('igual', $r['estado']);
    }

    public function testUrlDistintaDifiere(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://nueva.example/feed/'],
            $this->instalado('https://vieja.example/feed/')
        );
        self::assertSame('difiere', $r['estado']);
        self::assertSame('URL distinta', $r['detalle']);
    }

    public function testSeedInactivoSobreInstaladaActivaAvisaDeDesactivacion(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://a.example/feed/', 'active' => false],
            $this->instalado('https://a.example/feed/', true)
        );
        self::assertSame('difiere', $r['estado']);
        self::assertSame('Se DESACTIVARÁ', $r['detalle']);
    }

    public function testSeedActivoSobreInstaladaInactivaAvisaDeActivacion(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://a.example/feed/', 'active' => true],
            $this->instalado('https://a.example/feed/', false)
        );
        self::assertSame('difiere', $r['estado']);
        self::assertSame('Se ACTIVARÁ', $r['detalle']);
    }

    /**
     * Si el seed NO declara `active`, el importador no toca ese meta
     * (respeta la decisión manual del admin). La comparación no debe
     * marcar diferencia por ese motivo, o el panel invitaría a
     * re-importar entradas que no cambiarían nada.
     */
    public function testSeedSinActiveNoDifiereAunqueLaInstaladaEsteDesactivada(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://a.example/feed/'],
            $this->instalado('https://a.example/feed/', false)
        );
        self::assertSame('igual', $r['estado']);
    }

    /**
     * La baja manda sobre la URL: si además de cambiar el feed la
     * entrada se desactiva, lo que el admin necesita ver es la baja.
     */
    public function testLaDesactivacionTienePrioridadSobreElCambioDeUrl(): void
    {
        $r = $this->comparar(
            ['feed_url' => 'https://nueva.example/feed/', 'active' => false],
            $this->instalado('https://vieja.example/feed/', true)
        );
        self::assertSame('Se DESACTIVARÁ', $r['detalle']);
    }

    public function testEnRadiosComparaElStreamYNoElFeed(): void
    {
        $r = $this->comparar(
            ['stream_url' => 'https://nuevo.example/stream'],
            ['feed_url' => '', 'stream_url' => 'https://viejo.example/stream', 'active' => true],
            'radios'
        );
        self::assertSame('difiere', $r['estado']);
    }

    /**
     * Un seed sin URL no debe marcar diferencia: no hay nada que
     * comparar y re-importar no cambiaría la URL instalada.
     */
    public function testSeedSinUrlNoDifiere(): void
    {
        $r = $this->comparar([], $this->instalado('https://a.example/feed/'));
        self::assertSame('igual', $r['estado']);
    }
}
