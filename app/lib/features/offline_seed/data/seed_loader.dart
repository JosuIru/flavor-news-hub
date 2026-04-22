import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/models/source.dart';
import '../../../core/models/source_summary.dart';
import '../../../core/models/topic.dart';
import 'seed_cache.dart';

/// Entrada del seed de fuentes — versión reducida de `Source` con sólo los
/// campos que el cliente necesita para hacer ingesta directa de RSS.
class FuenteSeed {
  const FuenteSeed({
    required this.id,
    required this.name,
    required this.slug,
    required this.feedUrl,
    required this.feedType,
    required this.websiteUrl,
    required this.territory,
    required this.languages,
    this.topics = const [],
  });
  final int id;
  final String name;
  final String slug;
  final String feedUrl;
  final String feedType;
  final String websiteUrl;
  final String territory;
  final List<String> languages;
  /// Slugs de las temáticas que cubre este medio (curación editorial
  /// de la instancia). Los items descargados de su RSS heredan estos
  /// topics — es una aproximación: las noticias de un medio generalista
  /// ("El Salto") se etiquetan con los varios topics que cubre, no con
  /// el topic específico de cada artículo. Es ruidoso pero permite que
  /// el filtro por temática funcione offline.
  final List<String> topics;

  /// Representación plana como `SourceSummary` para poder reutilizarla con
  /// los `Item` que ya trae el backend.
  SourceSummary aSourceSummary() => SourceSummary(
        id: id,
        slug: slug,
        name: name,
        websiteUrl: websiteUrl,
        url: websiteUrl,
        feedType: feedType,
      );
}

/// Carga de una vez los seeds embebidos en los assets del APK. Se expone
/// como `FutureProvider` singleton — no cambia en tiempo de ejecución.
final fuentesSeedProvider = FutureProvider<List<FuenteSeed>>((ref) async {
  final lista = await _cargarListaConCache('sources.json');
  return lista.whereType<Map<String, dynamic>>().map(_leerFuente).toList(growable: false);
});

/// Versión "completa" de las fuentes desde el seed: mismo fichero que
/// `fuentesSeedProvider` pero mapeado al modelo `Source` para que el
/// directorio de medios pueda renderizarlas igual que las del backend.
/// Los campos que el seed no trae (description, ownership, editorial_note…)
/// quedan vacíos — el seed sólo expone lo imprescindible.
final sourcesSeedProvider = FutureProvider<List<Source>>((ref) async {
  final lista = await _cargarListaConCache('sources.json');
  return lista
      .whereType<Map<String, dynamic>>()
      .map(Source.fromJson)
      .toList(growable: false);
});

/// Intenta leer del cache en disco (catálogo fresco guardado la última vez
/// que el backend respondió). Si no existe, cae al asset bundleado.
Future<List<dynamic>> _cargarListaConCache(String nombre) async {
  final disco = await SeedCache.leer(nombre);
  if (disco != null && disco.isNotEmpty) return disco;
  final bruto = await rootBundle.loadString('assets/seed/$nombre');
  final decodificado = jsonDecode(bruto);
  return decodificado is List ? decodificado : const [];
}

FuenteSeed _leerFuente(Map<String, dynamic> raw) {
  return FuenteSeed(
    id: (raw['id'] is int) ? raw['id'] as int : int.tryParse('${raw['id']}') ?? 0,
    name: (raw['name'] ?? '').toString(),
    slug: (raw['slug'] ?? '').toString(),
    feedUrl: (raw['feed_url'] ?? '').toString(),
    feedType: (raw['feed_type'] ?? 'rss').toString(),
    websiteUrl: (raw['website_url'] ?? '').toString(),
    territory: (raw['territory'] ?? '').toString(),
    languages: (raw['languages'] is List)
        ? (raw['languages'] as List).map((e) => e.toString()).toList()
        : const [],
    topics: _leerTopicsSlugs(raw['topics']),
  );
}

/// Acepta tanto lista de slugs (`["vivienda"]`) como lista de objetos
/// (`[{"slug":"vivienda"}]`) para que el mismo seed sirva si lo exporta
/// el script o lo edita un humano a mano.
List<String> _leerTopicsSlugs(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final el in raw) {
    if (el is String && el.isNotEmpty) {
      out.add(el);
    } else if (el is Map<String, dynamic>) {
      final slug = (el['slug'] ?? '').toString();
      if (slug.isNotEmpty) out.add(slug);
    }
  }
  return out;
}

/// Radios seedadas para modo autónomo. Cargadas una vez; cada entrada se
/// mapea al modelo `Radio` para que la pantalla las renderice igual que
/// las que vienen del backend.
final radiosSeedProvider = FutureProvider<List<modelo_radio.Radio>>((ref) async {
  final lista = await _cargarListaConCache('radios.json');
  return lista.whereType<Map<String, dynamic>>().map(_leerRadio).toList(growable: false);
});

modelo_radio.Radio _leerRadio(Map<String, dynamic> raw) {
  return modelo_radio.Radio(
    id: (raw['id'] is int) ? raw['id'] as int : int.tryParse('${raw['id']}') ?? 0,
    slug: (raw['slug'] ?? '').toString(),
    name: (raw['name'] ?? '').toString(),
    streamUrl: (raw['stream_url'] ?? '').toString(),
    websiteUrl: (raw['website_url'] ?? '').toString(),
    rssUrl: (raw['rss_url'] ?? '').toString(),
    territory: (raw['territory'] ?? '').toString(),
    languages: (raw['languages'] is List)
        ? (raw['languages'] as List).map((e) => e.toString()).toList()
        : const [],
  );
}

/// Directorio de colectivos seedado. Son datos curados que no cambian a
/// diario; mantenerlos embebidos evita que la pestaña "Colectivos" quede
/// vacía si el backend no responde.
final colectivosSeedProvider = FutureProvider<List<Collective>>((ref) async {
  final lista = await _cargarListaConCache('collectives.json');
  return lista.whereType<Map<String, dynamic>>().map(_leerColectivo).toList(growable: false);
});

Collective _leerColectivo(Map<String, dynamic> raw) {
  final topicsRaw = raw['topics'];
  final topics = <Topic>[];
  if (topicsRaw is List) {
    for (final t in topicsRaw) {
      if (t is Map<String, dynamic>) {
        topics.add(Topic(
          id: (t['id'] is int) ? t['id'] as int : int.tryParse('${t['id']}') ?? 0,
          name: (t['name'] ?? '').toString(),
          slug: (t['slug'] ?? '').toString(),
        ));
      }
    }
  }
  return Collective(
    id: (raw['id'] is int) ? raw['id'] as int : int.tryParse('${raw['id']}') ?? 0,
    slug: (raw['slug'] ?? '').toString(),
    name: (raw['name'] ?? '').toString(),
    description: (raw['description'] ?? '').toString(),
    url: (raw['url'] ?? '').toString(),
    websiteUrl: (raw['website_url'] ?? '').toString(),
    flavorUrl: (raw['flavor_url'] ?? '').toString(),
    territory: (raw['territory'] ?? '').toString(),
    hasContact: raw['has_contact'] == true,
    verified: raw['verified'] != false,
    topics: topics,
  );
}
