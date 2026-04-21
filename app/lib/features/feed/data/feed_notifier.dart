import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import '../../personal_sources/data/items_personales_provider.dart';
import '../../sources_filter/data/fuentes_bloqueadas_notifier.dart';
import '../../widgets/widget_titulares_writer.dart';
import 'feed_state.dart';
import 'filtros_feed.dart';

/// Carga paginada del feed. Primera página vía `AsyncNotifier.build()`;
/// páginas sucesivas con `cargarSiguiente()`; refresco manual con
/// `refrescar()`.
///
/// Integra:
///  - fuentes personales locales (mezcladas sólo sin filtros activos),
///  - cache offline: si la petición al backend falla y no hay items
///    mostrados, devolvemos lo último cacheado en SQLite.
class FeedNotifier extends AsyncNotifier<EstadoFeed> {
  @override
  Future<EstadoFeed> build() async {
    final filtros = ref.watch(filtrosFeedProvider);
    final api = ref.watch(flavorNewsApiProvider);
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    final fuentesBloqueadas = ref.watch(fuentesBloqueadasProvider);

    final futuroPersonales = filtros.estaVacio
        ? ref.watch(itemsDeFuentesPersonalesProvider.future)
        : Future.value(const <Item>[]);

    try {
      final primeraPaginaBackend = await api.fetchItems(
        page: 1,
        topic: filtros.topicsParaQueryParam,
        source: filtros.idSource,
        territory: filtros.codigoTerritorio,
        language: filtros.idiomasParaQueryParam,
        // Feed de titulares = sólo texto. Vídeos y podcasts viven en su
        // propia pestaña porque los canales YouTube publican mucho más
        // frecuentemente que los medios de texto y los tapan.
        excludeSourceType: 'video,youtube,podcast',
      );

      // Cachear en segundo plano para poder servir offline la próxima vez.
      // Sólo items del backend (id > 0); los personales no se cachean.
      unawaited(dao.cachearMuchos(primeraPaginaBackend.items));

      final itemsPersonales = await futuroPersonales;
      final combinados = [...primeraPaginaBackend.items, ...itemsPersonales]
          .where(_noEsVideo) // filtra personales tipo youtube/video
          .where((it) => !_estaFuenteBloqueada(it, fuentesBloqueadas))
          .toList();
      combinados.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      // Empujamos los 3 más recientes al widget Android para que pinte
      // titulares en la pantalla de inicio. No-op si no hay widget colocado.
      unawaited(WidgetTitularesWriter.escribir(combinados));

      return EstadoFeed(
        items: combinados,
        paginaActual: 1,
        totalPaginas: primeraPaginaBackend.totalPages,
        cargandoMasPaginas: false,
      );
    } on FlavorNewsApiException catch (error) {
      // Sin red / error HTTP → modo autónomo: siempre que el dispositivo
      // tenga red (aunque el backend esté caído), descargamos los RSS del
      // seed directamente. Si también falla la red absoluta, caemos al
      // cache local. Priorizamos seed sobre cache porque el seed es más
      // fresco (descarga ahora) y el cache puede tener horas/días.
      if (error.esProblemaRed) {
        final itemsPersonales = await futuroPersonales;
        List<Item> desdeSeed = const [];
        try {
          desdeSeed = await ref.watch(itemsDesdeSeedProvider.future);
        } catch (_) {
          // sigue intentando con cache
        }

        if (desdeSeed.isNotEmpty) {
          unawaited(dao.cachearMuchos(desdeSeed));
          // Mezclamos con cache para mantener items del backend que no
          // están en el seed (colectivos, publicaciones federadas…).
          final cache = await dao.obtenerCache(limite: 50);
          final idsSeed = desdeSeed.map((e) => e.id).toSet();
          final cacheNoSolapado = cache.where((i) => !idsSeed.contains(i.id));
          final combinados = [...desdeSeed, ...cacheNoSolapado, ...itemsPersonales]
              .where(_noEsVideo)
              .where((it) => !_estaFuenteBloqueada(it, fuentesBloqueadas))
              .toList();
          combinados.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          unawaited(WidgetTitularesWriter.escribir(combinados));
          return EstadoFeed(
            items: combinados,
            paginaActual: 1,
            totalPaginas: 1,
            cargandoMasPaginas: false,
            modoOffline: true,
          );
        }

        // Sin seed (sin red absoluta) → cache.
        final cache = await dao.obtenerCache(limite: 50);
        if (cache.isNotEmpty) {
          final combinados = [...cache, ...itemsPersonales]
              .where(_noEsVideo)
              .where((it) => !_estaFuenteBloqueada(it, fuentesBloqueadas))
              .toList();
          combinados.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          return EstadoFeed(
            items: combinados,
            paginaActual: 1,
            totalPaginas: 1,
            cargandoMasPaginas: false,
            modoOffline: true,
          );
        }
      }
      rethrow;
    }
  }

