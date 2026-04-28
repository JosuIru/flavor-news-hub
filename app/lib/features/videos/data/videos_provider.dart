import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/models/item.dart';
import '../../../core/models/paginated_list.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/filtro_idioma_contenido.dart';
import '../../../core/utils/territory_scoring.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import '../../personal_sources/data/items_personales_provider.dart';

/// Filtro local de Vídeos para "ver sólo este canal". Topics e idiomas
/// se leen del provider transversal (compartidos entre Feed/Vídeos/TV/
/// Podcasts). El filtro de canal es propio porque conceptualmente es
/// un atajo de navegación ("vídeos del canal X"), no un eje compartido.
final videosSourceFilterProvider = StateProvider<int?>((_) => null);

/// Items tipo "vídeo" filtrados por el provider transversal y el
/// `videosSourceFilterProvider` local.
///
/// Una sola petición al backend con `source_type=video,youtube`.
/// Fuentes personales tipo YouTube se añaden sólo si no hay filtros
/// (las personales no tienen topics en BD).
final videosProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final transversal = ref.watch(filtrosTransversalesProvider);
  final idSource = ref.watch(videosSourceFilterProvider);
  final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);
  final slugCsv = transversal.topicsParaQueryParam;
  final idiomasCsv =
      idiomasEfectivos.isEmpty ? null : idiomasEfectivos.join(',');

  PaginatedList<Item>? paginaBackend;
  final itemsDelSeed = <Item>[];
  bool fallbackAlSeed = false;
  try {
    // Si el usuario pidió un canal concreto, no restringimos por
    // `source_type` — él ya eligió qué fuente ver y el tipo de feed
    // es irrelevante para "ver los últimos items de este medio". Sin
    // este relajo, un canal PeerTube con feed_type=rss se quedaba sin
    // resultados porque `video,youtube` lo excluía.
    paginaBackend = await api.fetchItems(
      page: 1,
      perPage: 50,
      sourceType: idSource == null ? 'video,youtube' : null,
      topic: slugCsv,
      source: idSource,
      language: idiomasCsv,
    );
    // Si el backend no conoce el source pedido (p. ej. canales YouTube
    // que sólo existen en el seed bundleado del APK), devuelve vacío —
    // en ese caso complementamos con los items del seed.
    if (paginaBackend.items.isEmpty && idSource != null) {
      fallbackAlSeed = true;
    }
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    fallbackAlSeed = true;
  }

  if (fallbackAlSeed) {
    try {
      final todosDelSeed = await ref.watch(itemsDesdeSeedProvider.future);
      itemsDelSeed.addAll(todosDelSeed.where(_esItemDeVideo));
    } catch (_) {
      // Seed también falla → seguimos con vacío.
    }
  }

  // Filtro offline: source + topic + idioma sobre los items del seed
  // (el backend ya los aplicó en su query; aquí replicamos para que el
  // comportamiento sea coherente cuando caemos al seed).
  final topicsActivos = transversal.slugsTopics.toSet();

  bool passaFiltrosSeed(Item i) {
    if (idSource != null && i.source?.id != idSource) {
      return false;
    }
    // Topic: estricto si el item trae topics (heredados del source);
    // permisivo si viene sin topics — evita vaciar la lista cuando el
    // seed aún no está curado con topics.
    if (topicsActivos.isNotEmpty && i.topics.isNotEmpty) {
      final slugsItem = i.topics.map((t) => t.slug).toSet();
      if (!slugsItem.any(topicsActivos.contains)) return false;
    }
    return true;
  }

  final items = <Item>[
    if (paginaBackend != null) ...paginaBackend.items,
    ...itemsDelSeed.where(passaFiltrosSeed),
  ];
  // Sin filtros activos (transversal + source) añadimos también los
  // canales personales tipo vídeo, igual que hacía el provider antiguo.
  if (transversal.estaVacio && idSource == null) {
    final personales = await ref.watch(itemsDeFuentesPersonalesProvider.future);
    items.addAll(personales.where(_esItemDeVideo));
  }

  // Deduplicamos por id (backend positivos, personales negativos).
  final porId = <int, Item>{};
  for (final it in items) {
    porId[it.id] = it;
  }
  final combinados = porId.values.toList();
  final territorioBase = ref.read(
    preferenciasProvider.select((p) => p.territorioBase),
  );
  ordenarItemsLocalPrimero(combinados, territorioBase);
  // Defensa contra contenido legacy de feeds mal etiquetados
  // (canales que decían `es` pero servían árabe/cirílico/etc).
  return filtrarContenidoNoLatino(combinados, idiomasEfectivos);
});

bool _esItemDeVideo(Item item) {
  final tipo = item.source?.feedType ?? '';
  if (tipo == 'youtube' || tipo == 'video') return true;
  return _tieneUrlDeVideo(item);
}

bool _tieneUrlDeVideo(Item item) {
  final url = item.originalUrl.toLowerCase();
  if (url.isEmpty) return false;
  return url.contains('youtube.com') ||
      url.contains('youtu.be') ||
      url.contains('vimeo.com') ||
      url.contains('peertube') ||
      url.endsWith('.mp4');
}
