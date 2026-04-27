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
/// Canal por defecto. Hoy no hay UI para conmutar a `beta`; cuando se
/// añada, este valor saldrá de preferencias y el cache cliente se
/// segmentará automáticamente porque las claves llevan el canal en su
/// nombre.
const String _canalActualPorDefecto = 'stable';

final actualizacionProvider =
    FutureProvider.family<EstadoActualizacion, bool>((ref, forzar) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final ahora = DateTime.now().toUtc();
  const canalActual = _canalActualPorDefecto;
  final claveResultado = _ClavesPref.ultimoResultadoPorCanal(canalActual);
  final claveTimestamp = _ClavesPref.ultimoTimestampPorCanal(canalActual);

  // Cache cliente: respetamos a no ser que se haya pedido `forzar`.
  if (!forzar) {
    final cacheadoRaw = prefs.getString(claveResultado);
    final cacheadoTs = prefs.getInt(claveTimestamp) ?? 0;
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
      'channel': canalActual,
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
    await prefs.setString(claveResultado, respuesta.body);
    await prefs.setInt(claveTimestamp, ahora.millisecondsSinceEpoch);
    return _parsear(respuesta.body, prefs) ??
        EstadoActualizacion.sinActualizacion;
  } catch (error) {
    // Check transitorio en background: no avisamos al usuario, pero
    // dejamos rastro para poder debuggear si todos los usuarios dejan
    // de ver actualizaciones de golpe.
    debugPrint('[Actualizaciones] check falló: $error');
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
    final urlDescarga = (data['download_url'] ?? '').toString();
    // Defensa-en-profundidad: si el backend está comprometido (o un MITM
    // en una conexión HTTP — el usuario puede haber configurado una
    // instancia self-host sin TLS), la URL de descarga podría apuntar a
    // un APK malicioso. Forzamos que sea HTTPS en github.com — el origen
    // canónico de las releases. Quien fork-ee a otro host tendrá que
    // modificar también esta lista.
    if (!urlDescargaParecesegura(urlDescarga)) {
      debugPrint('[Actualizaciones] URL descarga rechazada: $urlDescarga');
      return EstadoActualizacion.sinActualizacion;
    }
    return EstadoActualizacion(
      hayActualizacion: true,
      versionRemota: versionRemota,
      urlDescarga: urlDescarga,
      urlRelease: (data['release_url'] ?? '').toString(),
      changelog: (data['changelog'] ?? '').toString(),
      esObligatoria: data['is_mandatory'] == true,
    );
  } catch (error) {
    debugPrint('[Actualizaciones] parseo falló: $error');
    return null;
  }
}

/// Lista blanca mínima del origen del APK: HTTPS y dominio github.com.
/// Pública para que `AvisoActualizacion` pueda re-validar antes de
/// descargar — la respuesta del backend pudo cachearse antes de que
/// añadiéramos esta validación.
bool urlDescargaParecesegura(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return false;
  if (parsed.scheme != 'https') return false;
  return parsed.host == 'github.com' || parsed.host.endsWith('.github.com');
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
  // El cache cliente se segmenta por canal — sin esto, conmutar entre
  // stable y beta servía la respuesta cacheada del otro hasta 30 min.
  // Hoy sólo se usa `stable` pero el sufijo está listo para cuando se
  // añada UI de canal en preferencias.
  static String ultimoResultadoPorCanal(String canal) =>
      'fnh.pref.actualizacion.respuesta.$canal';
  static String ultimoTimestampPorCanal(String canal) =>
      'fnh.pref.actualizacion.ts.$canal';
  // La versión descartada por el usuario es identificación absoluta
  // (semver) — no varía por canal.
  static const versionDescartada = 'fnh.pref.actualizacion.descartada';
}

const _ttlMs = 30 * 60 * 1000; // 30 min en ms
