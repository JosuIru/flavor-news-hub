import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../personal_sources/data/items_personales_provider.dart';

/// Filtros locales para la pantalla de vídeos. No se persisten entre sesiones:
/// es una exploración puntual, no un consumo recurrente.
@immutable
class FiltrosVideos {
  const FiltrosVideos({this.slugsTopics = const []});
  final List<String> slugsTopics;

  static const vacios = FiltrosVideos();
  bool get estaVacio => slugsTopics.isEmpty;

  FiltrosVideos alternarTopic(String slug) {
    final nueva = slugsTopics.contains(slug)
        ? slugsTopics.where((s) => s != slug).toList()
        : [...slugsTopics, slug];
    return FiltrosVideos(slugsTopics: nueva);
  }
}

final filtrosVideosProvider = StateProvider<FiltrosVideos>((ref) => FiltrosVideos.vacios);

/// Items tipo "vídeo" filtrados por `filtrosVideosProvider`.
///
/// Una sola petición al backend con `source_type=video,youtube`.
/// Fuentes personales tipo YouTube se añaden sólo si no hay filtros
/// (las personales no tienen topics en BD).
final videosProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final filtros = ref.watch(filtrosVideosProvider);
  final slugCsv = filtros.slugsTopics.isEmpty ? null : filtros.slugsTopics.join(',');

  final paginaBackend = await api.fetchItems(
    page: 1,
    perPage: 50,
    sourceType: 'video,youtube',
    topic: slugCsv,
  );

  final items = <Item>[...paginaBackend.items];
  if (filtros.estaVacio) {
    final personales = await ref.watch(itemsDeFuentesPersonalesProvider.future);
    items.addAll(personales.where((i) {
      final tipo = i.source?.feedType ?? '';
      return tipo == 'youtube' || tipo == 'video' || _tieneUrlDeVideo(i);
    }));
  }

  // Deduplicamos por id (backend positivos, personales negativos).
  final porId = <int, Item>{};
  for (final it in items) {
    porId[it.id] = it;
  }
  final combinados = porId.values.toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return combinados;
});

bool _tieneUrlDeVideo(Item item) {
  final url = item.originalUrl.toLowerCase();
  if (url.isEmpty) return false;
  return url.contains('youtube.com') ||
      url.contains('youtu.be') ||
      url.contains('vimeo.com') ||
      url.contains('peertube') ||
      url.endsWith('.mp4');
}
