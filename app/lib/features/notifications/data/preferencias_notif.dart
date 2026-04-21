import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/preferences_provider.dart';

/// Frecuencias posibles para la comprobación de titulares nuevos.
/// WorkManager en Android tiene un mínimo de 15 minutos por periódica,
/// así que cualquier valor más bajo sería ignorado por el sistema.
enum FrecuenciaNotif {
  nunca(0),
  cadaHora(60),
  cada3h(180),
  cada6h(360),
  cada12h(720),
  cada24h(1440);

  const FrecuenciaNotif(this.minutos);
  final int minutos;

  bool get esActiva => minutos > 0;
}

/// Preferencias del usuario sobre las notificaciones locales.
class PreferenciasNotif {
  const PreferenciasNotif({
    required this.frecuencia,
    required this.ultimaComprobacionUtc,
  });

  final FrecuenciaNotif frecuencia;
  final DateTime? ultimaComprobacionUtc;

  PreferenciasNotif copyWith({
    FrecuenciaNotif? frecuencia,
    DateTime? ultimaComprobacionUtc,
    bool limpiarUltimaComprobacion = false,
  }) {
    return PreferenciasNotif(
      frecuencia: frecuencia ?? this.frecuencia,
      ultimaComprobacionUtc: limpiarUltimaComprobacion
          ? null
          : (ultimaComprobacionUtc ?? this.ultimaComprobacionUtc),
    );
  }

  static const PreferenciasNotif porDefecto = PreferenciasNotif(
    frecuencia: FrecuenciaNotif.nunca,
    ultimaComprobacionUtc: null,
  );
}

const String _clavePrefFrecuencia = 'fnh.pref.notifFrecuencia';
const String _clavePrefUltimaComprob = 'fnh.pref.notifUltimaComprobacion';

final preferenciasNotifProvider =
    StateNotifierProvider<PreferenciasNotifNotifier, PreferenciasNotif>((ref) {
  return PreferenciasNotifNotifier(ref.watch(sharedPreferencesProvider));
});

class PreferenciasNotifNotifier extends StateNotifier<PreferenciasNotif> {
  PreferenciasNotifNotifier(this._sp) : super(_leerInicial(_sp));

  final SharedPreferences _sp;

  static PreferenciasNotif _leerInicial(SharedPreferences sp) {
    final codigo = sp.getString(_clavePrefFrecuencia);
    final frecuencia = FrecuenciaNotif.values.firstWhere(
      (f) => f.name == codigo,
      orElse: () => FrecuenciaNotif.nunca,
    );
    final ultimaRaw = sp.getString(_clavePrefUltimaComprob);
    return PreferenciasNotif(
      frecuencia: frecuencia,
      ultimaComprobacionUtc: ultimaRaw != null ? DateTime.tryParse(ultimaRaw) : null,
    );
  }

  Future<void> establecerFrecuencia(FrecuenciaNotif frecuencia) async {
    state = state.copyWith(frecuencia: frecuencia);
    await _sp.setString(_clavePrefFrecuencia, frecuencia.name);
  }

  Future<void> marcarComprobado(DateTime cuandoUtc) async {
    state = state.copyWith(ultimaComprobacionUtc: cuandoUtc);
    await _sp.setString(_clavePrefUltimaComprob, cuandoUtc.toIso8601String());
  }
}
