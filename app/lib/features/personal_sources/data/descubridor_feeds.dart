import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Feed candidato encontrado al analizar una URL.
///
/// Puede venir de varias vías:
///  - Un `<link rel="alternate" type="application/rss+xml" href="…">` en el
///    `<head>` del HTML de la web pasada.
///  - Una resolución de URL de YouTube (`@handle` o `channel/UCxxx`) a su
///    feed oficial `youtube.com/feeds/videos.xml?channel_id=…`.
///  - La propia URL si ya pintaba a ser un feed.
@immutable
class FeedDescubierto {
  const FeedDescubierto({
    required this.url,
    required this.tituloSugerido,
    required this.tipoDetectado,
  });

  final String url;

  /// Título legible para sugerir como nombre al usuario (del `<title>` de
  /// la web o del `<title>` del propio feed tras un segundo HEAD).
  final String tituloSugerido;

  /// Tipo que encaja con el selector de tipo de la UI: rss / atom / youtube / podcast.
  final String tipoDetectado;
}

/// Descubre feeds RSS/Atom/YouTube a partir de cualquier URL razonable que
/// el usuario pegue. Sin servicios externos: todo se hace con peticiones
/// HTTP directas desde el dispositivo, coherente con el principio de "sin
/// tracking, sin terceros".
class DescubridorFeeds {
  const DescubridorFeeds();

  static const Duration _tiempoMaximo = Duration(seconds: 15);

  static const Map<String, String> _headersNavegador = {
    'User-Agent':
        'Mozilla/5.0 (FlavorNewsHub/0.1; +https://github.com/JosuIru/flavor-news-hub)',
    'Accept':
        'text/html, application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8',
    'Accept-Language': 'es, en;q=0.8',
  };

  /// Intenta encontrar feeds a partir del `urlEntrada`.
  /// Devuelve lista vacía si no encuentra nada.
  static Future<List<FeedDescubierto>> descubrir(
    http.Client cliente,
    String urlEntrada,
  ) async {
    final entrada = urlEntrada.trim();
    if (entrada.isEmpty) return const [];

    final uri = _normalizarUri(entrada);
    if (uri == null) return const [];

    // Caso 1: YouTube. Resolvemos @handle / channel/UCxxx / URL con video.
    if (_pareceYoutube(uri)) {
      final feedsYoutube = await _descubrirYoutube(cliente, uri);
      if (feedsYoutube.isNotEmpty) return feedsYoutube;
    }

    // Caso 2: la URL ya es un feed XML. Lo confirmamos con HEAD ligero.
    final feedsDirectos = await _comprobarSiYaEsFeed(cliente, uri);
    if (feedsDirectos.isNotEmpty) return feedsDirectos;

    // Caso 3: descargar HTML y extraer <link rel=alternate>.
    return _descubrirDesdeHtml(cliente, uri);
  }

  // ---------------- internos ----------------

  static Uri? _normalizarUri(String entrada) {
    // Si el usuario pegó algo tipo "elsaltodiario.com/…", añadimos https://.
    final conEsquema = entrada.contains('://') ? entrada : 'https://$entrada';
    final uri = Uri.tryParse(conEsquema);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    return uri;
  }

  static bool _pareceYoutube(Uri uri) {
    final host = uri.host.replaceFirst('www.', '');
    return host == 'youtube.com' || host == 'm.youtube.com' || host == 'youtu.be';
  }

