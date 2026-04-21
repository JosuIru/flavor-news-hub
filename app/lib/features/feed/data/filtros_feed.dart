import 'dart:convert';

// `PlatformDispatcher` (para el idioma del sistema en primera ejecución)
// y `listEquals` / `immutable` vienen re-exportados por flutter/foundation.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/preferences_provider.dart';

/// Filtros aplicados al feed. Inmutable.
///
/// `slugsTopics` y `codigosIdiomas` son multi-selección (OR en backend).
/// `codigoTerritorio` e `idSource` son únicos.
@immutable
class FiltrosFeed {
  const FiltrosFeed({
    this.slugsTopics = const [],
    this.codigoTerritorio,
    this.codigosIdiomas = const [],
    this.idSource,
  });

  final List<String> slugsTopics;
  final String? codigoTerritorio;
  final List<String> codigosIdiomas;
  final int? idSource;

  static const FiltrosFeed vacios = FiltrosFeed();

  /// Idiomas que la interfaz declara como de primera clase.
  static const List<String> idiomasSoportados = ['es', 'ca', 'eu', 'gl', 'en'];

  bool get estaVacio =>
      slugsTopics.isEmpty &&
      (codigoTerritorio == null || codigoTerritorio!.isEmpty) &&
      codigosIdiomas.isEmpty &&
      idSource == null;

  /// Formato esperado por el backend (`topic=vivienda,sanidad`).
  String? get topicsParaQueryParam => slugsTopics.isEmpty ? null : slugsTopics.join(',');

  /// Idiomas como cadena coma-separada. Backend interpreta OR.
  String? get idiomasParaQueryParam =>
      codigosIdiomas.isEmpty ? null : codigosIdiomas.join(',');

  FiltrosFeed copyWith({
    List<String>? slugsTopics,
    String? codigoTerritorio,
    bool borrarTerritorio = false,
    List<String>? codigosIdiomas,
    int? idSource,
    bool borrarSource = false,
  }) {
    return FiltrosFeed(
      slugsTopics: slugsTopics ?? this.slugsTopics,
      codigoTerritorio:
          borrarTerritorio ? null : (codigoTerritorio ?? this.codigoTerritorio),
      codigosIdiomas: codigosIdiomas ?? this.codigosIdiomas,
      idSource: borrarSource ? null : (idSource ?? this.idSource),
    );
  }

  Map<String, dynamic> toJson() => {
        'slugsTopics': slugsTopics,
        'codigoTerritorio': codigoTerritorio,
        'codigosIdiomas': codigosIdiomas,
        'idSource': idSource,
      };

  factory FiltrosFeed.fromJson(Map<String, dynamic> json) {
    // Compat: en versiones anteriores el campo era `codigoIdioma` (single).
    List<String> idiomas = (json['codigosIdiomas'] as List?)?.cast<String>() ?? const [];
    if (idiomas.isEmpty) {
      final antiguo = json['codigoIdioma'] as String?;
      if (antiguo != null && antiguo.isNotEmpty) {
        idiomas = [antiguo];
      }
    }
    return FiltrosFeed(
      slugsTopics: (json['slugsTopics'] as List?)?.cast<String>() ?? const [],
      codigoTerritorio: json['codigoTerritorio'] as String?,
      codigosIdiomas: idiomas,
      idSource: json['idSource'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! FiltrosFeed) return false;
    return codigoTerritorio == other.codigoTerritorio &&
        idSource == other.idSource &&
        listEquals(slugsTopics, other.slugsTopics) &&
        listEquals(codigosIdiomas, other.codigosIdiomas);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(slugsTopics),
        codigoTerritorio,
        Object.hashAll(codigosIdiomas),
        idSource,
      );
}

/// Notifier que persiste los filtros en SharedPreferences.
///
/// En la primera ejecución — cuando no hay nada guardado aún — y si el
/// idioma del sistema es uno de los 5 soportados, se preselecciona ese
/// idioma como filtro. El usuario puede añadir otros o desmarcarlo desde
/// la pantalla de Filtros, y la siguiente lectura respetará su elección
/// (aunque deje la lista vacía, se persiste la clave y no volvemos a
/// auto-rellenar).
class FiltrosFeedNotifier extends StateNotifier<FiltrosFeed> {
  FiltrosFeedNotifier(this._sharedPrefs, String? codigoIdiomaUi)
      : super(_leerInicial(_sharedPrefs, codigoIdiomaUi));

