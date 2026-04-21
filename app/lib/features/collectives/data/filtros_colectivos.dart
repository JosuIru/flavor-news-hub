import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtros del directorio de colectivos.
///
/// A diferencia del feed, aquí no los persistimos: el directorio es una
/// herramienta de búsqueda puntual (usuario llega, busca, actúa), no
/// un consumo recurrente. Si en el futuro aparece la necesidad, se
/// añade SharedPreferences igual que en `FiltrosFeedNotifier`.
@immutable
class FiltrosColectivos {
  const FiltrosColectivos({
    this.slugsTopics = const [],
    this.codigoTerritorio,
  });

  final List<String> slugsTopics;
  final String? codigoTerritorio;

  static const vacios = FiltrosColectivos();

  bool get estaVacio => slugsTopics.isEmpty && (codigoTerritorio == null || codigoTerritorio!.isEmpty);

  String? get topicsParaQueryParam => slugsTopics.isEmpty ? null : slugsTopics.join(',');

  FiltrosColectivos copyWith({
    List<String>? slugsTopics,
    String? codigoTerritorio,
    bool borrarTerritorio = false,
  }) {
    return FiltrosColectivos(
      slugsTopics: slugsTopics ?? this.slugsTopics,
      codigoTerritorio:
          borrarTerritorio ? null : (codigoTerritorio ?? this.codigoTerritorio),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! FiltrosColectivos) return false;
    return codigoTerritorio == other.codigoTerritorio &&
        listEquals(slugsTopics, other.slugsTopics);
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(slugsTopics), codigoTerritorio);
}

class FiltrosColectivosNotifier extends StateNotifier<FiltrosColectivos> {
  FiltrosColectivosNotifier() : super(FiltrosColectivos.vacios);

  void alternarTopic(String slug) {
    final nueva = state.slugsTopics.contains(slug)
        ? (state.slugsTopics.where((s) => s != slug).toList())
        : ([...state.slugsTopics, slug]);
    state = state.copyWith(slugsTopics: nueva);
  }

  void establecerTerritorio(String? territorio) {
    final limpio = territorio?.trim();
    state = state.copyWith(
      codigoTerritorio: (limpio == null || limpio.isEmpty) ? null : limpio,
      borrarTerritorio: limpio == null || limpio.isEmpty,
    );
  }

  void limpiar() => state = FiltrosColectivos.vacios;
}

final filtrosColectivosProvider =
    StateNotifierProvider<FiltrosColectivosNotifier, FiltrosColectivos>(
  (ref) => FiltrosColectivosNotifier(),
);
