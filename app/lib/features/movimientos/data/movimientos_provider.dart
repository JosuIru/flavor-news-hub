import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/idioma_contenido/politica_idioma_contenido.dart';
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
final feedMovimientosProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final idiomasContenido = ref.watch(idiomasContenidoEfectivosProvider);
  final territorioBase = ref.watch(
    preferenciasProvider.select((p) => p.territorioBase),
  );

  try {
    final pagina = await api.fetchItems(
      page: 1,
      perPage: 50,
      esMovimiento: true,
      language: idiomasContenido.isEmpty ? null : idiomasContenido.join(','),
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
    return filtrarContenidoNoLatino(items, idiomasContenido);
  } on FlavorNewsApiException {
    return const <Item>[];
  }
});
