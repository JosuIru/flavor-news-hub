import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path_utils;
import 'package:path_provider/path_provider.dart';

/// Cache en disco del catálogo que sirvió el backend la última vez que
/// respondió. Prioridad al cargar el seed:
///  1. Cache en disco (si existe y no está corrupto) — es lo más fresco.
///  2. Seed bundleado en el APK — fallback de fábrica.
///
/// Así el modo autónomo refleja la realidad actual del usuario: si
/// instaló la app hace 6 meses y el backend ha añadido 20 fuentes desde
/// entonces, el cache en disco las tiene aunque el bundleado no.
class SeedCache {
  static const String _dirSubcarpeta = 'seed';

  static Future<File> _fichero(String nombre) async {
    final dir = await getApplicationSupportDirectory();
    final seedDir = Directory(path_utils.join(dir.path, _dirSubcarpeta));
    if (!await seedDir.exists()) {
      await seedDir.create(recursive: true);
    }
    return File(path_utils.join(seedDir.path, nombre));
  }

  /// Guarda una respuesta del backend como cache del seed. `nombre` debe
  /// coincidir con el bundleado: `sources.json`, `radios.json`,
  /// `collectives.json`.
  static Future<void> guardar(String nombre, List<dynamic> lista) async {
    try {
      final f = await _fichero(nombre);
      await f.writeAsString(jsonEncode(lista));
    } catch (_) {
      // Un fallo al guardar cache no debe romper el flujo; simplemente
      // caerá al bundleado la próxima vez.
    }
  }

  /// Intenta leer el cache; devuelve null si no existe o está corrupto.
  static Future<List<dynamic>?> leer(String nombre) async {
    try {
      final f = await _fichero(nombre);
      if (!await f.exists()) return null;
      final decodificado = jsonDecode(await f.readAsString());
      if (decodificado is List) return decodificado;
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Provider sintético: al arrancar la app escribimos aquí cada vez que un
/// fetch al backend tiene éxito. No hay estado reactivo — es un trigger
/// de side-effects puro.
void guardarSnapshotSeed(String nombre, List<dynamic> lista) {
  // Fire-and-forget: el caller no necesita esperar.
  SeedCache.guardar(nombre, lista);
}
