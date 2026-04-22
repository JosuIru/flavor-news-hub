import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/collective.dart';
import '../../../core/models/item.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import '../../offline_seed/data/seed_loader.dart';

/// Consulta activa del buscador. Vacía = no hay búsqueda en curso.
/// La pantalla la actualiza con debounce (300ms) para no saturar el backend
/// en cada pulsación de tecla.
final consultaBusquedaProvider = StateProvider<String>((_) => '');

class ResultadosBusqueda {
  const ResultadosBusqueda({
    required this.items,
    required this.sources,
    required this.radios,
    required this.colectivos,
  });
  final List<Item> items;
  final List<Source> sources;
  final List<modelo_radio.Radio> radios;
  final List<Collective> colectivos;

  bool get estaVacio =>
      items.isEmpty && sources.isEmpty && radios.isEmpty && colectivos.isEmpty;

  static const ResultadosBusqueda vacio = ResultadosBusqueda(
    items: [],
    sources: [],
    radios: [],
    colectivos: [],
  );
}

/// Dispara 4 peticiones paralelas a /items, /sources, /radios y /collectives
/// con el mismo parámetro `s`. Cada una trae pocos resultados (10 máx).
///
/// Fallback offline: si la API da error de red (backend caído), buscamos
/// en los datos locales — cache SQLite de items y seed de sources/radios
/// /colectivos. Búsqueda naive case-insensitive `contains` sobre nombre
/// y título; suficiente para que el buscador no aparezca roto offline.
final resultadosBusquedaProvider =
    FutureProvider.autoDispose<ResultadosBusqueda>((ref) async {
  final consulta = ref.watch(consultaBusquedaProvider).trim();
  if (consulta.length < 2) {
    return ResultadosBusqueda.vacio;
  }
  final api = ref.watch(flavorNewsApiProvider);
  final minuscula = consulta.toLowerCase();

  bool esError(dynamic e) => e is FlavorNewsApiException && e.esProblemaRed;

  Future<List<Item>> buscarItems() async {
    try {
      final pag = await api.fetchItems(perPage: 10, search: consulta);
      return pag.items;
    } catch (e) {
      if (!esError(e)) return const [];
      // Fallback offline: buscamos en el cache SQLite (lo que ya se
      // había visto) y también en el stream del seed RSS en vivo
      // (titulares frescos del minuto, si el dispositivo tiene red
      // aunque el backend esté caído). Los unimos deduplicando por id.
      final dao = await ref.watch(itemsLocalesDaoProvider.future);
      final cache = await dao.obtenerCache(limite: 500);
      final estadoSeed = ref.watch(itemsDesdeSeedProvider);
      final delSeed = estadoSeed.valueOrNull ?? const <Item>[];
      final idsSeed = delSeed.map((i) => i.id).toSet();
      final unidos = [
        ...delSeed,
        ...cache.where((i) => !idsSeed.contains(i.id)),
      ];
      return unidos
          .where((it) =>
              it.title.toLowerCase().contains(minuscula) ||
              it.excerpt.toLowerCase().contains(minuscula))
          .take(20)
          .toList();
    }
  }

  Future<List<Source>> buscarSources() async {
    try {
      final pag = await api.fetchSources(perPage: 10, search: consulta);
      return pag.items;
    } catch (e) {
      if (!esError(e)) return const [];
      final fuentesSeed = await ref.watch(sourcesSeedProvider.future);
      return fuentesSeed
          .where((s) => s.name.toLowerCase().contains(minuscula))
          .take(10)
          .toList();
    }
  }

  Future<List<modelo_radio.Radio>> buscarRadios() async {
    try {
      return await api.fetchRadios(search: consulta);
    } catch (e) {
      if (!esError(e)) return const [];
      final radios = await ref.watch(radiosSeedProvider.future);
      return radios
          .where((r) => r.name.toLowerCase().contains(minuscula))
          .take(10)
          .toList();
    }
  }

  Future<List<Collective>> buscarColectivos() async {
    try {
      final pag = await api.fetchCollectives(perPage: 10, search: consulta);
      return pag.items;
    } catch (e) {
      if (!esError(e)) return const [];
      final colectivos = await ref.watch(colectivosSeedProvider.future);
      return colectivos
          .where((c) =>
              c.name.toLowerCase().contains(minuscula) ||
              c.description.toLowerCase().contains(minuscula))
          .take(10)
          .toList();
    }
  }

  final resultados = await Future.wait<dynamic>([
    buscarItems(),
    buscarSources(),
    buscarRadios(),
    buscarColectivos(),
  ]);

  return ResultadosBusqueda(
    items: resultados[0] as List<Item>,
    sources: resultados[1] as List<Source>,
    radios: resultados[2] as List<modelo_radio.Radio>,
    colectivos: resultados[3] as List<Collective>,
  );
});
