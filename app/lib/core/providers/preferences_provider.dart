import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias persistidas del usuario: tema, idioma de UI, URL de la
/// instancia backend y tamaño de texto.
///
/// Inmutable: los cambios se aplican con `copyWith` y se persisten desde
/// el notifier.
@immutable
class PreferenciasUsuario {
  const PreferenciasUsuario({
    required this.modoTema,
    required this.codigoIdioma,
    required this.urlInstanciaBackend,
    required this.escalaTexto,
  });

  /// ThemeMode de Flutter (`system`, `light`, `dark`).
  final ThemeMode modoTema;

  /// Código ISO del idioma de UI. `null` = seguir sistema.
  final String? codigoIdioma;

  /// URL de la instancia backend (namespace `flavor-news/v1`). Por defecto
  /// apunta a la instancia oficial; cualquier autohospedaje puede cambiarla.
  final String urlInstanciaBackend;

  /// Factor de escalado de texto (0.8 – 1.4). 1.0 = default del sistema.
  final double escalaTexto;

  PreferenciasUsuario copyWith({
    ThemeMode? modoTema,
    String? codigoIdioma,
    bool borrarCodigoIdioma = false,
    String? urlInstanciaBackend,
    double? escalaTexto,
  }) {
    return PreferenciasUsuario(
      modoTema: modoTema ?? this.modoTema,
      codigoIdioma: borrarCodigoIdioma ? null : (codigoIdioma ?? this.codigoIdioma),
      urlInstanciaBackend: urlInstanciaBackend ?? this.urlInstanciaBackend,
      escalaTexto: escalaTexto ?? this.escalaTexto,
    );
  }
}

/// Claves internas de SharedPreferences. Prefijo para no colisionar con nada.
class _Claves {
  static const themeMode = 'fnh.pref.themeMode';
  static const localeCode = 'fnh.pref.localeCode';
  static const backendUrl = 'fnh.pref.backendUrl';
  static const textScale = 'fnh.pref.textScale';
}

/// Valor por defecto de la URL de la instancia.
///
/// Producción: dominio oficial del proyecto (`flavor.gailu.it`). El
/// usuario puede apuntar a cualquier otro WordPress con este plugin
/// instalado desde Ajustes → URL del backend.
///
/// Para desarrollo en local con Local by Flywheel, editar este valor
/// a `http://localhost:10028/wp-json/flavor-news/v1` y mapear el
/// puerto con `adb reverse tcp:10028 tcp:10028` desde el dispositivo.
const String urlInstanciaOficialDefault = 'https://flavor.gailu.it/wp-json/flavor-news/v1';

/// Provider de SharedPreferences. Se sobreescribe en `main.dart` con la
/// instancia resuelta tras `await SharedPreferences.getInstance()`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse en main.dart con una instancia real.',
  );
});

class PreferenciasNotifier extends StateNotifier<PreferenciasUsuario> {
  PreferenciasNotifier(this._sharedPrefs) : super(_leerEstadoInicial(_sharedPrefs));

  final SharedPreferences _sharedPrefs;

  static PreferenciasUsuario _leerEstadoInicial(SharedPreferences sp) {
    final cadenaTema = sp.getString(_Claves.themeMode) ?? 'system';
    final modoTema = ThemeMode.values.firstWhere(
      (modo) => modo.name == cadenaTema,
      orElse: () => ThemeMode.system,
    );

    return PreferenciasUsuario(
      modoTema: modoTema,
      codigoIdioma: sp.getString(_Claves.localeCode),
      urlInstanciaBackend: sp.getString(_Claves.backendUrl) ?? urlInstanciaOficialDefault,
      escalaTexto: sp.getDouble(_Claves.textScale) ?? 1.0,
    );
  }

  Future<void> establecerModoTema(ThemeMode modo) async {
    state = state.copyWith(modoTema: modo);
    await _sharedPrefs.setString(_Claves.themeMode, modo.name);
  }

  Future<void> establecerIdiomaUi(String? codigoIdioma) async {
    state = state.copyWith(
      codigoIdioma: codigoIdioma,
      borrarCodigoIdioma: codigoIdioma == null,
    );
    if (codigoIdioma == null) {
      await _sharedPrefs.remove(_Claves.localeCode);
    } else {
      await _sharedPrefs.setString(_Claves.localeCode, codigoIdioma);
    }
  }

  Future<void> establecerUrlBackend(String nuevaUrl) async {
    final urlNormalizada = nuevaUrl.trim().isEmpty ? urlInstanciaOficialDefault : nuevaUrl.trim();
    state = state.copyWith(urlInstanciaBackend: urlNormalizada);
    await _sharedPrefs.setString(_Claves.backendUrl, urlNormalizada);
  }

  Future<void> establecerEscalaTexto(double escala) async {
    final escalaAcotada = escala.clamp(0.8, 1.4);
    state = state.copyWith(escalaTexto: escalaAcotada);
    await _sharedPrefs.setDouble(_Claves.textScale, escalaAcotada);
  }
}

final preferenciasProvider =
    StateNotifierProvider<PreferenciasNotifier, PreferenciasUsuario>((ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  return PreferenciasNotifier(sharedPrefs);
});
