import 'package:flutter/foundation.dart';

import '../../../core/models/item.dart';

/// Estado del feed paginado. Inmutable.
/// `copyWith` permite transiciones atómicas tipo "añadir página siguiente".
@immutable
class EstadoFeed {
  const EstadoFeed({
    required this.items,
    required this.paginaActual,
    required this.totalPaginas,
    required this.cargandoMasPaginas,
    this.errorAlPaginar,
    this.modoOffline = false,
  });

  final List<Item> items;
  final int paginaActual;
  final int totalPaginas;
  final bool cargandoMasPaginas;

  /// Mensaje de error aislado al intentar cargar la siguiente página.
  /// Separado del `AsyncValue.error`: el error de la primera carga se
  /// gestiona con `AsyncError`; un fallo de paginado no debe vaciar la
  /// lista ya cargada.
  final String? errorAlPaginar;

  /// Indica que los items vienen del cache local porque el backend no
  /// respondió. La UI muestra un aviso "sin conexión" en este modo.
  final bool modoOffline;

  bool get hayMasPaginas => paginaActual < totalPaginas;
  bool get estaVacio => items.isEmpty;

  EstadoFeed copyWith({
    List<Item>? items,
    int? paginaActual,
    int? totalPaginas,
    bool? cargandoMasPaginas,
    String? errorAlPaginar,
    bool limpiarErrorAlPaginar = false,
    bool? modoOffline,
  }) {
    return EstadoFeed(
      items: items ?? this.items,
      paginaActual: paginaActual ?? this.paginaActual,
      totalPaginas: totalPaginas ?? this.totalPaginas,
      cargandoMasPaginas: cargandoMasPaginas ?? this.cargandoMasPaginas,
      errorAlPaginar: limpiarErrorAlPaginar ? null : (errorAlPaginar ?? this.errorAlPaginar),
      modoOffline: modoOffline ?? this.modoOffline,
    );
  }
}
