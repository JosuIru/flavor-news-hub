import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';

/// Resultado del check de actualización de la app. Inmutable.
@immutable
class EstadoActualizacion {
  const EstadoActualizacion({
    required this.hayActualizacion,
    this.versionRemota,
    this.urlDescarga,
    this.urlRelease,
    this.changelog,
    this.esObligatoria = false,
  });

  final bool hayActualizacion;
  final String? versionRemota;
  final String? urlDescarga;
  final String? urlRelease;
  final String? changelog;
  final bool esObligatoria;

  static const sinActualizacion = EstadoActualizacion(hayActualizacion: false);
}

/// Comprueba contra `GET {instancia}/apps/check-update` si hay una
/// versión nueva del APK.
///
/// Param `forzar`:
///  - false (default): respeta cache cliente (30 min). El backend
///    también puede devolver respuesta cacheada (1h).
///  - true: salta cache cliente Y pide al backend `refresh=1` para
///    que también ignore su transient. Lo usa el botón
///    "Comprobar actualizaciones" de Ajustes — sin esto, el usuario
///    pulsaba el botón y seguía recibiendo la versión vieja del
///    transient backend hasta que expirase.
final actualizacionProvider =
    FutureProvider.family<EstadoActualizacion, bool>((ref, forzar) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ahora = DateTime.now().toUtc();

  // Cache cliente: respetamos a no ser que se haya pedido `forzar`.
  if (!forzar) {
    final cacheadoRaw = prefs.getString(_ClavesPref.ultimoResultado);
    final cacheadoTs = prefs.getInt(_ClavesPref.ultimoTimestamp) ?? 0;
    final tieneCacheValido =
        cacheadoRaw != null && ahora.millisecondsSinceEpoch - cacheadoTs < _ttlMs;
    if (tieneCacheValido) {
      final desdeCache = _parsear(cacheadoRaw, prefs);
      if (desdeCache != null) return desdeCache;
    }
  }

  final info = await PackageInfo.fromPlatform();
  final http.Client cliente = ref.watch(httpClientProvider);
  final api = ref.watch(flavorNewsApiProvider);
  var pathBase = api.baseUrl.path;
  while (pathBase.endsWith('/')) {
    pathBase = pathBase.substring(0, pathBase.length - 1);
  }
  final uri = api.baseUrl.replace(
    path: '$pathBase/apps/check-update',
    queryParameters: {
      'version': info.version,
      'platform': 'android',
      'channel': 'stable',
      if (forzar) 'refresh': '1',
    },
  );

  try {
    final respuesta = await cliente
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      return EstadoActualizacion.sinActualizacion;
    }
    final cuerpo = jsonDecode(respuesta.body);
    if (cuerpo is! Map<String, dynamic>) {
      return EstadoActualizacion.sinActualizacion;
    }
    await prefs.setString(_ClavesPref.ultimoResultado, respuesta.body);
    await prefs.setInt(
      _ClavesPref.ultimoTimestamp,
      ahora.millisecondsSinceEpoch,
    );
    return _parsear(respuesta.body, prefs) ??
        EstadoActualizacion.sinActualizacion;
  } catch (_) {
    return EstadoActualizacion.sinActualizacion;
  }
});

EstadoActualizacion? _parsear(String raw, SharedPreferences prefs) {
  try {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return null;
    final disponible = data['update_available'] == true;
    if (!disponible) return EstadoActualizacion.sinActualizacion;
    final versionRemota = (data['version'] ?? '').toString();
    final descartada = prefs.getString(_ClavesPref.versionDescartada);
    if (descartada != null && descartada == versionRemota) {
      // El usuario ya dijo "no ahora" para esta versión exacta.
      return EstadoActualizacion.sinActualizacion;
    }
    return EstadoActualizacion(
      hayActualizacion: true,
      versionRemota: versionRemota,
      urlDescarga: (data['download_url'] ?? '').toString(),
      urlRelease: (data['release_url'] ?? '').toString(),
      changelog: (data['changelog'] ?? '').toString(),
      esObligatoria: data['is_mandatory'] == true,
    );
  } catch (_) {
    return null;
  }
}

/// Marca una versión como "descartada por el usuario". No se le volverá
/// a ofrecer hasta que salga una versión distinta. Si la versión es
/// obligatoria, el diálogo no da opción a descartar — esto no llega
/// a llamarse en ese caso.
Future<void> descartarActualizacion(
  SharedPreferences prefs,
  String version,
) async {
  await prefs.setString(_ClavesPref.versionDescartada, version);
}

class _ClavesPref {
  static const ultimoResultado = 'fnh.pref.actualizacion.respuesta';
  static const ultimoTimestamp = 'fnh.pref.actualizacion.ts';
  static const versionDescartada = 'fnh.pref.actualizacion.descartada';
}

const _ttlMs = 30 * 60 * 1000; // 30 min en ms
