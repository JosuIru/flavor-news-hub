import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../idioma_contenido/politica_idioma_contenido.dart';
import '../providers/preferences_provider.dart';

/// Filtros que se comparten entre las secciones que los toleran:
/// Feed, Vídeos, TV, Podcasts, Colectivos (directorio + noticias) y
/// Radios. Cada sección lee y escribe sólo los campos que aplica; los
/// que no aplica se conservan intactos. De esa forma, si el usuario
/// fija euskera + feminismos en Feed y luego pasa por Radios (que sólo
/// tolera idioma+territorio), al volver a Vídeos sigue viendo
/// "feminismos" como temática activa.
///
/// Antes cada sección tenía su propio `FiltrosX` aislado y sólo Feed
/// persistía. Eso producía la sensación de "perder" los filtros al
/// cambiar de pestaña, además de duplicar 5 modelos casi idénticos.
@immutable
class FiltrosTransversales {
  const FiltrosTransversales({
    this.slugsTopics = const [],
    this.codigoTerritorio,
    this.codigosIdiomasOverride = const [],
  });

  /// Lista de slugs de temáticas seleccionadas (OR en backend).
  final List<String> slugsTopics;

  /// Territorio fijado por el usuario (texto libre, p.ej. "Bizkaia").
  /// `null` o vacío = sin filtro de territorio.
  final String? codigoTerritorio;

  /// Override sobre la política central de idioma de contenido. Si está
  /// vacío, las pestañas usan `idiomasContenidoEfectivosProvider`. Si el
  /// usuario marca chips en cualquier pestaña, esa selección pasa aquí
  /// y la heredan las demás.
  final List<String> codigosIdiomasOverride;

  static const FiltrosTransversales vacios = FiltrosTransversales();

  bool get tieneTopics => slugsTopics.isNotEmpty;
  bool get tieneTerritorio =>
      codigoTerritorio != null && codigoTerritorio!.isNotEmpty;
  bool get tieneIdiomasOverride => codigosIdiomasOverride.isNotEmpty;

  bool get estaVacio =>
      !tieneTopics && !tieneTerritorio && !tieneIdiomasOverride;

  String? get topicsParaQueryParam =>
      slugsTopics.isEmpty ? null : slugsTopics.join(',');

  String? get idiomasOverrideParaQueryParam =>
      codigosIdiomasOverride.isEmpty ? null : codigosIdiomasOverride.join(',');

  FiltrosTransversales copyWith({
    List<String>? slugsTopics,
    String? codigoTerritorio,
    bool borrarTerritorio = false,
    List<String>? codigosIdiomasOverride,
  }) {
    return FiltrosTransversales(
      slugsTopics: slugsTopics ?? this.slugsTopics,
      codigoTerritorio: borrarTerritorio
          ? null
          : (codigoTerritorio ?? this.codigoTerritorio),
      codigosIdiomasOverride:
          codigosIdiomasOverride ?? this.codigosIdiomasOverride,
    );
  }

  Map<String, dynamic> toJson() => {
        'slugsTopics': slugsTopics,
        'codigoTerritorio': codigoTerritorio,
        'codigosIdiomasOverride': codigosIdiomasOverride,
      };

