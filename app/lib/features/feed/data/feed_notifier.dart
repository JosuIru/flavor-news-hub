import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/ingest_trigger.dart';
import '../../../core/utils/territory_scoring.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import '../../offline_seed/data/seed_loader.dart';
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
    final territorioBase = ref.watch(
      preferenciasProvider.select((p) => p.territorioBase),
    );

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
      _ordenarLocalPrimero(combinados, territorioBase);

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
      // Sin red / error HTTP → modo autónomo. Combinamos TODO lo que
      // tengamos disponible (seed RSS en vivo + cache SQLite +
      // personales) y devolvemos siempre `EstadoFeed` con
      // `modoOffline: true`, aunque el combinado salga vacío. La UI
      // interpreta una lista vacía en offline como "sin contenido
      // guardado" y no como error — mejor que tirar la pantalla.
      if (error.esProblemaRed) {
        final itemsPersonales = await futuroPersonales;
        final cache = await dao.obtenerCache(limite: 50);

        // Mapas id_source → {idiomas, territorio}, leídos del seed.
        // Los usamos en modo offline para replicar en cliente los
        // filtros que normalmente aplica el backend (language,
        // territory). El filtro por topic va contra `item.topics`
        // directamente y el de source contra `item.source.id`.
        final fuentesSeed = await ref.watch(fuentesSeedProvider.future);
        final idiomasPorIdSource = <int, List<String>>{
          for (final f in fuentesSeed) f.id: f.languages,
        };
        final territorioPorIdSource = <int, String>{
          for (final f in fuentesSeed) f.id: f.territory,
        };

        EstadoFeed estadoDesde(List<Item> desdeSeed) => EstadoFeed(
              items: _combinar(
                desdeSeed: desdeSeed,
                cache: cache,
                itemsPersonales: itemsPersonales,
                fuentesBloqueadas: fuentesBloqueadas,
                filtros: filtros,
                idiomasPorIdSource: idiomasPorIdSource,
                territorioPorIdSource: territorioPorIdSource,
                territorioBase: territorioBase,
              ),
              paginaActual: 1,
              totalPaginas: 1,
              // Marcamos que seguimos esperando más tramos. La UI del
              // feed usa este flag para pintar un spinner fino en el
              // pie de lista (no sustituye la lista ya cargada).
              cargandoMasPaginas: true,
              modoOffline: true,
            );

        // Escuchamos el stream del seed: cada tramo refresca la UI con
        // los items acumulados. También procesamos tramos vacíos —
        // antes se ignoraban, lo que dejaba la UI con `cargandoMasPaginas=true`
        // para siempre si todos los feeds fallaban y no había ningún
        // item que acumular. Al recibir un vacío, combinamos con lo que
        // ya hubiera (cache, personales) y al menos apagamos el spinner.
        ref.listen<AsyncValue<List<Item>>>(itemsDesdeSeedProvider, (prev, next) {
          next.whenData((desdeSeed) {
            if (desdeSeed.isNotEmpty) {
              unawaited(dao.cachearMuchos(desdeSeed));
            }
            final combinados = _combinar(
              desdeSeed: desdeSeed,
              cache: cache,
              itemsPersonales: itemsPersonales,
              fuentesBloqueadas: fuentesBloqueadas,
              filtros: filtros,
              idiomasPorIdSource: idiomasPorIdSource,
              territorioPorIdSource: territorioPorIdSource,
              territorioBase: territorioBase,
            );
            unawaited(WidgetTitularesWriter.escribir(combinados));
            state = AsyncValue.data(EstadoFeed(
              items: combinados,
              paginaActual: 1,
              totalPaginas: 1,
              cargandoMasPaginas: false,
              modoOffline: true,
            ));
          });
        });

        // Sin cache ni personales: esperamos al PRIMER tramo con items
        // antes de devolver. Durante el await, AsyncNotifier queda en
        // estado AsyncLoading y la pantalla muestra el spinner — mucho
        // mejor que ver "feed vacío" durante los primeros segundos.
        if (cache.isEmpty && itemsPersonales.isEmpty) {
          final primerTramo = await ref
              .read(itemsDesdeSeedProvider.stream)
              .firstWhere((lista) => lista.isNotEmpty,
                  orElse: () => const <Item>[]);
          debugPrint('[FeedNotifier] fallback primer tramo items=${primerTramo.length}');
          return estadoDesde(primerTramo);
        }

        // Con cache o medios personales: devolvemos ya lo que haya y
        // el listener irá añadiendo los tramos conforme lleguen.
        debugPrint('[FeedNotifier] fallback inicial cache=${cache.length} personales=${itemsPersonales.length}');
        return estadoDesde(const []);
      }
      rethrow;
    }
  }

  /// Fusiona items de seed + cache + personales aplicando TODOS los
  /// filtros en cliente — offline el backend no contesta y no puede
  /// filtrar por nosotros. Replicamos la semántica de la API:
  ///  - topic: slug del item debe estar entre los seleccionados.
  ///  - territory: el territorio del medio (mapa id→territorio del seed)
  ///    debe contener el código elegido (LIKE parcial, igual que backend).
  ///  - language: algún idioma del medio coincide (OR entre idiomas).
  ///  - source: coincide exactamente con el id del medio.
  /// Items personales (id negativo, sin metadato en el seed) pasan el
  /// filtro de territorio/idioma: el usuario los añadió explícitamente
  /// y no queremos bloquearlos por falta de metadatos.
  List<Item> _combinar({
    required List<Item> desdeSeed,
    required List<Item> cache,
    required List<Item> itemsPersonales,
    required Set<int> fuentesBloqueadas,
    required FiltrosFeed filtros,
    required Map<int, List<String>> idiomasPorIdSource,
    required Map<int, String> territorioPorIdSource,
    required String territorioBase,
  }) {
    final idsSeed = desdeSeed.map((e) => e.id).toSet();
    final cacheNoSolapado = cache.where((i) => !idsSeed.contains(i.id));

    final topicsActivos = filtros.slugsTopics.toSet();
    final territorio = filtros.codigoTerritorio?.toLowerCase().trim();
    final filtroTerritorioActivo = territorio != null && territorio.isNotEmpty;
    final filtroIdiomaActivo = filtros.codigosIdiomas.isNotEmpty;
    final codigosIdiomasSet = filtros.codigosIdiomas.toSet();
    final idSourceFiltrada = filtros.idSource;

    bool pasaTodosLosFiltros(Item it) {
      if (!_noEsVideo(it)) return false;
      if (_estaFuenteBloqueada(it, fuentesBloqueadas)) return false;

      // Topic: el backend filtra por taxonomía asignada a cada post.
      // Los items del seed RSS no traen topics (el parser no los
      // extrae), así que aplicar el filtro estricto offline dejaría
      // el feed vacío. Política: si el item NO declara topics, lo
      // dejamos pasar — es menos estricto pero mucho más útil que
      // "nada que leer". Si sí los declara, exigimos coincidencia.
      if (topicsActivos.isNotEmpty && it.topics.isNotEmpty) {
        final slugsItem = it.topics.map((t) => t.slug).toSet();
        if (!slugsItem.any(topicsActivos.contains)) return false;
      }

      // Source concreto
      final idSource = it.source?.id;
      if (idSourceFiltrada != null && idSource != idSourceFiltrada) {
        return false;
      }

      // Territorio e idioma: sólo aplican si sabemos el medio del item.
      // Items personales (id <= 0) o sin metadato en seed → dejan pasar.
      final esPersonalOSinMetadato = idSource == null || idSource <= 0;

      if (filtroTerritorioActivo && !esPersonalOSinMetadato) {
        final territorioMedio =
            (territorioPorIdSource[idSource] ?? '').toLowerCase();
        if (!territorioMedio.contains(territorio)) return false;
      }

      if (filtroIdiomaActivo && !esPersonalOSinMetadato) {
        final idiomasDelMedio = idiomasPorIdSource[idSource] ?? const <String>[];
        // Si no tenemos dato de idiomas para este medio, no bloqueamos
        // (evita vaciar el feed al filtrar si el seed no lo anota).
        if (idiomasDelMedio.isNotEmpty &&
            !idiomasDelMedio.any(codigosIdiomasSet.contains)) {
          return false;
        }
      }

      return true;
    }

    final todos = [...desdeSeed, ...cacheNoSolapado, ...itemsPersonales];
    final combinados = todos.where(pasaTodosLosFiltros).toList();
    debugPrint(
      '[FeedNotifier] _combinar total=${todos.length} tras_filtros=${combinados.length} '
      'filtros{topics:${topicsActivos.length} territorio:$filtroTerritorioActivo '
      'idioma:$filtroIdiomaActivo source:$idSourceFiltrada '
      'bloqueadas:${fuentesBloqueadas.length}}',
    );
    _ordenarLocalPrimero(combinados, territorioBase);
    return combinados;
  }

  /// Delega en [ordenarItemsLocalPrimero]. Se mantiene este wrapper
  /// para no reescribir los puntos de llamada dentro del notifier.
  static void _ordenarLocalPrimero(List<Item> lista, String territorioBase) {
    ordenarItemsLocalPrimero(lista, territorioBase);
  }

  /// Recarga la primera página manteniendo los filtros actuales.
  /// Invalidamos también el stream del seed RSS: si el build anterior
  /// ya consumió la lista completa, un simple invalidateSelf del feed
  /// no haría re-fetch de los RSS — veríamos los mismos titulares.
  Future<void> refrescar() async {
    // Pull-to-refresh: aprovechamos para despertar la ingesta del
    // backend. Así si el usuario tira porque "no veo nada nuevo",
    // el backend pasa por los feeds antes del siguiente request.
    // Fire-and-forget; el rate-limit del endpoint evita encadenar.
    unawaited(dispararIngestaBackend(ref.read(sharedPreferencesProvider)));
    ref.invalidate(itemsDesdeSeedProvider);
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
      final territorioBase = ref.read(
        preferenciasProvider.select((p) => p.territorioBase),
      );
      final nuevosFiltrados = siguientePagina.items
          .where(_noEsVideo)
          .where((it) => !_estaFuenteBloqueada(it, bloqueadas))
          .toList();
      // Aplicamos scoring local-primero dentro de la página nueva.
      // No reordenamos lo ya mostrado: un item de la pág 2 que fuera
      // muy local no debe "saltar" a la pág 1 que el usuario ya vio.
      _ordenarLocalPrimero(nuevosFiltrados, territorioBase);
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
