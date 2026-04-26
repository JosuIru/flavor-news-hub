import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/item.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/utils/normalizacion_texto.dart';
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
/// Fallback offline: si la API falla (red caída, 5xx, JSON corrupto…) caemos
/// al cache local — items en SQLite y seeds bundleados de sources/radios/
/// colectivos. Búsqueda naive case-insensitive `contains` sobre nombre y
/// título. Antes filtrábamos sólo errores de red; eso dejaba al usuario sin
/// resultados cuando el backend devolvía 500 (falso "no hay nada"). Ahora
/// cualquier excepción cae al fallback y dejamos rastro en `debugPrint`.
final resultadosBusquedaProvider =
    FutureProvider.autoDispose<ResultadosBusqueda>((ref) async {
  final consulta = ref.watch(consultaBusquedaProvider).trim();
  if (consulta.length < 2) {
    return ResultadosBusqueda.vacio;
  }
  final api = ref.watch(flavorNewsApiProvider);
  // Normalizamos sin diacríticos para que el fallback offline encuentre
  // "Cataluña" buscando "cataluna" y "Bilbó" buscando "bilbo". El
  // online (`search:` al backend) sigue su propia política de WP.
  final consultaNormalizada = normalizarParaBusqueda(consulta);
  bool coincide(String texto) =>
      normalizarParaBusqueda(texto).contains(consultaNormalizada);

  Future<List<Item>> buscarItems() async {
    try {
      final pag = await api.fetchItems(perPage: 10, search: consulta);
      return pag.items;
    } catch (error) {
      debugPrint('[Buscador] /items falló, fallback local: $error');
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
          .where((it) => coincide(it.title) || coincide(it.excerpt))
          .take(20)
          .toList();
    }
  }

  Future<List<Source>> buscarSources() async {
    try {
      final pag = await api.fetchSources(perPage: 10, search: consulta);
      return pag.items;
    } catch (error) {
      debugPrint('[Buscador] /sources falló, fallback seed: $error');
      final fuentesSeed = await ref.watch(sourcesSeedProvider.future);
      // Alineado con `s=` del backend: nombre + descripción (post_content).
      // Añadimos también territorio como desempate útil ("¿qué medios
      // hay en Bizkaia?" se resuelve sin red).
      return fuentesSeed
          .where((s) =>
              coincide(s.name) ||
              coincide(s.description) ||
              coincide(s.territory))
          .take(10)
          .toList();
    }
  }

  Future<List<modelo_radio.Radio>> buscarRadios() async {
    try {
      return await api.fetchRadios(search: consulta);
    } catch (error) {
      debugPrint('[Buscador] /radios falló, fallback seed: $error');
      final radios = await ref.watch(radiosSeedProvider.future);
      return radios
          .where((r) =>
              coincide(r.name) ||
              coincide(r.description) ||
              coincide(r.territory))
          .take(10)
          .toList();
    }
  }

  Future<List<Collective>> buscarColectivos() async {
    try {
      final pag = await api.fetchCollectives(perPage: 10, search: consulta);
      return pag.items;
    } catch (error) {
      debugPrint('[Buscador] /collectives falló, fallback seed: $error');
      final colectivos = await ref.watch(colectivosSeedProvider.future);
      return colectivos
          .where((c) => coincide(c.name) || coincide(c.description))
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
