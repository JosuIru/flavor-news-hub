import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/idioma_contenido/politica_idioma_contenido.dart';
import '../../../core/models/item.dart';
import '../../../core/models/paginated_list.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/territory_scoring.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import '../../personal_sources/data/items_personales_provider.dart';

/// Filtros locales para la pantalla de vídeos. No se persisten entre sesiones:
/// es una exploración puntual, no un consumo recurrente.
@immutable
class FiltrosVideos {
  const FiltrosVideos({
    this.slugsTopics = const [],
    this.codigosIdiomas = const [],
    this.idSource,
  });
  final List<String> slugsTopics;
  final List<String> codigosIdiomas;
  final int? idSource;

  static const vacios = FiltrosVideos();
  bool get estaVacio =>
      slugsTopics.isEmpty && codigosIdiomas.isEmpty && idSource == null;

  FiltrosVideos alternarTopic(String slug) {
    final nueva = slugsTopics.contains(slug)
        ? slugsTopics.where((s) => s != slug).toList()
        : [...slugsTopics, slug];
    return FiltrosVideos(
      slugsTopics: nueva,
      codigosIdiomas: codigosIdiomas,
      idSource: idSource,
    );
  }

  FiltrosVideos alternarIdioma(String codigo) {
    final nueva = codigosIdiomas.contains(codigo)
        ? codigosIdiomas.where((c) => c != codigo).toList()
        : [...codigosIdiomas, codigo];
    return FiltrosVideos(
      slugsTopics: slugsTopics,
      codigosIdiomas: nueva,
      idSource: idSource,
    );
  }

  FiltrosVideos conSource(int? id) {
    return FiltrosVideos(
      slugsTopics: slugsTopics,
      codigosIdiomas: codigosIdiomas,
      idSource: id,
    );
  }
}

/// Filtros locales por pestaña — ahora arrancan vacíos. El idioma de
/// contenido por defecto se calcula desde
/// `idiomasContenidoEfectivosProvider`. Si el usuario marca chips en
/// el bottom sheet de filtros, eso actúa como override por pestaña.
final filtrosVideosProvider =
    StateProvider<FiltrosVideos>((_) => FiltrosVideos.vacios);

/// Items tipo "vídeo" filtrados por `filtrosVideosProvider`.
///
/// Una sola petición al backend con `source_type=video,youtube`.
/// Fuentes personales tipo YouTube se añaden sólo si no hay filtros
/// (las personales no tienen topics en BD).
final videosProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final filtros = ref.watch(filtrosVideosProvider);
  final slugCsv = filtros.slugsTopics.isEmpty ? null : filtros.slugsTopics.join(',');

  PaginatedList<Item>? paginaBackend;
  final itemsDelSeed = <Item>[];
  bool fallbackAlSeed = false;
  try {
    // Override por pestaña > política central. Sin override, la
    // política central decide si se filtra y por qué idiomas.
    final idiomasContenido = ref.watch(idiomasContenidoEfectivosProvider);
    final idiomasEfectivos = filtros.codigosIdiomas.isNotEmpty
        ? filtros.codigosIdiomas
        : idiomasContenido;
    final idiomasCsv = idiomasEfectivos.isEmpty ? null : idiomasEfectivos.join(',');
    // Si el usuario pidió un canal concreto, no restringimos por
    // `source_type` — él ya eligió qué fuente ver y el tipo de feed
    // es irrelevante para "ver los últimos items de este medio". Sin
    // este relajo, un canal PeerTube con feed_type=rss se quedaba sin
    // resultados porque `video,youtube` lo excluía.
    paginaBackend = await api.fetchItems(
      page: 1,
      perPage: 50,
      sourceType: filtros.idSource == null ? 'video,youtube' : null,
      topic: slugCsv,
      source: filtros.idSource,
      language: idiomasCsv,
    );
    // Si el backend no conoce el source pedido (p. ej. canales YouTube
    // que sólo existen en el seed bundleado del APK), devuelve vacío —
    // en ese caso complementamos con los items del seed.
    if (paginaBackend.items.isEmpty && filtros.idSource != null) {
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
  final idSourceFiltrada = filtros.idSource;
  final topicsActivos = filtros.slugsTopics.toSet();

  bool passaFiltrosSeed(Item i) {
    if (idSourceFiltrada != null && i.source?.id != idSourceFiltrada) {
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
  if (filtros.estaVacio) {
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
  return combinados;
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
