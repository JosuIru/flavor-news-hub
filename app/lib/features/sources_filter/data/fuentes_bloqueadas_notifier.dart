import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/preferences_provider.dart';

/// Conjunto de IDs de fuentes que el usuario ha silenciado. Los items
/// cuyo `source.id` esté en este set no aparecerán en el feed local.
///
/// Filtro client-side por dos razones:
///  - el catálogo curado es global (decisión editorial de la instancia),
///    pero cada persona puede tener preferencias distintas;
///  - no ensucia el backend ni requiere tokens/cuentas — persistencia en
///    SharedPreferences basta.
const String _clavePref = 'fnh.pref.fuentesBloqueadas';

final fuentesBloqueadasProvider =
    StateNotifierProvider<FuentesBloqueadasNotifier, Set<int>>((ref) {
  return FuentesBloqueadasNotifier(ref.watch(sharedPreferencesProvider));
});

class FuentesBloqueadasNotifier extends StateNotifier<Set<int>> {
  FuentesBloqueadasNotifier(this._sp) : super(_leerInicial(_sp));

  final SharedPreferences _sp;

  static Set<int> _leerInicial(SharedPreferences sp) {
    final lista = sp.getStringList(_clavePref) ?? const [];
    return lista.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toSet();
  }

  bool estaBloqueada(int idFuente) => state.contains(idFuente);

  Future<void> alternar(int idFuente) async {
    if (idFuente <= 0) return;
    final nuevo = Set<int>.from(state);
    if (!nuevo.remove(idFuente)) {
      nuevo.add(idFuente);
    }
    state = Set.unmodifiable(nuevo);
    await _sp.setStringList(_clavePref, nuevo.map((e) => e.toString()).toList());
  }

  Future<void> limpiar() async {
    state = const <int>{};
    await _sp.remove(_clavePref);
  }
}
