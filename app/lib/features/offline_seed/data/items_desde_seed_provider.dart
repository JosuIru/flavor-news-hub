import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/item.dart';
import '../../../core/models/source_summary.dart';
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
const int _maxConcurrentes = 6;
const Duration _timeoutPorFeed = Duration(seconds: 12);

final itemsDesdeSeedProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final fuentes = await ref.watch(fuentesSeedProvider.future);
  final rsss = fuentes.where((f) {
    // Sólo tipos que sabemos que `ParserFeedXml` maneja bien.
    return f.feedType == 'rss' || f.feedType == 'atom' || f.feedType == 'podcast';
  }).toList();
  if (rsss.isEmpty) return const [];

  final http.Client httpClient = ref.watch(httpClientProvider);
  final items = <Item>[];

  // Batching simple para limitar concurrencia.
  for (var i = 0; i < rsss.length; i += _maxConcurrentes) {
    final chunk = rsss.sublist(i, (i + _maxConcurrentes).clamp(0, rsss.length));
    final futuros = chunk.map((fuente) => _traerUna(httpClient, fuente));
    final listas = await Future.wait(futuros);
    for (final lista in listas) {
      items.addAll(lista);
    }
  }

  items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return items;
});

Future<List<Item>> _traerUna(http.Client cliente, FuenteSeed fuente) async {
  final uri = Uri.tryParse(fuente.feedUrl);
  if (uri == null) return const [];
  try {
    final resp = await cliente.get(uri, headers: const {
      'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
      'User-Agent': 'FlavorNewsHub/1.0 (modo autónomo)',
    }).timeout(_timeoutPorFeed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
    final sintetica = FuentePersonal(
      nombre: fuente.name,
      feedUrl: fuente.feedUrl,
      tipoFeed: fuente.feedType,
      anadidaEn: DateTime.now().toUtc(),
    );
    final crudos = ParserFeedXml.parsear(resp.body, sintetica);
    // `ParserFeedXml` pone `source.id` a un hash del feedUrl (negativo).
    // Lo reemplazamos por el id del seed para poder enlazar con filtros.
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
      );
    }).toList(growable: false);
  } on TimeoutException {
    return const [];
  } catch (_) {
    return const [];
  }
}
