import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/item.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';

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
/// Si una sección falla aisladamente, las otras no arrastran el error.
final resultadosBusquedaProvider =
    FutureProvider.autoDispose<ResultadosBusqueda>((ref) async {
  final consulta = ref.watch(consultaBusquedaProvider).trim();
  if (consulta.length < 2) {
    return ResultadosBusqueda.vacio;
  }
  final api = ref.watch(flavorNewsApiProvider);

  Future<List<Item>> buscarItems() async {
    try {
      final pag = await api.fetchItems(perPage: 10, search: consulta);
      return pag.items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Source>> buscarSources() async {
    try {
      final pag = await api.fetchSources(perPage: 10, search: consulta);
      return pag.items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<modelo_radio.Radio>> buscarRadios() async {
    try {
      return await api.fetchRadios(search: consulta);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Collective>> buscarColectivos() async {
    try {
      final pag = await api.fetchCollectives(perPage: 10, search: consulta);
      return pag.items;
    } catch (_) {
      return const [];
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
