import 'package:freezed_annotation/freezed_annotation.dart';

part 'paginated_list.freezed.dart';

/// Lista paginada. El backend expone el total de resultados y de páginas
/// vía las cabeceras HTTP estándar de WordPress (`X-WP-Total`,
/// `X-WP-TotalPages`), no en el cuerpo JSON, así que este wrapper se
/// construye a mano en el cliente — no tiene `fromJson`.
@freezed
class PaginatedList<T> with _$PaginatedList<T> {
  const factory PaginatedList({
    required List<T> items,
    required int total,
    required int totalPages,
    required int page,
    required int perPage,
  }) = _PaginatedList<T>;

  const PaginatedList._();

  bool get tieneMasPaginas => page < totalPages;

  bool get estaVacia => items.isEmpty;
}
