import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/models/item.dart';
import 'base_datos_local.dart';

/// Operaciones sobre la tabla `item_local`.
/// - `cachearMuchos`: upsert manteniendo flags de saved/read si ya existen.
/// - `obtenerCache`: lista ordenada por `published_at DESC`.
/// - Métodos independientes para guardar/leer sin re-escribir el payload.
class ItemsLocalesDao {
  ItemsLocalesDao(this._base);
  final BaseDatosLocal _base;

  Database get _db => _base.db;

  /// Upsert masivo: si ya existe el id, NO pisa `saved_at` ni `read_at` (las
  /// marcas del usuario sobreviven a un refresh del feed).
  Future<void> cachearMuchos(List<Item> items) async {
    if (items.isEmpty) return;
    final ahoraMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final item in items) {
      // Cacheamos también items con id negativo: los produce el seed
      // RSS y las fuentes personales, y los ids son deterministas (hash
      // de feedUrl+guid), así que re-cachearlos no duplica — sólo
      // refresca el payload. Hace falta para que el detalle offline
      // funcione al tocar un titular del feed ingerido por seed.
      batch.rawInsert('''
        INSERT INTO ${BaseDatosLocal.tablaItems}
          (id, payload_json, cached_at, saved_at, read_at)
        VALUES (?, ?, ?, NULL, NULL)
        ON CONFLICT(id) DO UPDATE SET
          payload_json = excluded.payload_json,
          cached_at    = excluded.cached_at
      ''', [item.id, jsonEncode(item.toJson()), ahoraMs]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Item>> obtenerCache({int limite = 50}) async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['payload_json'],
      orderBy: 'cached_at DESC',
      limit: limite,
    );
    return _deserializar(filas).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  }