  factory FiltrosTransversales.fromJson(Map<String, dynamic> json) {
    return FiltrosTransversales(
      slugsTopics:
          (json['slugsTopics'] as List?)?.cast<String>() ?? const [],
      codigoTerritorio: json['codigoTerritorio'] as String?,
      codigosIdiomasOverride:
          (json['codigosIdiomasOverride'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! FiltrosTransversales) return false;
    return codigoTerritorio == other.codigoTerritorio &&
        listEquals(slugsTopics, other.slugsTopics) &&
        listEquals(codigosIdiomasOverride, other.codigosIdiomasOverride);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(slugsTopics),
        codigoTerritorio,
        Object.hashAll(codigosIdiomasOverride),
      );
}

/// Notifier que persiste los filtros transversales en
/// `SharedPreferences`. Migración suave: la primera vez que arranca, si
/// detecta los filtros antiguos del Feed (`fnh.filters.feed`, formato
/// pre-v0.12) los vuelca al nuevo y borra el viejo.
class FiltrosTransversalesNotifier extends StateNotifier<FiltrosTransversales> {
  FiltrosTransversalesNotifier(this._sharedPrefs)
      : super(_leerInicial(_sharedPrefs));

  static const _claveActual = 'fnh.filters.global';

  /// Clave del sistema antiguo (sólo Feed). La migración la consume
  /// y la borra una vez.
  static const _claveAntigua = 'fnh.filters.feed';

  final SharedPreferences _sharedPrefs;

  static FiltrosTransversales _leerInicial(SharedPreferences sp) {
    final raw = sp.getString(_claveActual);
    if (raw != null && raw.isNotEmpty) {
      try {
        final mapa = jsonDecode(raw) as Map<String, dynamic>;
        return FiltrosTransversales.fromJson(mapa);
      } catch (_) {
        // sigue al fallback
      }
    }
    // Migración suave desde el formato antiguo (pre-v0.12). Si existe,
    // lo volcamos al nuevo y lo borramos para no repetir migraciones.
    final rawAntiguo = sp.getString(_claveAntigua);
    if (rawAntiguo != null && rawAntiguo.isNotEmpty) {
      try {
        final mapa = jsonDecode(rawAntiguo) as Map<String, dynamic>;
        // Compat: el formato antiguo tenía `codigosIdiomas` (no
        // `codigosIdiomasOverride`) y, aún más antiguo, `codigoIdioma`
        // single. Reconstruimos como override.
        List<String> idiomas =
            (mapa['codigosIdiomas'] as List?)?.cast<String>() ?? const [];
        if (idiomas.isEmpty) {
          final antiguo = mapa['codigoIdioma'] as String?;
          if (antiguo != null && antiguo.isNotEmpty) {
            idiomas = [antiguo];
          }
        }
        final migrado = FiltrosTransversales(
          slugsTopics:
              (mapa['slugsTopics'] as List?)?.cast<String>() ?? const [],
          codigoTerritorio: mapa['codigoTerritorio'] as String?,
          codigosIdiomasOverride: idiomas,
        );
        // Persistimos el formato nuevo y borramos el antiguo. Si la
        // escritura falla por cualquier motivo, devolvemos lo
        // migrado de todas formas — la próxima ejecución reintentará.
        unawaited(sp.setString(_claveActual, jsonEncode(migrado.toJson())));
        unawaited(sp.remove(_claveAntigua));
        return migrado;
      } catch (_) {
        // JSON corrupto del antiguo: arrancamos vacío.
      }
    }
    return FiltrosTransversales.vacios;
  }

  Future<void> _persistir(FiltrosTransversales nuevos) async {
    state = nuevos;
    await _sharedPrefs.setString(_claveActual, jsonEncode(nuevos.toJson()));
  }

  Future<void> alternarTopic(String slug) async {
    final existe = state.slugsTopics.contains(slug);
    final nuevaLista = existe
        ? state.slugsTopics.where((s) => s != slug).toList()
        : [...state.slugsTopics, slug];
    await _persistir(state.copyWith(slugsTopics: nuevaLista));
  }

  Future<void> establecerTerritorio(String? territorio) async {
    final limpio = territorio?.trim();
    final estaVacio = limpio == null || limpio.isEmpty;
    await _persistir(state.copyWith(
      codigoTerritorio: estaVacio ? null : limpio,
      borrarTerritorio: estaVacio,
    ));
  }

  Future<void> alternarIdioma(String codigo) async {
    final existe = state.codigosIdiomasOverride.contains(codigo);
    final nueva = existe
        ? state.codigosIdiomasOverride.where((c) => c != codigo).toList()
        : [...state.codigosIdiomasOverride, codigo];
    await _persistir(state.copyWith(codigosIdiomasOverride: nueva));
  }

  Future<void> limpiarIdiomas() async {
    if (state.codigosIdiomasOverride.isEmpty) return;
    await _persistir(state.copyWith(codigosIdiomasOverride: const []));
  }

  Future<void> limpiarTopics() async {
    if (state.slugsTopics.isEmpty) return;
    await _persistir(state.copyWith(slugsTopics: const []));
  }

  Future<void> limpiarTodo() async {
    await _persistir(FiltrosTransversales.vacios);
  }

  /// Llamado al cambiar el idioma de UI en Ajustes. Si el usuario sólo
  /// tenía un idioma fijado como override (probablemente heredado del
  /// idioma UI anterior), lo cambia por el nuevo. Si tenía varios,
  /// respetamos su elección — es señal de que quería ver contenido en
  /// varios idiomas a propósito.
  Future<void> adoptarIdiomaUi(String? nuevoCodigoUi) async {
    if (nuevoCodigoUi == null) return;
    if (!EstadoIdiomaContenido.idiomasSoportados.contains(nuevoCodigoUi)) return;
    if (state.codigosIdiomasOverride.length <= 1) {
      await _persistir(
        state.copyWith(codigosIdiomasOverride: [nuevoCodigoUi]),
      );
    }
  }
}

final filtrosTransversalesProvider =
    StateNotifierProvider<FiltrosTransversalesNotifier, FiltrosTransversales>(
        (ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  return FiltrosTransversalesNotifier(sp);
});

/// Códigos de idioma que efectivamente se aplican como filtro de
/// contenido. Compone:
///   - override del usuario en `filtrosTransversales` si existe,
///   - en su defecto, la política central
///     (`idiomasContenidoEfectivosProvider`).
///
/// Se expone como un provider derivado para que las pestañas no tengan
/// que repetir la lógica de fallback en cada una.
final idiomasEfectivosConOverrideProvider = Provider<List<String>>((ref) {
  final transversal = ref.watch(filtrosTransversalesProvider);
  if (transversal.codigosIdiomasOverride.isNotEmpty) {
    return List.unmodifiable(transversal.codigosIdiomasOverride);
  }
  return ref.watch(idiomasContenidoEfectivosProvider);
});

/// Pequeño helper para `unawaited` sin importar `dart:async` aquí.
void unawaited(Future<void> _) {}
