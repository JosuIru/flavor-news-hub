import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/preferences_provider.dart';

/// Modos de política de idioma del contenido — cómo decide la app qué
/// idiomas pedir al backend cuando lista items, vídeos, radios y
/// podcasts.
///
/// Antes cada pestaña gestionaba sus chips de idioma por separado y
/// "Idioma de la interfaz" sólo se sincronizaba con Feed. Eso producía
/// resultados inconsistentes entre Feed/Vídeos/TV/Podcasts/Radios.
/// Ahora hay una sola fuente de verdad.
enum ModoIdiomaContenido {
  /// El idioma de contenido sigue al idioma de UI (o al locale del
  /// sistema si "Seguir sistema"). Cambia automáticamente con
  /// Ajustes → Idioma de la interfaz. Default histórico.
  seguirInterfaz,

  /// Lista de idiomas elegida explícitamente por el usuario,
  /// independiente del idioma de UI. Útil para gente que tiene la
  /// app en castellano pero quiere ver titulares en es+ca+eu.
  manual,

  /// Sin filtro de idioma — la app pide todo el contenido y muestra
  /// lo que el backend devuelva. Útil para descubrir medios en
  /// idiomas que el usuario no domina pero le interesan.
  desactivado,
}

@immutable
class EstadoIdiomaContenido {
  const EstadoIdiomaContenido({
    required this.modo,
    required this.idiomasManuales,
  });

  final ModoIdiomaContenido modo;

  /// Lista persistida sólo cuando `modo == manual`. En el resto de
  /// modos no se usa pero la guardamos para que volver a `manual`
  /// recupere la última configuración del usuario sin pedirla otra
  /// vez.
  final List<String> idiomasManuales;

  /// Idiomas soportados por el sistema de filtros. Coincide con los
  /// locales de la UI más algunos extras frecuentes en medios
  /// alternativos (pt para Brasil/Portugal, fr para Francia/Quebec).
  static const Set<String> idiomasSoportados = {
    'es', 'ca', 'eu', 'gl', 'en', 'pt', 'fr',
  };

  static const inicial = EstadoIdiomaContenido(
    modo: ModoIdiomaContenido.seguirInterfaz,
    idiomasManuales: <String>[],
  );

  EstadoIdiomaContenido copyWith({
    ModoIdiomaContenido? modo,
    List<String>? idiomasManuales,
  }) {
    return EstadoIdiomaContenido(
      modo: modo ?? this.modo,
      idiomasManuales: idiomasManuales ?? this.idiomasManuales,
    );
  }

  Map<String, dynamic> toJson() => {
        'modo': modo.name,
        'idiomas_manuales': idiomasManuales,
      };

  factory EstadoIdiomaContenido.fromJson(Map<String, dynamic> json) {
    final modoTexto = (json['modo'] ?? 'seguirInterfaz').toString();
    final modo = ModoIdiomaContenido.values.firstWhere(
      (m) => m.name == modoTexto,
      orElse: () => ModoIdiomaContenido.seguirInterfaz,
    );
    final manualesRaw = json['idiomas_manuales'];
    final manuales = (manualesRaw is List)
        ? manualesRaw
            .map((e) => e.toString())
            .where(idiomasSoportados.contains)
            .toList(growable: false)
        : const <String>[];
    return EstadoIdiomaContenido(modo: modo, idiomasManuales: manuales);
  }
}

class _ClavesPref {
  static const estado = 'fnh.pref.politicaIdiomaContenido';
}

class PoliticaIdiomaContenidoNotifier extends StateNotifier<EstadoIdiomaContenido> {
  PoliticaIdiomaContenidoNotifier(this._sharedPrefs)
      : super(_leerEstadoInicial(_sharedPrefs));

  final SharedPreferences _sharedPrefs;

  static EstadoIdiomaContenido _leerEstadoInicial(SharedPreferences sp) {
    final raw = sp.getString(_ClavesPref.estado);
    if (raw == null || raw.isEmpty) return EstadoIdiomaContenido.inicial;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return EstadoIdiomaContenido.fromJson(decoded);
      }
    } catch (_) {
      // JSON corrupto: arrancamos con default.
    }
    return EstadoIdiomaContenido.inicial;
  }

  Future<void> establecerModo(ModoIdiomaContenido modo) async {
    await _persistir(state.copyWith(modo: modo));
  }

  Future<void> establecerIdiomasManuales(List<String> codigos) async {
    final limpios = codigos
        .where(EstadoIdiomaContenido.idiomasSoportados.contains)
        .toSet()
        .toList()
      ..sort();
    await _persistir(state.copyWith(idiomasManuales: limpios));
  }

  Future<void> alternarIdiomaManual(String codigo) async {
    if (!EstadoIdiomaContenido.idiomasSoportados.contains(codigo)) return;
    final actual = state.idiomasManuales.toSet();
    if (actual.contains(codigo)) {
      actual.remove(codigo);
    } else {
      actual.add(codigo);
    }
    await establecerIdiomasManuales(actual.toList());
  }

  Future<void> _persistir(EstadoIdiomaContenido nuevo) async {
    state = nuevo;
    await _sharedPrefs.setString(_ClavesPref.estado, jsonEncode(nuevo.toJson()));
  }
}

final politicaIdiomaContenidoProvider =
    StateNotifierProvider<PoliticaIdiomaContenidoNotifier, EstadoIdiomaContenido>(
  (ref) {
    final sharedPrefs = ref.watch(sharedPreferencesProvider);
    return PoliticaIdiomaContenidoNotifier(sharedPrefs);
  },
);

/// Lista efectiva de códigos de idioma que las pestañas de contenido
/// (Feed, Vídeos, TV, Podcasts, Radios) deben aplicar como filtro.
///
/// Resolución según modo:
///   - `desactivado` → lista vacía (sin filtro).
///   - `manual` → idiomas manuales fijados por el usuario.
///   - `seguirInterfaz` → el idioma de UI o, si está en "Seguir
///     sistema", el locale del dispositivo. Se restringe al set
///     soportado para no enviar `de` o `it` al backend (no hay
///     fuentes en esos idiomas).
final idiomasContenidoEfectivosProvider = Provider<List<String>>((ref) {
  final estado = ref.watch(politicaIdiomaContenidoProvider);
  switch (estado.modo) {
    case ModoIdiomaContenido.desactivado:
      return const <String>[];
    case ModoIdiomaContenido.manual:
      return List.unmodifiable(estado.idiomasManuales);
    case ModoIdiomaContenido.seguirInterfaz:
      final codigoUi = ref.watch(
        preferenciasProvider.select((p) => p.codigoIdioma),
      );
      String codigoEfectivo = codigoUi ?? '';
      if (codigoEfectivo.isEmpty) {
        codigoEfectivo = PlatformDispatcher.instance.locale.languageCode;
      }
      if (EstadoIdiomaContenido.idiomasSoportados.contains(codigoEfectivo)) {
        return List.unmodifiable([codigoEfectivo]);
      }
      return const <String>[];
  }
});