  static const _clave = 'fnh.filters.feed';

  final SharedPreferences _sharedPrefs;

  /// Resuelve filtro inicial:
  ///  1. Si hay filtros guardados, respetarlos.
  ///  2. Si no, usar idioma configurado en Ajustes → Idioma de la interfaz.
  ///  3. Si el usuario tiene "seguir sistema", caer al idioma del sistema.
  ///  4. Si ese idioma no está entre los 5 soportados, dejar vacío.
  static FiltrosFeed _leerInicial(SharedPreferences sp, String? codigoIdiomaUi) {
    final cadena = sp.getString(_clave);
    if (cadena != null && cadena.isNotEmpty) {
      try {
        final mapa = jsonDecode(cadena) as Map<String, dynamic>;
        return FiltrosFeed.fromJson(mapa);
      } catch (_) {
        // sigue al default
      }
    }
    final codigoResuelto =
        codigoIdiomaUi ?? PlatformDispatcher.instance.locale.languageCode;
    if (FiltrosFeed.idiomasSoportados.contains(codigoResuelto)) {
      return FiltrosFeed(codigosIdiomas: [codigoResuelto]);
    }
    return FiltrosFeed.vacios;
  }

  /// Llamado al cambiar el idioma de UI en Ajustes. Si el usuario sólo
  /// tenía un idioma en el filtro (el default heredado del idioma UI),
  /// lo cambia por el nuevo. Si tenía varios seleccionados a propósito,
  /// no pisamos su elección — es señal de que quiere ver noticias en
  /// varios idiomas sin importar cuál use en la UI.
  Future<void> adoptarIdiomaUi(String? nuevoCodigoUi) async {
    if (nuevoCodigoUi == null) return;
    if (!FiltrosFeed.idiomasSoportados.contains(nuevoCodigoUi)) return;
    if (state.codigosIdiomas.length <= 1) {
      await _persistir(state.copyWith(codigosIdiomas: [nuevoCodigoUi]));
    }
  }

  Future<void> _persistir(FiltrosFeed nuevos) async {
    state = nuevos;
    // Siempre persistimos (incluso si queda vacío) para que la próxima
    // lectura no dispare el "auto-rellenar idioma del sistema".
    await _sharedPrefs.setString(_clave, jsonEncode(nuevos.toJson()));
  }

  Future<void> alternarTopic(String slug) async {
    final existe = state.slugsTopics.contains(slug);
    final nuevaLista = existe
        ? (state.slugsTopics.where((s) => s != slug).toList())
        : ([...state.slugsTopics, slug]);
    await _persistir(state.copyWith(slugsTopics: nuevaLista));
  }

  Future<void> establecerTerritorio(String? territorio) async {
    final limpio = territorio?.trim();
    await _persistir(state.copyWith(
      codigoTerritorio: (limpio == null || limpio.isEmpty) ? null : limpio,
      borrarTerritorio: limpio == null || limpio.isEmpty,
    ));
  }

  Future<void> alternarIdioma(String codigo) async {
    final existe = state.codigosIdiomas.contains(codigo);
    final nuevaLista = existe
        ? state.codigosIdiomas.where((c) => c != codigo).toList()
        : [...state.codigosIdiomas, codigo];
    await _persistir(state.copyWith(codigosIdiomas: nuevaLista));
  }

  Future<void> establecerSource(int? idSource) async {
    await _persistir(state.copyWith(
      idSource: idSource,
      borrarSource: idSource == null,
    ));
  }

  Future<void> limpiar() async => _persistir(FiltrosFeed.vacios);
}

final filtrosFeedProvider =
    StateNotifierProvider<FiltrosFeedNotifier, FiltrosFeed>((ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  // Leemos con `read` (no watch) para no recrear el notifier cada vez que
  // el usuario cambie el idioma de UI. El cambio en sí se propaga al
  // filtro mediante `adoptarIdiomaUi` desde la pantalla de Ajustes.
  final codigoIdiomaUi = ref.read(preferenciasProvider).codigoIdioma;
  return FiltrosFeedNotifier(sp, codigoIdiomaUi);
});
