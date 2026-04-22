import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/item.dart';
import '../../../core/models/source_summary.dart';
import '../../../core/models/topic.dart';
import '../../../core/providers/api_provider.dart';
import '../../personal_sources/data/fuente_personal.dart';
import '../../personal_sources/data/parser_feed_xml.dart';
import 'seed_loader.dart';

/// Modo autónomo: cuando el backend no responde, el cliente descarga los
/// RSS del seed directamente y los convierte en `Item`. Reutiliza el
/// parser existente de "Mis medios" porque el formato RSS/Atom es el mismo.
///
/// Límites deliberados:
///  - sólo feeds RSS/Atom (no YouTube/Mastodon) — no complicamos con auth.
///  - un máximo de N peticiones paralelas (`_maxConcurrentes`) para no
///    saturar conexiones móviles.
///  - cada fetch con timeout individual; si uno falla, los demás siguen.
// Subimos la concurrencia: WebView y la red Android manejan bien 15
// peticiones simultáneas, y antes con 6 teníamos que esperar al lento
// de cada batch antes de empezar el siguiente. Timeout 6s: los feeds
// que tardan más probablemente están rotos o en un país remoto y no
// vale la pena bloquear la UI por ellos.
const int _maxConcurrentes = 15;
const Duration _timeoutPorFeed = Duration(seconds: 6);

/// Descarga los RSS del seed en tramos y **emite la lista acumulada tras
/// cada tramo**. El `FeedNotifier` escucha este stream y actualiza la UI
/// progresivamente, en vez de esperar a que los 40 feeds acaben.
/// `.future` sigue funcionando para consumidores que quieran sólo el
/// valor final (p. ej. `videosProvider`): resuelve cuando el stream
/// cierra, con la lista completa.
final itemsDesdeSeedProvider = StreamProvider.autoDispose<List<Item>>((ref) async* {
  final fuentes = await ref.watch(fuentesSeedProvider.future);
  debugPrint('[itemsDesdeSeed] fuentes totales=${fuentes.length}');
  final rsss = fuentes.where((f) {
    // YouTube deprecó en 2026 su endpoint `/feeds/videos.xml?channel_id`:
    // ahora devuelve 404 para todos los canales. Excluimos `youtube` en
    // modo offline para no gastar timeouts — los canales siguen en el
    // seed porque el backend sí los ingesta vía su propio pipeline.
    // `video` (PeerTube) y `mastodon` exponen RSS nativo y funcionan.
    const tiposSoportados = {'rss', 'atom', 'podcast', 'video', 'mastodon'};
    return tiposSoportados.contains(f.feedType);
  }).toList();
  debugPrint('[itemsDesdeSeed] fuentes XML soportadas=${rsss.length}');
  if (rsss.isEmpty) {
    yield const [];
    return;
  }

  final http.Client httpClient = ref.watch(httpClientProvider);
  final acumulados = <Item>[];
  var fuentesOk = 0;
  var fuentesFallidas = 0;

  // Batching simple para limitar concurrencia. Tras cada tramo emitimos
  // la lista ordenada ya acumulada.
  for (var i = 0; i < rsss.length; i += _maxConcurrentes) {
    final chunk = rsss.sublist(i, (i + _maxConcurrentes).clamp(0, rsss.length));
    final futuros = chunk.map((fuente) => _traerUna(httpClient, fuente));
    final listas = await Future.wait(futuros);
    for (final lista in listas) {
      if (lista.isEmpty) {
        fuentesFallidas++;
      } else {
        fuentesOk++;
        acumulados.addAll(lista);
      }
    }
    acumulados.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    debugPrint('[itemsDesdeSeed] tramo ${i ~/ _maxConcurrentes + 1} acumulados=${acumulados.length}');
    yield List.unmodifiable(acumulados);
  }

  debugPrint('[itemsDesdeSeed] final OK=$fuentesOk fallidas=$fuentesFallidas items=${acumulados.length}');
});

Future<List<Item>> _traerUna(http.Client cliente, FuenteSeed fuente) async {
  final uri = Uri.tryParse(fuente.feedUrl);
  if (uri == null) {
    debugPrint('[itemsDesdeSeed] URI inválida: ${fuente.feedUrl}');
    return const [];
  }
  try {
    final resp = await cliente.get(uri, headers: const {
      // Accept permisivo: varios WordPress (El Salto, Naukas…) devuelven
      // 406 si no incluimos text/html o `*/*`, aunque el feed esté en
      // el mismo endpoint.
      'Accept':
          'application/rss+xml, application/atom+xml, application/xml;q=0.9, text/xml;q=0.9, text/html;q=0.8, */*;q=0.5',
      // Cabeceras HTTP sólo aceptan ASCII: cualquier acento rompe el
      // cliente con FormatException antes de abrir el socket. Usamos
      // un UA canónico de Chrome Mobile: YouTube devuelve 404 a UAs
      // con sintaxis inventada, y varios WP con WAF también bloquean
      // cualquier cosa que no parezca un navegador real.
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    }).timeout(_timeoutPorFeed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      debugPrint('[itemsDesdeSeed] ${fuente.name} HTTP ${resp.statusCode} (${fuente.feedUrl})');
      return const [];
    }
    final sintetica = FuentePersonal(
      nombre: fuente.name,
      feedUrl: fuente.feedUrl,
      tipoFeed: fuente.feedType,
      anadidaEn: DateTime.now().toUtc(),
    );
    final crudos = ParserFeedXml.parsear(resp.body, sintetica);
    // `ParserFeedXml` pone `source.id` a un hash del feedUrl (negativo).
    // Lo reemplazamos por el id del seed para poder enlazar con filtros.
    // Topics del item: heredados del source (curación editorial en el
    // seed). El parser RSS no los extrae por su cuenta, así que si el
    // usuario filtra por temática vía UI, esta heredancia es lo único
    // que hace que los items del seed respondan al filtro.
    final topicsHeredados = fuente.topics
        .map((slug) => Topic(id: 0, slug: slug, name: slug))
        .toList(growable: false);
    return crudos.map((it) {
      final source = it.source;
      if (source == null) return it;
      return it.copyWith(
        source: SourceSummary(
          id: fuente.id,
          slug: fuente.slug,
          name: fuente.name,
          websiteUrl: fuente.websiteUrl,
          url: fuente.websiteUrl,
          feedType: fuente.feedType,
        ),
        topics: topicsHeredados,
      );
    }).toList(growable: false);
  } on TimeoutException {
    debugPrint('[itemsDesdeSeed] ${fuente.name} TIMEOUT (${fuente.feedUrl})');
    return const [];
  } catch (e) {
    debugPrint('[itemsDesdeSeed] ${fuente.name} ERROR: $e (${fuente.feedUrl})');
    return const [];
  }
}
