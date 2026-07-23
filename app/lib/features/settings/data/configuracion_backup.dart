import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/item.dart';
import '../../history/data/items_locales_dao.dart';

/// Serializa y restaura la configuración del usuario a un mapa JSON para
/// que sobreviva a reinstalaciones y saltos entre orígenes de instalación
/// (F-Droid ↔ GitHub), donde el cambio de firma obliga a desinstalar y
/// Android borra todos los datos. Sin cuentas ni nube: el usuario guarda
/// el fichero donde quiera y lo restaura cuando le convenga.
///
/// Incluye: preferencias (idioma, territorio, URL del backend, tema,
/// notificaciones, favoritos de radio/vídeo, fuentes personales…) y los
/// artículos guardados/útiles con su payload completo.
class ConfiguracionBackup {
  const ConfiguracionBackup._();

  static const int versionFormato = 1;
  static const String _marcaApp = 'flavor-news-hub';

  /// Claves de SharedPreferences que NO exportamos: caché, estado efímero
  /// del worker, datos de widgets y último error. Todo lo demás bajo `fnh`
  /// es configuración del usuario y sí se incluye (allowlist implícita por
  /// prefijo `fnh`, denylist explícita aquí).
  static const List<String> _clavesExcluidas = [
    'fnh.pref.actualizacion.',        // caché del check de actualización
    'fnh.pref.notifActiva',           // derivado runtime del worker
    'fnh.pref.notifUltimaComprobacion',
    'fnh.error.',                     // último error registrado
    'fnh.titulares',                  // datos del widget de titulares
    'fnh_titulares',
    'fnh.radio.ultimaEmisora',        // runtime del modo coche/bluetooth
    'fnh.worker.',                    // claves internas del worker
    'fnh.db',                         // metadatos de la BD
  ];

  static bool _excluida(String clave) {
    for (final prefijo in _clavesExcluidas) {
      if (clave == prefijo || clave.startsWith(prefijo)) return true;
    }
    return false;
  }

  /// Construye el mapa completo de la copia. Los artículos guardados/útiles
  /// salen de SQLite con su payload íntegro.
  static Future<Map<String, dynamic>> construir(
    SharedPreferences prefs,
    ItemsLocalesDao dao,
  ) async {
    final prefsMap = <String, dynamic>{};
    for (final clave in prefs.getKeys()) {
      if (!clave.startsWith('fnh')) continue;
      if (_excluida(clave)) continue;
      final valor = prefs.get(clave);
      if (valor == null) continue;
      prefsMap[clave] = _envolver(valor);
    }
    final guardados = await dao.obtenerGuardados(limite: 100000);
    final utiles = await dao.obtenerUtiles(limite: 100000);
    return {
      'app': _marcaApp,
      'formato': versionFormato,
      'exportado_en': DateTime.now().toUtc().toIso8601String(),
      'prefs': prefsMap,
      'items': {
        'guardados': guardados.map((i) => i.toJson()).toList(),
        'utiles': utiles.map((i) => i.toJson()).toList(),
      },
    };
  }

  /// Restaura la copia sobre las preferencias y la BD. Devuelve un resumen
  /// de lo restaurado. Lanza [FormatException] si el fichero no es una
  /// copia válida de esta app.
  static Future<ResumenRestauracion> restaurar(
    Map<String, dynamic> datos,
    SharedPreferences prefs,
    ItemsLocalesDao dao,
  ) async {
    if (datos['app'] != _marcaApp || datos['prefs'] is! Map) {
      throw const FormatException(
        'El fichero no parece una copia de seguridad de Flavor News Hub.',
      );
    }
    final prefsMap = (datos['prefs'] as Map);
    var prefsRestauradas = 0;
    for (final entrada in prefsMap.entries) {
      final clave = entrada.key.toString();
      if (!clave.startsWith('fnh')) continue;
      if (_excluida(clave)) continue;
      if (await _desenvolverYGuardar(prefs, clave, entrada.value)) {
        prefsRestauradas++;
      }
    }

    final items = datos['items'];
    final guardados = items is Map ? _parsearItems(items['guardados']) : const <Item>[];
    final utiles = items is Map ? _parsearItems(items['utiles']) : const <Item>[];
    await dao.restaurarMarcados(guardados: guardados, utiles: utiles);

    return ResumenRestauracion(
      prefs: prefsRestauradas,
      guardados: guardados.length,
      utiles: utiles.length,
    );
  }

  static List<Item> _parsearItems(Object? bruto) {
    if (bruto is! List) return const [];
    final items = <Item>[];
    for (final elemento in bruto) {
      if (elemento is Map) {
        try {
          items.add(Item.fromJson(Map<String, dynamic>.from(elemento)));
        } catch (_) {
          // Un item corrupto no debe abortar la restauración completa.
        }
      }
    }
    return items;
  }

  // --- Serialización tipada de SharedPreferences ---
  // Guardamos el tipo junto al valor porque JSON no distingue int/double
  // y SharedPreferences necesita el setter correcto al restaurar.

  static Map<String, dynamic> _envolver(Object valor) {
    if (valor is bool) return {'t': 'bool', 'v': valor};
    if (valor is int) return {'t': 'int', 'v': valor};
    if (valor is double) return {'t': 'double', 'v': valor};
    if (valor is List) {
      return {'t': 'stringList', 'v': valor.map((e) => '$e').toList()};
    }
    return {'t': 'string', 'v': '$valor'};
  }

  static Future<bool> _desenvolverYGuardar(
    SharedPreferences prefs,
    String clave,
    Object? envuelto,
  ) async {
    if (envuelto is! Map) return false;
    final tipo = envuelto['t'];
    final valor = envuelto['v'];
    if (valor == null) return false;
    try {
      switch (tipo) {
        case 'bool':
          await prefs.setBool(clave, valor as bool);
          return true;
        case 'int':
          await prefs.setInt(clave, (valor as num).toInt());
          return true;
        case 'double':
          await prefs.setDouble(clave, (valor as num).toDouble());
          return true;
        case 'stringList':
          await prefs.setStringList(
            clave,
            (valor as List).map((e) => '$e').toList(),
          );
          return true;
        case 'string':
          await prefs.setString(clave, '$valor');
          return true;
      }
    } catch (_) {
      // Tipo inesperado en el fichero: saltamos esa clave sin romper.
    }
    return false;
  }
}

/// Resultado de una restauración, para informar al usuario.
class ResumenRestauracion {
  const ResumenRestauracion({
    required this.prefs,
    required this.guardados,
    required this.utiles,
  });

  final int prefs;
  final int guardados;
  final int utiles;
}
