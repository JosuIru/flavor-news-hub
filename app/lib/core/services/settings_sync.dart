import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de SharedPreferences donde guardamos la URL de donación vigente
/// del backend. Default hardcoded en el sheet de donaciones cubre el
/// primer arranque antes de que tengamos respuesta del servidor.
const String kPrefDonationUrl = 'fnh.pref.donationUrl';

/// Clave donde el `PreferenciasNotifier` persiste el nombre legible de
/// la instancia (`PreferenciasUsuario.nombreInstancia`). Reexpuesta aquí
/// para que `sincronizarAjustesPublicos` pueda prerrellenarla sin
/// importar el provider (servicio standalone llamado desde `main`).
const String kPrefBackendName = 'fnh.pref.backendName';

/// Sincroniza desde el backend los ajustes públicos del proyecto:
///  - `donation_url` → siempre se sobreescribe con la última versión.
///  - `site_name` → sólo se escribe si el usuario no había puesto nombre
///    a la instancia (no pisamos un override manual).
///
/// Fire-and-forget: nunca bloquea el arranque. Se llama desde `main()`
/// en paralelo al ingest-trigger y a los workers.
///
/// Si el backend no responde (caído, plugin viejo sin este endpoint)
/// dejamos las prefs como estén — la app sigue funcionando con la URL
/// última conocida o con el default hardcoded.
Future<void> sincronizarAjustesPublicos(SharedPreferences sp) async {
  final urlBackend = sp.getString('fnh.pref.backendUrl');
  if (urlBackend == null || urlBackend.isEmpty) return;
  final ajustes = await _descargarAjustesPublicos(Uri.tryParse(urlBackend));
  if (ajustes == null) return;
  final urlDonacion = (ajustes['donation_url'] ?? '').toString().trim();
  if (urlDonacion.isNotEmpty) {
    await sp.setString(kPrefDonationUrl, urlDonacion);
  }
  final nombreSitio = (ajustes['site_name'] ?? '').toString().trim();
  final nombreActual = (sp.getString(kPrefBackendName) ?? '').trim();
  if (nombreSitio.isNotEmpty && nombreActual.isEmpty) {
    await sp.setString(kPrefBackendName, nombreSitio);
  }
}

/// Devuelve el `site_name` declarado por la instancia indicada, o `null`
/// si la URL es inválida, el backend no responde o no expone el campo
/// (plugin viejo). Pensado para el botón "Sugerir desde la instancia"
/// del diálogo de URL: hace una sola petición y no toca SharedPreferences.
Future<String?> obtenerNombreSitioRemoto(Uri urlBackend) async {
  final ajustes = await _descargarAjustesPublicos(urlBackend);
  if (ajustes == null) return null;
  final nombre = (ajustes['site_name'] ?? '').toString().trim();
  return nombre.isEmpty ? null : nombre;
}

/// Descarga `/settings` de la instancia indicada con un timeout corto.
/// Devuelve el JSON decodificado o `null` ante cualquier error — los
/// callers deciden qué campo leer y con qué fallback.
Future<Map<String, dynamic>?> _descargarAjustesPublicos(Uri? urlBackend) async {
  if (urlBackend == null || !urlBackend.hasScheme || urlBackend.host.isEmpty) {
    return null;
  }
  try {
    final uriSettings = urlBackend.replace(
      path: '${urlBackend.path}/settings'.replaceAll('//', '/'),
    );
    final respuesta = await http
        .get(uriSettings, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) return null;
    final decodificado = jsonDecode(respuesta.body);
    if (decodificado is! Map<String, dynamic>) return null;
    return decodificado;
  } catch (_) {
    // Silencioso — mismo criterio que ingest_trigger.
    return null;
  }
}
