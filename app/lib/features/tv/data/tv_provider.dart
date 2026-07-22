import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/models/item.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/filtro_idioma_contenido.dart';
import '../../../core/utils/territory_scoring.dart';

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
  // Derivamos del catálogo completo que `sourcesProvider` ya descarga y
  // cachea (lo comparten Fuentes y Podcasts). Antes esta pestaña volvía a
  // paginar TODO el catálogo por su cuenta —descarga duplicada— y, peor,
  // como observa los filtros transversales/idioma, cada toque de un chip
  // re-descargaba las fuentes enteras. Ahora el fetch es único y cacheado;
  // aquí sólo filtramos en cliente (audiovisual + topics/idioma), que es
  // barato y ya se hacía así.
  final catalogo = await ref.watch(sourcesProvider.future);
  final transversal = ref.watch(filtrosTransversalesProvider);
  final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);
  const mediosAudiovisuales = {'tv_station', 'video'};
  const feedTypesAudiovisuales = {'youtube', 'video', 'peertube'};
  final fuentes = catalogo.items.where((s) {
    if (!s.active) return false;
    return mediosAudiovisuales.contains(s.mediumType) ||
        feedTypesAudiovisuales.contains(s.feedType);
  }).toList();
  return fuentes.where((s) {
    if (transversal.tieneTopics) {
      final topics = s.topics.map((t) => t.slug).toSet();
      if (!topics.any(transversal.slugsTopics.contains)) {
        return false;
      }
    }
    if (idiomasEfectivos.isNotEmpty) {
      final idiomas = s.languages.map((e) => e.toLowerCase()).toSet();
      if (!idiomas.any(idiomasEfectivos.contains)) {
        return false;
      }
    }
    return true;
  }).toList();
});

/// Items recientes de cualquier fuente audiovisual.
///
/// Una sola pareja de peticiones al backend en lugar de N (una por
/// fuente): el `feed_type` (youtube/video/peertube) cubre los canales
/// que distribuyen exclusivamente vídeo aunque su `medium_type` siga
/// siendo el default 'news', y el `medium_type` (tv_station/video)
/// cubre las TVs cuyo feed técnico es RSS de texto pero
/// conceptualmente son audiovisuales. Ambos filtros son AND en el
/// endpoint, así que los pedimos por separado y unimos en cliente.
/// Antes esto disparaba 77 peticiones en paralelo y el rate-limiter
/// del hosting respondía 429 además de ser muy lento.
final tvItemsRecientesProvider =
    FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final transversal = ref.watch(filtrosTransversalesProvider);
  final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);
  final idiomasCsv =
      idiomasEfectivos.isEmpty ? null : idiomasEfectivos.join(',');
  final topicsCsv = transversal.topicsParaQueryParam;

  Future<List<Item>> pedir({String? sourceType, String? mediumType}) async {
    try {
      final pagina = await api.fetchItems(
        perPage: 50,
        sourceType: sourceType,
        mediumType: mediumType,
        language: idiomasCsv,
        topic: topicsCsv,
      );
      return pagina.items;
    } on FlavorNewsApiException catch (_) {
      return const <Item>[];
    }
  }

  final resultados = await Future.wait([
    pedir(sourceType: 'youtube,video,peertube'),
    pedir(mediumType: 'tv_station,video'),
  ]);
  final porId = <int, Item>{};
  for (final lista in resultados) {
    for (final item in lista) {
      porId[item.id] = item;
    }
  }
  final todos = porId.values.toList();
  // Orden: local-primero si el usuario fijó "Mi territorio"; sin él,
  // equivale a publishedAt desc. `ordenarItemsLocalPrimero` gestiona
  // los dos casos y maneja internamente el parseo ISO 8601.
  final territorioBase = ref.read(
    preferenciasProvider.select((p) => p.territorioBase),
  );
  ordenarItemsLocalPrimero(todos, territorioBase);
  // Filtro defensivo: descarta items con título dominantemente
  // no-latino cuando los idiomas efectivos son todos latinos. Sirve
  // para items legacy de feeds mal etiquetados (caso histórico:
  // Al Mayadeen Español apuntando al canal árabe antes de v0.9.54;
  // los items ya ingestados quedan en BD bajo un source que ahora
  // declara `es` y se colaban en la pestaña TV).
  final filtrados = filtrarContenidoNoLatino(todos, idiomasEfectivos);
  // Nos quedamos con los 30 más recientes agregados entre todas las
  // fuentes — suficiente para una pestaña sin paginado y manteniendo
  // señal editorial (no 200 entradas de la misma fuente).
  return filtrados.take(30).toList();
});
