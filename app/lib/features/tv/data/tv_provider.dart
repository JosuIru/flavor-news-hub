import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/item.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';

@immutable
class FiltrosTv {
  const FiltrosTv({
    this.slugsTopics = const [],
    this.codigosIdiomas = const [],
  });

  final List<String> slugsTopics;
  final List<String> codigosIdiomas;

  static const vacios = FiltrosTv();

  bool get estaVacio => slugsTopics.isEmpty && codigosIdiomas.isEmpty;

  FiltrosTv alternarTopic(String slug) {
    final nueva = slugsTopics.contains(slug)
        ? slugsTopics.where((s) => s != slug).toList()
        : [...slugsTopics, slug];
    return FiltrosTv(
      slugsTopics: nueva,
      codigosIdiomas: codigosIdiomas,
    );
  }

  FiltrosTv alternarIdioma(String codigo) {
    final nueva = codigosIdiomas.contains(codigo)
        ? codigosIdiomas.where((c) => c != codigo).toList()
        : [...codigosIdiomas, codigo];
    return FiltrosTv(
      slugsTopics: slugsTopics,
      codigosIdiomas: nueva,
    );
  }
}

final filtrosTvProvider = StateProvider<FiltrosTv>((_) => FiltrosTv.vacios);

/// Fuentes audiovisuales activas: TVs (tv_station) e instancias /
/// canales de vídeo (video). Conceptualmente la pestaña "TV" de la
/// app agrupa todo lo audiovisual, porque la frontera TV/vídeo
/// se ha desdibujado en la práctica y el usuario final no distingue.
/// Filtramos en cliente porque la API no expone el filtro por
/// medium_type (son pocas fuentes y el coste es despreciable).
///
/// Fallback por `feed_type`: una fuente de YouTube / PeerTube / vídeo
/// declarado es audiovisual aunque su `medium_type` aún no se haya
/// migrado (fuentes existentes en instancias actualizadas desde una
/// versión previa al campo medium_type se crean con default 'news').
final tvSourcesProvider = FutureProvider<List<Source>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final filtros = ref.watch(filtrosTvProvider);
  final pagina = await api.fetchSources(perPage: 100);
  const mediosAudiovisuales = {'tv_station', 'video'};
  const feedTypesAudiovisuales = {'youtube', 'video', 'peertube'};
  final fuentes = pagina.items.where((s) {
    if (!s.active) return false;
    return mediosAudiovisuales.contains(s.mediumType) ||
        feedTypesAudiovisuales.contains(s.feedType);
  }).toList();
  return fuentes.where((s) {
    if (filtros.slugsTopics.isNotEmpty) {
      final topics = s.topics.map((t) => t.slug).toSet();
      if (!topics.any(filtros.slugsTopics.contains)) {
        return false;
      }
    }
    if (filtros.codigosIdiomas.isNotEmpty) {
      final idiomas = s.languages.map((e) => e.toLowerCase()).toSet();
      if (!idiomas.any(filtros.codigosIdiomas.contains)) {
        return false;
      }
    }
    return true;
  }).toList();
});

/// Items recientes de cualquier fuente `tv_station`. Hacemos una
/// petición por fuente (son pocas) y mergemos ordenando por fecha.
/// Límite por fuente pequeño para no saturar la vista; el usuario
/// puede profundizar entrando al detalle del medio.
final tvItemsRecientesProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final sources = await ref.watch(tvSourcesProvider.future);
  if (sources.isEmpty) return const <Item>[];
  final api = ref.watch(flavorNewsApiProvider);
  final futuros = sources.map(
    (s) async {
      try {
        final pagina = await api.fetchItems(perPage: 6, source: s.id);
        return pagina.items;
      } on FlavorNewsApiException catch (_) {
        return const <Item>[];
      }
    },
  );
  final resultados = await Future.wait(futuros);
  final todos = <Item>[];
  for (final lista in resultados) {
    todos.addAll(lista);
  }
  // publishedAt es ISO 8601 como string: compareTo alfabético ordena
  // correctamente ASC; aquí queremos DESC, así que invertimos.
  todos.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  // Nos quedamos con los 30 más recientes agregados entre todas las
  // fuentes — suficiente para una pestaña sin paginado y manteniendo
  // señal editorial (no 200 entradas de la misma fuente).
  return todos.take(30).toList();
});
