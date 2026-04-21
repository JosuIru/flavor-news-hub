import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/preferences_provider.dart';

/// Conjunto de IDs de fuentes de vídeo (canales YouTube/PeerTube/etc.) que
/// el usuario ha marcado como favoritas. Sirven para:
///  - distinguir visualmente en la grid ("mis canales"),
///  - activar el filtro "sólo mis canales" si lo quiere.
const String _clavePref = 'fnh.pref.canalesFavoritos';

final canalesFavoritosProvider =
    StateNotifierProvider<CanalesFavoritosNotifier, Set<int>>((ref) {
  return CanalesFavoritosNotifier(ref.watch(sharedPreferencesProvider));
});

class CanalesFavoritosNotifier extends StateNotifier<Set<int>> {
  CanalesFavoritosNotifier(this._sp) : super(_leerInicial(_sp));
  final SharedPreferences _sp;

  static Set<int> _leerInicial(SharedPreferences sp) {
    final lista = sp.getStringList(_clavePref) ?? const [];
    return lista.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toSet();
  }

  bool esFavorito(int idCanal) => state.contains(idCanal);

  Future<void> alternar(int idCanal) async {
    if (idCanal <= 0) return;
    final nuevo = Set<int>.from(state);
    if (!nuevo.remove(idCanal)) {
      nuevo.add(idCanal);
    }
    state = Set.unmodifiable(nuevo);
    await _sp.setStringList(_clavePref, nuevo.map((e) => e.toString()).toList());
  }
}
