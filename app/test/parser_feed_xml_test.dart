import 'package:flavor_news_hub/features/personal_sources/data/fuente_personal.dart';
import 'package:flavor_news_hub/features/personal_sources/data/parser_feed_xml.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de ingesta RSS/Atom client-side. Cubren:
///  - parsing de formatos reales (RSS 2.0 y Atom 1.0),
///  - decodificación de entidades HTML doblemente escapadas,
///  - extracción de audio enclosure (pódcasts) y de imagen destacada,
///  - resistencia a feeds rotos (devuelve lista vacía, no lanza).
void main() {
  final fuente = FuentePersonal(
    nombre: 'Test',
    feedUrl: 'https://ejemplo.org/feed',
    tipoFeed: 'rss',
    anadidaEn: DateTime.utc(2026, 1, 1),
  );

  group('ParserFeedXml', () {
    test('RSS 2.0 con enclosure audio → audioUrl poblado', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
  <title>Podcast de prueba</title>
  <item>
    <title>Primer episodio</title>
    <link>https://ejemplo.org/ep1</link>
    <description>Descripción del ep1.</description>
    <pubDate>Mon, 20 Apr 2026 10:00:00 +0000</pubDate>
    <enclosure url="https://archive.org/ep1.mp3" type="audio/mpeg" length="12345"/>
  </item>
</channel>
</rss>
''';
      final items = ParserFeedXml.parsear(xml, fuente);
      expect(items, hasLength(1));
      expect(items.first.title, 'Primer episodio');
      expect(items.first.originalUrl, 'https://ejemplo.org/ep1');
      expect(items.first.audioUrl, 'https://archive.org/ep1.mp3');
    });

    test('Atom 1.0 con link alternate → lo usa como originalUrl', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Blog de prueba</title>
  <entry>
    <title>Post A</title>
    <link rel="alternate" href="https://ejemplo.org/post-a"/>
    <published>2026-04-19T09:00:00Z</published>
    <summary>Resumen A.</summary>
  </entry>
</feed>
''';
      final items = ParserFeedXml.parsear(xml, fuente);
      expect(items, hasLength(1));
      expect(items.first.title, 'Post A');
      expect(items.first.originalUrl, 'https://ejemplo.org/post-a');
    });

    test('Entidades dobles se decodifican a carácter real', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
  <item>
    <title>Título con &amp;#8217; tipográfica</title>
    <link>https://ejemplo.org/x</link>
  </item>
</channel>
</rss>
''';
      final items = ParserFeedXml.parsear(xml, fuente);
      expect(items, hasLength(1));
      // El parser decodifica `&#8217;` al apóstrofe tipográfico (U+2019).
      expect(items.first.title, contains('\u2019'));
    });

    test('XML roto devuelve lista vacía sin lanzar', () {
      final items = ParserFeedXml.parsear('no es xml en absoluto', fuente);
      expect(items, isEmpty);
    });

    test('Item sin título ni link se descarta', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
  <item>
    <description>Sólo descripción.</description>
  </item>
  <item>
    <title>Sí tiene título</title>
    <link>https://ejemplo.org/ok</link>
  </item>
</channel>
</rss>
''';
      final items = ParserFeedXml.parsear(xml, fuente);
      expect(items, hasLength(1));
      expect(items.first.title, 'Sí tiene título');
    });
  });
}
