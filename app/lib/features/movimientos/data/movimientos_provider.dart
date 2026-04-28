import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/filtro_idioma_contenido.dart';
import '../../../core/utils/territory_scoring.dart';

/// Items de fuentes marcadas como "voz de movimiento": medios
/// pequeños/militantes y colectivos cuyo contenido queda tapado en el
/// feed general por agregadores prolíficos. Sección dedicada para que
/// puedan oírse sin competir por atención con MakerTube y similares.
///
/// Llama a `/items?es_movimiento=1`. El backend resuelve qué sources
/// tienen `_fnh_es_movimiento=1` y filtra los items por su source_id.
/// Aplica los filtros transversales (topics + territorio + idiomas)
/// igual que el feed principal — antes ignoraba topics y territorio,
/// lo que la dejaba como un feed "todo o nada" sin posibilidad de
/// foco en una temática o geografía concreta.
final feedMovimientosProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final transversal = ref.watch(filtrosTransversalesProvider);
  final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);
  final territorioBase = ref.watch(
    preferenciasProvider.select((p) => p.territorioBase),
  );

  // No silenciamos `FlavorNewsApiException`: cuando el endpoint falla
  // (timeout, 500, parse mal) la pantalla mostraba "no hay noticias"
  // en lugar de un error real, dejando al usuario sin pista de qué va
  // mal. Mejor que el AsyncValue.error fluya hasta la UI.
  final pagina = await api.fetchItems(
    page: 1,
    perPage: 50,
    esMovimiento: true,
    topic: transversal.topicsParaQueryParam,
    territory: transversal.codigoTerritorio,
    language: idiomasEfectivos.isEmpty ? null : idiomasEfectivos.join(','),
    // El feed de titulares principal excluye vídeos/podcasts (van en
    // sus pestañas dedicadas). Aquí también — la sección Movimientos
    // es para texto principalmente. Si un colectivo hace YouTube o
    // podcast, sus items aparecen en sus pestañas correspondientes.
    excludeSourceType: 'video,youtube,podcast',
  );
  final items = [...pagina.items];
  // Aplicamos los mismos saneos que el feed principal: ordenación
  // local-primero y filtro defensivo de contenido no-latino.
  ordenarItemsLocalPrimero(items, territorioBase);
  return filtrarContenidoNoLatino(items, idiomasEfectivos);
});
