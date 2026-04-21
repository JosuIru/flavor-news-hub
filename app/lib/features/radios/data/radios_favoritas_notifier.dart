import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/preferences_provider.dart';

/// Conjunto de IDs de radios marcadas como favoritas. Se usa para:
///  - pintar un corazón en la fila,
///  - ordenar la lista de radios con las favoritas al principio.
///
/// Persistido en SharedPreferences como lista de strings — sqflite sería
/// overkill para unos pocos IDs y evita una migración del esquema.
const String _clavePref = 'fnh.pref.radiosFavoritas';

final radiosFavoritasProvider =
    StateNotifierProvider<RadiosFavoritasNotifier, Set<int>>((ref) {
  return RadiosFavoritasNotifier(ref.watch(sharedPreferencesProvider));
});

class RadiosFavoritasNotifier extends StateNotifier<Set<int>> {
  RadiosFavoritasNotifier(this._sp) : super(_leerInicial(_sp));

  final SharedPreferences _sp;

  static Set<int> _leerInicial(SharedPreferences sp) {
    final lista = sp.getStringList(_clavePref) ?? const [];
    return lista.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toSet();
  }

  bool esFavorita(int idRadio) => state.contains(idRadio);

  Future<void> alternar(int idRadio) async {
    if (idRadio <= 0) return;
    final nuevo = Set<int>.from(state);
    if (!nuevo.remove(idRadio)) {
      nuevo.add(idRadio);
    }
    state = Set.unmodifiable(nuevo);
    await _sp.setStringList(_clavePref, nuevo.map((e) => e.toString()).toList());
  }
}
