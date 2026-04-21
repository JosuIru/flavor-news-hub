import 'package:path/path.dart' as path_utils;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (sqflite) para cache offline, guardados y leídos.
///
/// Una sola tabla `item_local` con:
///  - `payload_json`: el Item serializado (para no perder datos si el
///    backend desaparece).
///  - `cached_at`: cuándo se guardó. Se purga tras `purgarCacheAntiguo()`.
///  - `saved_at`: si no es null, el usuario lo marcó como guardado (NO se purga).
///  - `read_at`: si no es null, el usuario abrió el detalle.
///
/// Así tres funcionalidades (cache, guardados, leídos) comparten fila sin
/// duplicar datos y el flujo de UX es consistente: un guardado es algo que
/// el usuario quiere conservar, independientemente de que siga en el feed.
class BaseDatosLocal {
  static const String _nombreFichero = 'fnh.db';
  static const int _versionEsquema = 1;
  static const String tablaItems = 'item_local';

  /// TTL por defecto del cache: los items no-guardados se purgan tras 7 días.
  static const Duration ttlCache = Duration(days: 7);

  BaseDatosLocal._(this._db);

  final Database _db;
  Database get db => _db;

  static Future<BaseDatosLocal> abrir() async {
    final directorio = await getDatabasesPath();
    final rutaCompleta = path_utils.join(directorio, _nombreFichero);
    final db = await openDatabase(
      rutaCompleta,
      version: _versionEsquema,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $tablaItems (
            id INTEGER PRIMARY KEY,
            payload_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            saved_at INTEGER,
            read_at INTEGER
          );
        ''');
        await database.execute('CREATE INDEX idx_saved_at ON $tablaItems (saved_at);');
        await database.execute('CREATE INDEX idx_read_at ON $tablaItems (read_at);');
        await database.execute('CREATE INDEX idx_cached_at ON $tablaItems (cached_at);');
      },
    );
    return BaseDatosLocal._(db);
  }

  Future<void> cerrar() => _db.close();
}