  /// Recarga la primera página manteniendo los filtros actuales.
  Future<void> refrescar() async {
    ref.invalidateSelf();
    await future;
  }

  /// Añade la siguiente página al final de la lista. Idempotente: si ya
  /// está cargando o no hay más páginas, no hace nada.
  Future<void> cargarSiguiente() async {
    final estadoActual = state.valueOrNull;
    if (estadoActual == null) return;
    if (estadoActual.cargandoMasPaginas) return;
    if (!estadoActual.hayMasPaginas) return;
    if (estadoActual.modoOffline) return; // offline no hay paginación

    state = AsyncData(estadoActual.copyWith(
      cargandoMasPaginas: true,
      limpiarErrorAlPaginar: true,
    ));

    try {
      final filtros = ref.read(filtrosFeedProvider);
      final api = ref.read(flavorNewsApiProvider);
      final dao = await ref.read(itemsLocalesDaoProvider.future);
      final siguientePagina = await api.fetchItems(
        page: estadoActual.paginaActual + 1,
        topic: filtros.topicsParaQueryParam,
        source: filtros.idSource,
        territory: filtros.codigoTerritorio,
        language: filtros.idiomasParaQueryParam,
        excludeSourceType: 'video,youtube,podcast',
      );
      unawaited(dao.cachearMuchos(siguientePagina.items));

      final bloqueadas = ref.read(fuentesBloqueadasProvider);
      final nuevosFiltrados = siguientePagina.items
          .where(_noEsVideo)
          .where((it) => !_estaFuenteBloqueada(it, bloqueadas))
          .toList();
      state = AsyncData(EstadoFeed(
        items: [...estadoActual.items, ...nuevosFiltrados],
        paginaActual: estadoActual.paginaActual + 1,
        totalPaginas: siguientePagina.totalPages,
        cargandoMasPaginas: false,
      ));
    } on FlavorNewsApiException catch (error) {
      state = AsyncData(estadoActual.copyWith(
        cargandoMasPaginas: false,
        errorAlPaginar: error.message,
      ));
    } catch (error) {
      state = AsyncData(estadoActual.copyWith(
        cargandoMasPaginas: false,
        errorAlPaginar: error.toString(),
      ));
    }
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, EstadoFeed>(FeedNotifier.new);

/// `unawaited` propio para evitar importar `dart:async` sólo por esto.
void unawaited(Future<void> _) {}

/// Items cuya fuente está en la lista de silenciadas por el usuario.
/// Aplicable sólo a items del backend (ids > 0); los personales siempre
/// pasan porque el usuario eligió añadirlos.
bool _estaFuenteBloqueada(Item item, Set<int> bloqueadas) {
  final idFuente = item.source?.id ?? 0;
  if (idFuente <= 0) return false;
  return bloqueadas.contains(idFuente);
}

/// Un item es "vídeo" cuando su source está marcada youtube/video, o su URL
/// original apunta a un dominio conocido de vídeo. Se excluye del feed de
/// titulares: vive en su propia pestaña.
bool _noEsVideo(Item item) {
  final tipo = item.source?.feedType ?? 'rss';
  if (tipo == 'youtube' || tipo == 'video') return false;
  final url = item.originalUrl.toLowerCase();
  if (url.isEmpty) return true;
  return !(url.contains('youtube.com/watch') ||
      url.contains('youtu.be/') ||
      url.contains('vimeo.com/') ||
      url.contains('peertube'));
}
