<?php

declare(strict_types=1);

namespace FlavorNewsHub\Tests\Unit;

use FlavorNewsHub\Ingest\FeedIngester;
use PHPUnit\Framework\TestCase;
use ReflectionMethod;

/**
 * Tests de `FeedIngester::pareceFeed`, que decide si una respuesta 200
 * es un feed o una página HTML.
 *
 * De esa distinción depende el reintento con User-Agent de lector: hay
 * orígenes que sirven el RSS a los agregadores y devuelven una pared
 * anti-bot en HTML —con 200, no con 403— a los User-Agent de
 * navegador, que es el que manda el ingester. Caso verificado:
 * desinformemonos.org. Un falso positivo aquí haría tragar HTML como
 * si fuera un feed; un falso negativo dispararía un segundo request
 * inútil en cada ingesta.
 */
final class PareceFeedTest extends TestCase
{
    private function pareceFeed(string $cuerpo): bool
    {
        $metodo = new ReflectionMethod(FeedIngester::class, 'pareceFeed');
        $metodo->setAccessible(true);
        return $metodo->invoke(null, $cuerpo);
    }

    public function testRssSimple(): void
    {
        self::assertTrue($this->pareceFeed(
            '<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>'
        ));
    }

    public function testAtom(): void
    {
        self::assertTrue($this->pareceFeed(
            '<?xml version="1.0" encoding="utf-8"?><feed xmlns="http://www.w3.org/2005/Atom"></feed>'
        ));
    }

    public function testRdfDeRss10(): void
    {
        self::assertTrue($this->pareceFeed(
            '<?xml version="1.0"?><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"></rdf:RDF>'
        ));
    }

    /** Muchos feeds abren con un BOM que rompía comparaciones ingenuas. */
    public function testToleraBomYEspacios(): void
    {
        self::assertTrue($this->pareceFeed(
            "\xEF\xBB\xBF\n  <?xml version=\"1.0\"?>\n<rss version=\"2.0\"></rss>"
        ));
    }

    /** Hoja de estilo XML antes de la raíz: habitual en feeds "bonitos". */
    public function testToleraStylesheetYComentarios(): void
    {
        self::assertTrue($this->pareceFeed(
            '<?xml version="1.0"?>' .
            '<?xml-stylesheet type="text/xsl" href="/feed.xsl"?>' .
            '<!-- generado por WordPress -->' .
            '<rss version="2.0"></rss>'
        ));
    }

    public function testPaginaHtmlNoEsFeed(): void
    {
        self::assertFalse($this->pareceFeed(
            "<!DOCTYPE html>\n<html lang=\"es\"><head><title>Inicio</title></head><body></body></html>"
        ));
    }

    /** El caso real: pared anti-bot servida con HTTP 200. */
    public function testParedAntibotNoEsFeed(): void
    {
        self::assertFalse($this->pareceFeed(
            '<!DOCTYPE html><html><head><meta charset="utf-8">' .
            '<title>Making sure you are not a bot!</title></head>' .
            '<body><div id="challenge"></div></body></html>'
        ));
    }

    public function testCuerpoVacioNoEsFeed(): void
    {
        self::assertFalse($this->pareceFeed(''));
    }

    /**
     * Una página HTML que MENCIONA un feed en un <link rel=alternate>
     * no es un feed. Con una búsqueda por subcadena tipo `str_contains`
     * esto habría dado positivo.
     */
    public function testHtmlQueEnlazaUnFeedNoEsFeed(): void
    {
        self::assertFalse($this->pareceFeed(
            '<!DOCTYPE html><html><head>' .
            '<link rel="alternate" type="application/rss+xml" href="https://x.example/feed/">' .
            '</head><body></body></html>'
        ));
    }
}
