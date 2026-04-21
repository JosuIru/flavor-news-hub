import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
final topicsProvider = FutureProvider<List<Topic>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  return api.fetchTopics();
});

/// Fuentes activas (para filtrar por medio y mostrar directorio).
///
/// Si el backend no responde, caemos al seed bundleado (que además se
/// refresca en disco cada vez que la petición sí tiene éxito). Así el
/// directorio de medios sigue funcionando con la instancia caída.
final sourcesProvider = FutureProvider<PaginatedList<Source>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    final pagina = await api.fetchSources(perPage: 100);
    // Snapshot del catálogo en disco: la siguiente vez que el backend esté
    // caído, el fallback usará estos datos frescos en vez del bundleado.
    guardarSnapshotSeed(
      'sources.json',
      pagina.items
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
              })
          .toList(),
    );
    return pagina;
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
