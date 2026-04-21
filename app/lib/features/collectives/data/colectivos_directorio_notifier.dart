import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/collective.dart';
import '../../../core/providers/api_provider.dart';
import '../../offline_seed/data/seed_cache.dart';
import '../../offline_seed/data/seed_loader.dart';
import 'filtros_colectivos.dart';

@immutable
class EstadoDirectorioColectivos {
  const EstadoDirectorioColectivos({
    required this.items,
    required this.paginaActual,
    required this.totalPaginas,
    required this.cargandoMasPaginas,
    this.errorAlPaginar,
  });

  final List<Collective> items;
  final int paginaActual;
  final int totalPaginas;
  final bool cargandoMasPaginas;
  final String? errorAlPaginar;

  bool get hayMasPaginas => paginaActual < totalPaginas;
  bool get estaVacio => items.isEmpty;

  EstadoDirectorioColectivos copyWith({
    List<Collective>? items,
    int? paginaActual,
    int? totalPaginas,
    bool? cargandoMasPaginas,
    String? errorAlPaginar,
    bool limpiarError = false,
  }) {
    return EstadoDirectorioColectivos(
      items: items ?? this.items,
      paginaActual: paginaActual ?? this.paginaActual,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      cargandoMasPaginas: cargandoMasPaginas ?? this.cargandoMasPaginas,
      errorAlPaginar: limpiarError ? null : (errorAlPaginar ?? this.errorAlPaginar),
    );
  }
}

/// Gemelo del FeedNotifier pero para colectivos. Misma política de paginación
/// y de observación de filtros; al cambiar `filtrosColectivosProvider` se
/// recarga desde la primera página automáticamente.
class ColectivosDirectorioNotifier extends AsyncNotifier<EstadoDirectorioColectivos> {
  @override
  Future<EstadoDirectorioColectivos> build() async {
    final filtros = ref.watch(filtrosColectivosProvider);
    final api = ref.watch(flavorNewsApiProvider);
    try {
      final primera = await api.fetchCollectives(
        page: 1,
        topic: filtros.topicsParaQueryParam,
        territory: filtros.codigoTerritorio,
      );
      // Snapshot sólo si la petición era sin filtros (es lo que queremos
      // como fallback completo; no queremos cachear una subsección).
      if (filtros.estaVacio) {
        guardarSnapshotSeed(
          'collectives.json',
          primera.items
              .map((c) => {
                    'id': c.id,
                    'name': c.name,
                    'slug': c.slug,
                    'description': c.description,
                    'url': c.url,
                    'website_url': c.websiteUrl,
                    'flavor_url': c.flavorUrl,
                    'territory': c.territory,
                    'has_contact': c.hasContact,
                    'verified': c.verified,
                    'topics': c.topics
                        .map((t) => {'id': t.id, 'name': t.name, 'slug': t.slug})
                        .toList(),
                  })
              .toList(),
        );
      }
      return EstadoDirectorioColectivos(
        items: primera.items,
        paginaActual: 1,
        totalPaginas: primera.totalPages,
        cargandoMasPaginas: false,
      );
    } on FlavorNewsApiException catch (error) {
      // Fallback autónomo: si el backend no responde, servimos el directorio
      // bundleado. Aplicamos los filtros de territorio/topic en cliente.
      if (!error.esProblemaRed) rethrow;
      final seed = await ref.watch(colectivosSeedProvider.future);
      final filtrados = _aplicarFiltros(seed, filtros);
      return EstadoDirectorioColectivos(
        items: filtrados,
        paginaActual: 1,
        totalPaginas: 1,
        cargandoMasPaginas: false,
      );
    }
  }

  List<Collective> _aplicarFiltros(
    List<Collective> todos,
    FiltrosColectivos filtros,
  ) {
    Iterable<Collective> iter = todos;
    final terr = filtros.codigoTerritorio;
    if (terr != null && terr.isNotEmpty) {
      final needle = terr.toLowerCase();
      iter = iter.where((c) => c.territory.toLowerCase().contains(needle));
    }
    final slugs = filtros.topicsParaQueryParam;
    if (slugs != null && slugs.isNotEmpty) {
      final set = slugs.split(',').map((s) => s.trim()).toSet();
      iter = iter.where((c) => c.topics.any((t) => set.contains(t.slug)));
    }
    return iter.toList();
  }

  Future<void> refrescar() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> cargarSiguiente() async {
    final estadoActual = state.valueOrNull;
    if (estadoActual == null) return;
    if (estadoActual.cargandoMasPaginas) return;
    if (!estadoActual.hayMasPaginas) return;

    state = AsyncData(estadoActual.copyWith(
      cargandoMasPaginas: true,
      limpiarError: true,
    ));

    try {
      final filtros = ref.read(filtrosColectivosProvider);
      final api = ref.read(flavorNewsApiProvider);
      final siguiente = await api.fetchCollectives(
        page: estadoActual.paginaActual + 1,
        topic: filtros.topicsParaQueryParam,
        territory: filtros.codigoTerritorio,
      );
      state = AsyncData(EstadoDirectorioColectivos(
        items: [...estadoActual.items, ...siguiente.items],
        paginaActual: estadoActual.paginaActual + 1,
        totalPaginas: siguiente.totalPages,
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

final colectivosDirectorioProvider =
    AsyncNotifierProvider<ColectivosDirectorioNotifier, EstadoDirectorioColectivos>(
  ColectivosDirectorioNotifier.new,
);
