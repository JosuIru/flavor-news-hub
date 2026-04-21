import 'package:xml/xml.dart';

import '../../../core/models/item.dart';
import '../../../core/models/source_summary.dart';
import 'fuente_personal.dart';

/// Parser ligero de feeds RSS 2.0 y Atom.
///
/// Convierte cada entrada a un `Item` del dominio del backend para poder
/// mezclarlo en la misma lista del feed (cronológico por `publishedAt`).
/// No hacemos scraping, no resolvemos enlaces, no seguimos redirecciones:
/// lo que el feed provee es lo que se muestra.
class ParserFeedXml {
  /// @return lista de items de la fuente personal.
  static List<Item> parsear(String xmlString, FuentePersonal fuente) {
    final XmlDocument documento;
    try {
      documento = XmlDocument.parse(xmlString);
    } on XmlException {
      return const [];
    }

    if (documento.findAllElements('feed').isNotEmpty) {
      return _parsearAtom(documento, fuente);
    }
    if (documento.findAllElements('rss').isNotEmpty ||
        documento.findAllElements('channel').isNotEmpty) {
      return _parsearRss2(documento, fuente);
    }
    return const [];
  }

  static List<Item> _parsearRss2(XmlDocument documento, FuentePersonal fuente) {
    final salida = <Item>[];
    var indice = 0;
    for (final itemXml in documento.findAllElements('item')) {
      final titulo = _primerTextoHijo(itemXml, ['title']);
      final enlace = _primerTextoHijo(itemXml, ['link']);
      if (titulo.isEmpty || enlace.isEmpty) continue;

      final descripcion = _primerTextoHijo(itemXml, ['description', 'summary']);
      final pubDateTexto = _primerTextoHijo(itemXml, ['pubDate', 'dc:date', 'date']);
      final guid = _primerTextoHijo(itemXml, ['guid']);
      final mediaUrl = _primeraImagenRss(itemXml);
      final audioUrl = _primerAudioEnclosure(itemXml);

      final fechaPublicacion = _parsearFecha(pubDateTexto);
      salida.add(Item(
        id: _idEstable(fuente.feedUrl, guid.isNotEmpty ? guid : enlace, indice),
        slug: '',
        title: _decodificarEntidades(titulo),
        excerpt: descripcion,
        url: '',
        originalUrl: enlace,
        publishedAt: fechaPublicacion?.toUtc().toIso8601String() ?? '',
        mediaUrl: mediaUrl,
        audioUrl: audioUrl,
        source: SourceSummary(
          id: _idEstable(fuente.feedUrl, fuente.feedUrl, 0),
          slug: '',
          name: fuente.nombre,
          websiteUrl: '',
          url: fuente.feedUrl,
          feedType: fuente.tipoFeed,
        ),
        topics: const [],
      ));
      indice++;
    }
    return salida;
  }

  static List<Item> _parsearAtom(XmlDocument documento, FuentePersonal fuente) {
    final salida = <Item>[];
    var indice = 0;
    for (final entry in documento.findAllElements('entry')) {
      final titulo = _primerTextoHijo(entry, ['title']);
      final enlace = _enlaceAtom(entry);
      if (titulo.isEmpty || enlace.isEmpty) continue;

      final resumen = _primerTextoHijo(entry, ['summary', 'content']);
      final fechaTexto = _primerTextoHijo(entry, ['published', 'updated']);
      final guid = _primerTextoHijo(entry, ['id']);
      final mediaUrl = _primeraImagenAtom(entry);
      final audioUrl = _primerAudioEnclosureAtom(entry);

      final fechaPublicacion = _parsearFecha(fechaTexto);
      salida.add(Item(
        id: _idEstable(fuente.feedUrl, guid.isNotEmpty ? guid : enlace, indice),
        slug: '',
        title: _decodificarEntidades(titulo),
        excerpt: resumen,
        url: '',
        originalUrl: enlace,
        publishedAt: fechaPublicacion?.toUtc().toIso8601String() ?? '',
        mediaUrl: mediaUrl,
        audioUrl: audioUrl,
        source: SourceSummary(
          id: _idEstable(fuente.feedUrl, fuente.feedUrl, 0),
          slug: '',
          name: fuente.nombre,
          websiteUrl: '',
          url: fuente.feedUrl,
          feedType: fuente.tipoFeed,
        ),
        topics: const [],
      ));
      indice++;
    }
    return salida;
  }

  static String _primerTextoHijo(XmlElement elemento, List<String> nombresHijos) {
    for (final nombre in nombresHijos) {
      final nodo = elemento.findElements(nombre);
      if (nodo.isNotEmpty) {
        final texto = nodo.first.innerText.trim();
        if (texto.isNotEmpty) return texto;
      }
    }
    return '';
  }

  static String _enlaceAtom(XmlElement entry) {
    for (final link in entry.findElements('link')) {
      final rel = link.getAttribute('rel') ?? 'alternate';
      if (rel == 'alternate') {
        final href = link.getAttribute('href');
        if (href != null && href.isNotEmpty) return href;
      }
    }
    // fallback: primer <link> disponible
    final primero = entry.findElements('link');
    if (primero.isNotEmpty) {
      return primero.first.getAttribute('href') ?? primero.first.innerText.trim();
    }
    return '';
  }

