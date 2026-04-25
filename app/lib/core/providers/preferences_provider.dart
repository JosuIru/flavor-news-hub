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
    required this.territorioBase,
    required this.onboardingCompleto,
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

  /// Territorio base del usuario — clave del `TerritoryNormalizer`
  /// (p. ej. `bizkaia`, `argentina`, `euskal herria`). Cadena vacía =
  /// sin preferencia: feed y mapa se muestran sin ponderación local.
  /// Cuando está fijado, los contenidos cuyo territorio coincide (por
  /// ciudad, región, país o red) ganan prioridad editorial sobre los
  /// globales sin ocultar nada.
  final String territorioBase;

  /// `true` cuando el usuario ha pasado por (o saltado explícitamente)
  /// el onboarding de primer arranque. Se usa para no volver a mostrar
  /// el sheet de "Mi territorio" en siguientes aperturas de la app.
  final bool onboardingCompleto;

  PreferenciasUsuario copyWith({
    ThemeMode? modoTema,
    String? codigoIdioma,
    bool borrarCodigoIdioma = false,
    String? urlInstanciaBackend,
    double? escalaTexto,
    String? territorioBase,
    bool? onboardingCompleto,
  }) {
    return PreferenciasUsuario(
      modoTema: modoTema ?? this.modoTema,
      codigoIdioma: borrarCodigoIdioma ? null : (codigoIdioma ?? this.codigoIdioma),
      urlInstanciaBackend: urlInstanciaBackend ?? this.urlInstanciaBackend,
      escalaTexto: escalaTexto ?? this.escalaTexto,
      territorioBase: territorioBase ?? this.territorioBase,
      onboardingCompleto: onboardingCompleto ?? this.onboardingCompleto,
    );
  }
}

/// Claves internas de SharedPreferences. Prefijo para no colisionar con nada.
class _Claves {
  static const themeMode = 'fnh.pref.themeMode';
  static const localeCode = 'fnh.pref.localeCode';
  static const backendUrl = 'fnh.pref.backendUrl';
  static const textScale = 'fnh.pref.textScale';
  static const territorioBase = 'fnh.pref.territorioBase';
  static const onboardingCompleto = 'fnh.pref.onboardingCompleto';
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
      urlInstanciaBackend: _saneoUrlBackend(sp.getString(_Claves.backendUrl)),
      escalaTexto: _saneoEscalaTexto(sp.getDouble(_Claves.textScale)),
      territorioBase: sp.getString(_Claves.territorioBase) ?? '',
      onboardingCompleto: sp.getBool(_Claves.onboardingCompleto) ?? false,
    );
  }

  /// Valida la URL guardada antes de devolverla. Si está corrupta (no
  /// parsea, no tiene scheme http/https o no tiene host), cae al default
  /// — así una SharedPreferences corrupta no rompe la app al arrancar.
  static String _saneoUrlBackend(String? valorGuardado) {
    if (valorGuardado == null || valorGuardado.trim().isEmpty) {
      return urlInstanciaOficialDefault;
    }
    final uri = Uri.tryParse(valorGuardado.trim());
    if (uri == null) return urlInstanciaOficialDefault;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return urlInstanciaOficialDefault;
    if (uri.host.isEmpty) return urlInstanciaOficialDefault;
    return valorGuardado.trim();
  }

  /// Limita la escala de texto a un rango razonable. Un valor corrupto
  /// (negativo, NaN o exagerado) podría hacer la UI ilegible o crashear
  /// algunos widgets de texto.
  static double _saneoEscalaTexto(double? valorGuardado) {
    if (valorGuardado == null || valorGuardado.isNaN) return 1.0;
    return valorGuardado.clamp(0.8, 1.6);
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

  Future<void> establecerTerritorioBase(String clave) async {
    final claveLimpia = clave.trim();
    state = state.copyWith(territorioBase: claveLimpia);
    if (claveLimpia.isEmpty) {
      await _sharedPrefs.remove(_Claves.territorioBase);
    } else {
      await _sharedPrefs.setString(_Claves.territorioBase, claveLimpia);
    }
  }

  Future<void> marcarOnboardingCompleto() async {
    state = state.copyWith(onboardingCompleto: true);
    await _sharedPrefs.setBool(_Claves.onboardingCompleto, true);
  }
}

final preferenciasProvider =
    StateNotifierProvider<PreferenciasNotifier, PreferenciasUsuario>((ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  return PreferenciasNotifier(sharedPrefs);
});
