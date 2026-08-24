<?php

declare(strict_types=1);

namespace FlavorNewsHub\Tests\Unit;

use FlavorNewsHub\Support\InterleaveSources;
use PHPUnit\Framework\TestCase;

/**
 * Tests unitarios de InterleaveSources::conTopePorSource — el recorte
 * con tope por medio que evita que una fuente prolífica monopolice la
 * página (`max_per_source` del endpoint /items).
 */
final class InterleaveSourcesTest extends TestCase
{
    /** @var array<int,int> post ID → source ID */
    public static array $sourcePorPost = [];

    /** Crea un post del source dado y registra su meta en el mapa. */
    private function post(int $idPost, int $idSource): \WP_Post
    {
        self::$sourcePorPost[$idPost] = $idSource;
        return new \WP_Post($idPost);
    }

    protected function setUp(): void
    {
        self::$sourcePorPost = [];
    }

    /** @param array<int,\WP_Post> $posts @return list<int> */
    private static function sources(array $posts): array
    {
        return array_map(
            fn(\WP_Post $p) => self::$sourcePorPost[$p->ID],
            array_values($posts),
        );
    }

    public function testFuenteProlificaNoMonopolizaLaPagina(): void
    {
        // Ventana: 8 items de la fuente 1 (la prolífica) seguidos de
        // 2 de la fuente 2 y 1 de la 3 — el caso Radio Kurruf.
        $ventana = [];
        for ($i = 1; $i <= 8; $i++) {
            $ventana[] = $this->post($i, 1);
        }
        $ventana[] = $this->post(9, 2);
        $ventana[] = $this->post(10, 2);
        $ventana[] = $this->post(11, 3);

        $resultado = InterleaveSources::conTopePorSource($ventana, 2, 5);

        $cuenta = array_count_values(self::sources($resultado));
        self::assertCount(5, $resultado);
        self::assertSame(2, $cuenta[1]);
        self::assertSame(2, $cuenta[2]);
        self::assertSame(1, $cuenta[3]);
    }

    public function testRellenaConDescartadosSiNoSeLlenaElCupo(): void
    {
        // Sólo dos fuentes con tope 1: sin la segunda pasada el
        // resultado tendría 2 items; con relleno llega al límite de 4.
        $ventana = [
            $this->post(1, 1),
            $this->post(2, 1),
            $this->post(3, 2),
            $this->post(4, 2),
        ];

        $resultado = InterleaveSources::conTopePorSource($ventana, 1, 4);

        self::assertCount(4, $resultado);
    }

    public function testRespetaElLimiteDePagina(): void
    {
        $ventana = [];
        for ($i = 1; $i <= 20; $i++) {
            $ventana[] = $this->post($i, $i); // 20 fuentes distintas
        }

        $resultado = InterleaveSources::conTopePorSource($ventana, 2, 10);

        self::assertCount(10, $resultado);
    }

    public function testTopeCeroEquivaleASoloRecortar(): void
    {
        $ventana = [
            $this->post(1, 1),
            $this->post(2, 1),
            $this->post(3, 2),
        ];

        $resultado = InterleaveSources::conTopePorSource($ventana, 0, 2);

        self::assertCount(2, $resultado);
    }
}