  /// Resuelve cualquier URL de YouTube al feed RSS oficial por canal.
  /// YouTube ya no anuncia el feed en `<link rel=alternate>` desde hace
  /// años, pero sí expone el `channelId` en el HTML.
  static Future<List<FeedDescubierto>> _descubrirYoutube(
    http.Client cliente,
    Uri uri,
  ) async {
    try {
      final respuesta = await cliente
          .get(uri, headers: _headersNavegador)
          .timeout(_tiempoMaximo);
      if (respuesta.statusCode != 200) return const [];
      final idCanal = _extraerChannelIdYoutube(respuesta.body);
      if (idCanal == null || idCanal.isEmpty) return const [];

      final tituloCanal = _extraerTituloYoutube(respuesta.body) ?? 'Canal YouTube';
      final feedUrl = 'https://www.youtube.com/feeds/videos.xml?channel_id=$idCanal';
      return [
        FeedDescubierto(
          url: feedUrl,
          tituloSugerido: tituloCanal,
          tipoDetectado: 'youtube',
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static String? _extraerChannelIdYoutube(String html) {
    // YouTube expone "channelId":"UCxxx..." en su <script> embebido, y
    // también en meta itemprop="identifier". Probamos varios patrones.
    final patrones = [
      RegExp(r'"channelId":"(UC[A-Za-z0-9_-]{20,24})"'),
      RegExp(r'"externalId":"(UC[A-Za-z0-9_-]{20,24})"'),
      RegExp(r'<meta\s+itemprop="(?:channelId|identifier)"\s+content="(UC[A-Za-z0-9_-]{20,24})"'),
      RegExp(r'<link\s+rel="canonical"\s+href="https://www\.youtube\.com/channel/(UC[A-Za-z0-9_-]{20,24})"'),
    ];
    for (final patron in patrones) {
      final match = patron.firstMatch(html);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String? _extraerTituloYoutube(String html) {
    final m = RegExp(r'<meta\s+property="og:title"\s+content="([^"]+)"').firstMatch(html);
    if (m != null) return m.group(1);
    final t = RegExp(r'<title>([^<]+)</title>').firstMatch(html);
    if (t != null) {
      return t.group(1)?.replaceAll(RegExp(r'\s*-\s*YouTube\s*$'), '').trim();
    }
    return null;
  }

  /// Si la URL ya es el feed (devuelve XML directamente), la devolvemos
  /// tal cual, con el título extraído del propio feed para sugerirlo.
  static Future<List<FeedDescubierto>> _comprobarSiYaEsFeed(
    http.Client cliente,
    Uri uri,
  ) async {
    try {
      final respuesta = await cliente
          .get(uri, headers: _headersNavegador)
          .timeout(_tiempoMaximo);
      if (respuesta.statusCode != 200) return const [];
      final tipoContenido = (respuesta.headers['content-type'] ?? '').toLowerCase();
      final cuerpo = respuesta.body;
      if (!_pareceFeedXml(tipoContenido, cuerpo)) return const [];

      final titulo = _extraerTituloDeFeed(cuerpo) ?? uri.host;
      final esAtom = cuerpo.contains('<feed') && !cuerpo.contains('<rss');
      return [
        FeedDescubierto(
          url: uri.toString(),
          tituloSugerido: titulo,
          tipoDetectado: esAtom ? 'atom' : 'rss',
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static bool _pareceFeedXml(String tipoContenido, String cuerpo) {
    if (tipoContenido.contains('rss') ||
        tipoContenido.contains('atom') ||
        tipoContenido.contains('xml')) {
      return true;
    }
    // Algunos servidores devuelven text/html para feeds mal configurados.
    // Miramos los primeros bytes por si acaso.
    final inicio = cuerpo.trimLeft();
    return inicio.startsWith('<?xml') ||
        inicio.startsWith('<rss') ||
        inicio.startsWith('<feed');
  }

  static String? _extraerTituloDeFeed(String xmlCuerpo) {
    final match = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(xmlCuerpo);
    if (match == null) return null;
    final titulo = match.group(1)?.trim() ?? '';
    return titulo.isEmpty ? null : titulo;
  }

  /// Extrae todos los `<link rel="alternate">` con tipo RSS/Atom del HTML.
  static Future<List<FeedDescubierto>> _descubrirDesdeHtml(
    http.Client cliente,
    Uri uri,
  ) async {
    try {
      final respuesta = await cliente
          .get(uri, headers: _headersNavegador)
          .timeout(_tiempoMaximo);
      if (respuesta.statusCode != 200) return const [];
      if (respuesta.body.isEmpty) return const [];

      final documento = html_parser.parse(respuesta.body);
      final tituloPagina = documento
              .querySelector('meta[property="og:site_name"]')
              ?.attributes['content'] ??
          documento.querySelector('title')?.text.trim() ??
          uri.host;

      final encontrados = <FeedDescubierto>[];
      final vistos = <String>{};
      for (final link in documento.querySelectorAll('link[rel="alternate"]')) {
        final tipo = (link.attributes['type'] ?? '').toLowerCase();
        if (!tipo.contains('rss') && !tipo.contains('atom')) continue;
        final href = link.attributes['href'];
        if (href == null || href.isEmpty) continue;

        final urlAbsoluta = _resolverUrl(uri, href);
        if (!vistos.add(urlAbsoluta)) continue;

        final tituloFeed = link.attributes['title']?.trim();
        encontrados.add(FeedDescubierto(
          url: urlAbsoluta,
          tituloSugerido: (tituloFeed != null && tituloFeed.isNotEmpty)
              ? tituloFeed
              : tituloPagina,
          tipoDetectado: tipo.contains('atom') ? 'atom' : 'rss',
        ));
      }
      return encontrados;
    } catch (_) {
      return const [];
    }
  }

  static String _resolverUrl(Uri base, String href) {
    try {
      return base.resolve(href).toString();
    } catch (_) {
      return href;
    }
  }
}
