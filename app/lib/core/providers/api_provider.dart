import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/history/data/historial_provider.dart';
import '../../features/offline_seed/data/seed_cache.dart';
import '../../features/offline_seed/data/seed_loader.dart';
import '../api/api_exception.dart';
import '../api/flavor_news_api.dart';
import '../models/item.dart';
import '../models/paginated_list.dart';
import '../models/radio.dart' as modelo_radio;
import '../models/source.dart';
import '../models/topic.dart';
import 'preferences_provider.dart';

/// Cliente HTTP compartido. Se cierra cuando el provider se descarta.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// `FlavorNewsApi` reactivo a la URL de instancia configurada por el usuario.
/// Al cambiar esa preferencia, Riverpod reconstruye el cliente y los
/// providers dependientes (items, sources, collectives...) se invalidan
/// automáticamente.
final flavorNewsApiProvider = Provider<FlavorNewsApi>((ref) {
  final urlGuardada = ref.watch(
    preferenciasProvider.select((prefs) => prefs.urlInstanciaBackend),
  );
  final cliente = ref.watch(httpClientProvider);
  final urlNormalizada = urlGuardada.endsWith('/') ? urlGuardada : '$urlGuardada/';
  return FlavorNewsApi(
    baseUrl: Uri.parse(urlNormalizada),
    httpClient: cliente,
  );
});

/// Primera página del feed. Se auto-dispara al subscribirse y se auto-dispone
/// al cerrar la pantalla. Capa 11 añadirá scroll infinito / paginado.
final itemsFeedProvider = FutureProvider.autoDispose<PaginatedList<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  return api.fetchItems();
});

/// Árbol de temáticas. Sólo cambian cuando el admin añade/edita una; casi
/// estático. Cacheamos hasta que alguien invalide explícitamente.
///
/// Si el backend no responde, derivamos la lista de temáticas a partir
/// de los items que ya tenemos en cache SQLite — así los chips de
/// filtro siguen estando disponibles offline (sólo aparecen las que
/// realmente tienen contenido visible).
final topicsProvider = FutureProvider<List<Topic>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    return await api.fetchTopics();
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    try {
      final dao = await ref.watch(itemsLocalesDaoProvider.future);
      final cache = await dao.obtenerCache(limite: 500);
      final conteo = <String, Topic>{};
      final counts = <String, int>{};
      for (final item in cache) {
        for (final t in item.topics) {
          if (t.slug.isEmpty) continue;
          conteo[t.slug] = t;
          counts[t.slug] = (counts[t.slug] ?? 0) + 1;
        }
      }
      if (conteo.isNotEmpty) {
        return conteo.values
            .map((t) => Topic(id: t.id, slug: t.slug, name: t.name, count: counts[t.slug] ?? 0))
            .toList()
          ..sort((a, b) => (b.count).compareTo(a.count));
      }
      // Cache sin topics declarados (p. ej. items del seed RSS, cuyo
      // parser no los extrae). Caemos al listado canónico bundleado
      // para que el filtro por temática siga funcionando offline. El
      // `count=1` es un marcador — no refleja ocurrencias reales.
      return _temasCanonicosOffline;
    } catch (_) {
      return _temasCanonicosOffline;
    }
  }
});

/// Lista canónica de temáticas precargada: refleja el mismo conjunto
/// que el activador del plugin backend. La duplicamos aquí para tener
/// un fallback cuando el backend no está disponible y los items en
/// cache no traen topic alguno.
const List<Topic> _temasCanonicosOffline = [
  Topic(id: 0, slug: 'vivienda', name: 'Vivienda', count: 1),
  Topic(id: 0, slug: 'sanidad', name: 'Sanidad', count: 1),
  Topic(id: 0, slug: 'laboral', name: 'Laboral', count: 1),
  Topic(id: 0, slug: 'feminismos', name: 'Feminismos', count: 1),
  Topic(id: 0, slug: 'ecologismo', name: 'Ecologismo', count: 1),
  Topic(id: 0, slug: 'antirracismo', name: 'Antirracismo', count: 1),
  Topic(id: 0, slug: 'educacion', name: 'Educación', count: 1),
  Topic(id: 0, slug: 'memoria-historica', name: 'Memoria histórica', count: 1),
  Topic(id: 0, slug: 'rural', name: 'Rural', count: 1),
  Topic(id: 0, slug: 'cultura', name: 'Cultura', count: 1),
  Topic(id: 0, slug: 'internacional', name: 'Internacional', count: 1),
  Topic(id: 0, slug: 'tecnologia-soberana', name: 'Tecnología soberana', count: 1),
  Topic(id: 0, slug: 'economia-social', name: 'Economía social', count: 1),
  Topic(id: 0, slug: 'migraciones', name: 'Migraciones', count: 1),
  Topic(id: 0, slug: 'cuidados', name: 'Cuidados', count: 1),
];

