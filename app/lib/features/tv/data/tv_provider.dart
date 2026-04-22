import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/item.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';

/// Fuentes audiovisuales activas: TVs (tv_station) e instancias /
/// canales de vídeo (video). Conceptualmente la pestaña "TV" de la
/// app agrupa todo lo audiovisual, porque la frontera TV/vídeo
/// se ha desdibujado en la práctica y el usuario final no distingue.
/// Filtramos en cliente porque la API no expone el filtro por
/// medium_type (son pocas fuentes y el coste es despreciable).
final tvSourcesProvider = FutureProvider<List<Source>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final pagina = await api.fetchSources(perPage: 100);
  const mediosAudiovisuales = {'tv_station', 'video'};
  return pagina.items
      .where((s) => mediosAudiovisuales.contains(s.mediumType) && s.active)
      .toList();
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