  static String _primeraImagenRss(XmlElement itemXml) {
    // enclosure type=image/*
    for (final enclosure in itemXml.findElements('enclosure')) {
      final tipo = enclosure.getAttribute('type') ?? '';
      if (tipo.isEmpty || tipo.startsWith('image/')) {
        final url = enclosure.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
    }
    // media:thumbnail
    for (final media in itemXml.findElements('media:thumbnail')) {
      final url = media.getAttribute('url');
      if (url != null && url.isNotEmpty) return url;
    }
    // primera <img> del contenido
    final contenido = _primerTextoHijo(itemXml, ['content:encoded', 'description']);
    return _primeraImagenHtml(contenido);
  }

  static String _primeraImagenAtom(XmlElement entry) {
    for (final link in entry.findElements('link')) {
      final rel = link.getAttribute('rel') ?? '';
      final tipo = link.getAttribute('type') ?? '';
      if (rel == 'enclosure' && tipo.startsWith('image/')) {
        final href = link.getAttribute('href');
        if (href != null && href.isNotEmpty) return href;
      }
    }
    for (final media in entry.findElements('media:thumbnail')) {
      final url = media.getAttribute('url');
      if (url != null && url.isNotEmpty) return url;
    }
    final contenido = _primerTextoHijo(entry, ['content', 'summary']);
    return _primeraImagenHtml(contenido);
  }

  /// Extrae la primera URL de audio de un `<item>` RSS. Los feeds de podcast
  /// usan `<enclosure url="…mp3" type="audio/mpeg">`. Si no hay enclosure
  /// audio, devuelve cadena vacía — el item se tratará como texto.
  static String _primerAudioEnclosure(XmlElement itemXml) {
    for (final enclosure in itemXml.findElements('enclosure')) {
      final tipo = enclosure.getAttribute('type') ?? '';
      if (tipo.startsWith('audio/')) {
        final url = enclosure.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
    }
    return '';
  }

  /// Atom equivalente: `<link rel="enclosure" type="audio/…" href="…">`.
  static String _primerAudioEnclosureAtom(XmlElement entry) {
    for (final link in entry.findElements('link')) {
      final rel = link.getAttribute('rel') ?? '';
      final tipo = link.getAttribute('type') ?? '';
      if (rel == 'enclosure' && tipo.startsWith('audio/')) {
        final href = link.getAttribute('href');
        if (href != null && href.isNotEmpty) return href;
      }
    }
    return '';
  }

  static String _primeraImagenHtml(String contenido) {
    if (contenido.isEmpty) return '';
    final reg = RegExp(r"""<img[^>]+src=['"]([^'"]+)['"]""", caseSensitive: false);
    final coincidencia = reg.firstMatch(contenido);
    return coincidencia?.group(1) ?? '';
  }

  /// Decodifica entidades HTML básicas (`&quot;`, `&amp;`, `&#8220;`, etc.)
  /// que algunos feeds emiten sin decodificar.
  static String _decodificarEntidades(String texto) {
    return texto
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#8220;', '\u201C')
        .replaceAll('&#8221;', '\u201D')
        .replaceAll('&#8217;', '\u2019')
        .replaceAll('&#8211;', '\u2013')
        .replaceAll('&#038;', '&')
        .replaceAll('&amp;', '&');
  }

  /// Parsea `pubDate` RFC 822 o ISO 8601. Devuelve null si no se puede.
  static DateTime? _parsearFecha(String texto) {
    if (texto.isEmpty) return null;
    final iso = DateTime.tryParse(texto);
    if (iso != null) return iso;
    try {
      // HttpDate parsea RFC 1123/822, común en RSS 2.0.
      return DateTime.tryParse(texto) ?? _parsearRfc822(texto);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parsearRfc822(String texto) {
    // Flutter web no tiene `HttpDate`; hacemos un parser regex manual.
    // Formato: "Mon, 20 Apr 2026 08:00:00 +0000"
    final reg = RegExp(
      r'(\d{1,2})\s+(\w{3})\s+(\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})\s*([+-]\d{4}|\w+)?',
    );
    final match = reg.firstMatch(texto);
    if (match == null) return null;
    const meses = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final dia = int.tryParse(match.group(1)!);
    final mes = meses[match.group(2)!];
    var anio = int.tryParse(match.group(3)!);
    final hora = int.tryParse(match.group(4)!);
    final minuto = int.tryParse(match.group(5)!);
    final segundo = int.tryParse(match.group(6)!);
    if (dia == null || mes == null || anio == null || hora == null || minuto == null || segundo == null) {
      return null;
    }
    if (anio < 100) anio += 2000;
    return DateTime.utc(anio, mes, dia, hora, minuto, segundo);
  }

  /// Genera un id numérico estable a partir del feed y el guid/permalink.
  /// Negativo por convención para distinguirlo de los ids del backend
  /// (que son positivos: IDs de posts WordPress).
  static int _idEstable(String feedUrl, String identificador, int indice) {
    final combinado = '$feedUrl|$identificador|$indice';
    var hash = 0;
    for (final codigo in combinado.codeUnits) {
      hash = (hash * 31 + codigo) & 0x7fffffff;
    }
    return -hash - 1;
  }
}