  /// Busca un item concreto por id en el cache local. Devuelve `null`
  /// si no está — el caller decidirá si mostrar error o qué.
  Future<Item?> obtenerPorId(int idItem) async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['payload_json'],
      where: 'id = ?',
      whereArgs: [idItem],
      limit: 1,
    );
    final lista = _deserializar(filas).toList();
    return lista.isEmpty ? null : lista.first;
  }

  Future<List<Item>> obtenerGuardados() async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['payload_json'],
      where: 'saved_at IS NOT NULL',
      orderBy: 'saved_at DESC',
    );
    return _deserializar(filas).toList();
  }

  Future<Set<int>> obtenerIdsGuardados() async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['id'],
      where: 'saved_at IS NOT NULL',
    );
    return {for (final fila in filas) fila['id'] as int};
  }

  /// Lista completa de items leídos (con su payload) ordenados por la
  /// fecha en que el usuario los abrió. Usa el historial de lectura.
  Future<List<Item>> obtenerLeidos({int limite = 200}) async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['payload_json'],
      where: 'read_at IS NOT NULL',
      orderBy: 'read_at DESC',
      limit: limite,
    );
    return _deserializar(filas).toList();
  }

  Future<Set<int>> obtenerIdsLeidos({int limiteRecientes = 2000}) async {
    // Limitamos para que el set no crezca sin control: 2000 ids recientes
    // cubren cualquier caso razonable de uso continuado.
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['id'],
      where: 'read_at IS NOT NULL',
      orderBy: 'read_at DESC',
      limit: limiteRecientes,
    );
    return {for (final fila in filas) fila['id'] as int};
  }

  Future<void> alternarGuardado(Item item) async {
    // Si la fila no existe, la creamos con payload (por si el item es
    // personal y no está en cache).
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['saved_at'],
      where: 'id = ?',
      whereArgs: [item.id],
    );
    final ahoraMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (filas.isEmpty) {
      await _db.insert(BaseDatosLocal.tablaItems, {
        'id': item.id,
        'payload_json': jsonEncode(item.toJson()),
        'cached_at': ahoraMs,
        'saved_at': ahoraMs,
        'read_at': null,
      });
      return;
    }
    final yaGuardado = filas.first['saved_at'] != null;
    await _db.update(
      BaseDatosLocal.tablaItems,
      {'saved_at': yaGuardado ? null : ahoraMs},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Alterna la marca "útil" del item. Las útiles (como las guardadas)
  /// se preservan fuera del TTL del cache: el usuario las elige para
  /// aprender qué le interesa.
  Future<void> alternarUtil(Item item) async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['useful_at'],
      where: 'id = ?',
      whereArgs: [item.id],
    );
    final ahoraMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (filas.isEmpty) {
      await _db.insert(BaseDatosLocal.tablaItems, {
        'id': item.id,
        'payload_json': jsonEncode(item.toJson()),
        'cached_at': ahoraMs,
        'saved_at': null,
        'read_at': null,
        'useful_at': ahoraMs,
      });
      return;
    }
    final yaUtil = filas.first['useful_at'] != null;
    await _db.update(
      BaseDatosLocal.tablaItems,
      {'useful_at': yaUtil ? null : ahoraMs},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<List<Item>> obtenerUtiles() async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['payload_json'],
      where: 'useful_at IS NOT NULL',
      orderBy: 'useful_at DESC',
    );
    return _deserializar(filas).toList();
  }

  Future<Set<int>> obtenerIdsUtiles() async {
    final filas = await _db.query(
      BaseDatosLocal.tablaItems,
      columns: ['id'],
      where: 'useful_at IS NOT NULL',
    );
    return {for (final fila in filas) fila['id'] as int};
  }

  Future<void> marcarLeido(Item item) async {
    final ahoraMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final afectadas = await _db.update(
      BaseDatosLocal.tablaItems,
      {'read_at': ahoraMs},
      where: 'id = ?',
      whereArgs: [item.id],
    );
    if (afectadas == 0) {
      // Item aún no cacheado — insertamos la fila para preservar la marca.
      await _db.insert(BaseDatosLocal.tablaItems, {
        'id': item.id,
        'payload_json': jsonEncode(item.toJson()),
        'cached_at': ahoraMs,
        'saved_at': null,
        'read_at': ahoraMs,
      });
    }
  }

  /// Purga los items cacheados cuyo `cached_at` es anterior a `ttlCache`
  /// atrás, EXCEPTO los que el usuario guardó explícitamente.
  /// Devuelve el número de filas eliminadas.
  Future<int> purgarCacheAntiguo({Duration? ttlPersonalizado}) async {
    final ttl = ttlPersonalizado ?? BaseDatosLocal.ttlCache;
    final corteMs = DateTime.now().toUtc().subtract(ttl).millisecondsSinceEpoch;
    // Nunca purgamos lo que el usuario marcó explícitamente como
    // guardado o útil: son señales de su aprendizaje, no cache.
    final borradosPorFecha = await _db.delete(
      BaseDatosLocal.tablaItems,
      where: 'cached_at < ? AND saved_at IS NULL AND useful_at IS NULL',
      whereArgs: [corteMs],
    );

    // Tope de filas: con el seed RSS llegamos a 1000+ items por ingesta,
    // si el usuario refresca varias veces sin abrir la app la tabla
    // crece sin freno. Mantenemos como mucho N filas no-guardadas/útiles;
    // las más viejas por `cached_at` se borran. Saved/útiles siguen
    // inmunes — son del usuario, no cache.
    const tope = 2000;
    final filas = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM ${BaseDatosLocal.tablaItems} '
      'WHERE saved_at IS NULL AND useful_at IS NULL',
    );
    final total = (filas.first['c'] as int?) ?? 0;
    var borradosPorTope = 0;
    if (total > tope) {
      final exceso = total - tope;
      borradosPorTope = await _db.rawDelete(
        'DELETE FROM ${BaseDatosLocal.tablaItems} WHERE id IN ('
        'SELECT id FROM ${BaseDatosLocal.tablaItems} '
        'WHERE saved_at IS NULL AND useful_at IS NULL '
        'ORDER BY cached_at ASC LIMIT ?)',
        [exceso],
      );
    }
    return borradosPorFecha + borradosPorTope;
  }

  Iterable<Item> _deserializar(List<Map<String, Object?>> filas) {
    return filas
        .map((fila) {
          try {
            final mapa = jsonDecode(fila['payload_json'] as String) as Map<String, dynamic>;
            return Item.fromJson(mapa);
          } catch (_) {
            return null;
          }
        })
        .whereType<Item>();
  }
}