/// Fuentes activas (para filtrar por medio y mostrar directorio).
///
/// Si el backend no responde, caemos al seed bundleado (que además se
/// refresca en disco cada vez que la petición sí tiene éxito). Así el
/// directorio de medios sigue funcionando con la instancia caída.
final sourcesProvider = FutureProvider<PaginatedList<Source>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    final primera = await api.fetchSources(perPage: 100);
    // Snapshot completo en disco para el fallback offline: recorremos
    // todas las páginas si hay más de 100 fuentes. Antes se guardaba
    // sólo la primera página (100 fuentes máximo), y a partir de ahí
    // el modo offline perdía el resto del catálogo. Preservamos
    // `topics` también porque `seed_loader` los necesita para
    // reconstruir la relación source → topic en offline.
    final todasLasFuentes = <Source>[...primera.items];
    for (var p = 2; p <= primera.totalPages; p++) {
      try {
        final siguiente = await api.fetchSources(perPage: 100, page: p);
        todasLasFuentes.addAll(siguiente.items);
      } on FlavorNewsApiException {
        // Si una página falla, seguimos con lo que tengamos — es mejor
        // snapshot parcial que snapshot corrupto.
        break;
      }
    }
    guardarSnapshotSeed(
      'sources.json',
      todasLasFuentes
          .where((s) => s.feedUrl.isNotEmpty)
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'slug': s.slug,
                'feed_url': s.feedUrl,
                'feed_type': s.feedType,
                'website_url': s.websiteUrl,
                'territory': s.territory,
                'languages': s.languages,
                'topics': s.topics
                    .map((t) => {'id': t.id, 'name': t.name, 'slug': t.slug})
                    .toList(),
              })
          .toList(),
    );
    return primera;
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    final desdeSeed = await ref.watch(sourcesSeedProvider.future);
    return PaginatedList<Source>(
      items: desdeSeed,
      total: desdeSeed.length,
      totalPages: 1,
      page: 1,
      perPage: desdeSeed.length,
    );
  }
});

// El directorio de colectivos vive en `features/collectives/data/
// colectivos_directorio_notifier.dart` con filtros reactivos propios.

/// Directorio de radios libres. Casi estático: se cachea hasta que la
/// instancia cambie.
///
/// Si el backend no responde (sin red, servidor caído), caemos al seed
/// bundleado en el APK — así las radios siguen sonando aunque la instancia
/// esté off. Los streams de las radios son URLs directas a servidores
/// externos (Icecast/HLS), así que funcionan sin depender del backend.
final radiosProvider = FutureProvider<List<modelo_radio.Radio>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    final radios = await api.fetchRadios();
    guardarSnapshotSeed(
      'radios.json',
      radios
          .where((r) => r.streamUrl.isNotEmpty)
          .map((r) => {
                'id': r.id,
                'name': r.name,
                'slug': r.slug,
                'stream_url': r.streamUrl,
                'website_url': r.websiteUrl,
                'rss_url': r.rssUrl,
                'territory': r.territory,
                'languages': r.languages,
              })
          .toList(),
    );
    return radios;
  } on FlavorNewsApiException catch (e) {
    if (e.esProblemaRed) {
      return await ref.watch(radiosSeedProvider.future);
    }
    rethrow;
  }
});
