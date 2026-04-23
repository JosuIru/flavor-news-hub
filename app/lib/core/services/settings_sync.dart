import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de SharedPreferences donde guardamos la URL de donación vigente
/// del backend. Default hardcoded en el sheet de donaciones cubre el
/// primer arranque antes de que tengamos respuesta del servidor.
const String kPrefDonationUrl = 'fnh.pref.donationUrl';

/// Sincroniza desde el backend los ajustes públicos del proyecto (hoy
/// sólo la URL de donaciones, mañana más). Fire-and-forget: nunca
/// bloquea el arranque. Se llama desde `main()` en paralelo al
/// ingest-trigger y a los workers.
///
/// Si el backend no responde (caído, plugin viejo sin este endpoint)
/// dejamos las prefs como estén — la app sigue funcionando con la URL
/// última conocida o con el default hardcoded.
Future<void> sincronizarAjustesPublicos(SharedPreferences sp) async {
  final urlBackend = sp.getString('fnh.pref.backendUrl');
  if (urlBackend == null || urlBackend.isEmpty) return;
  try {
    final uri = Uri.parse(urlBackend);
    final uriSettings = uri.replace(
      path: '${uri.path}/settings'.replaceAll('//', '/'),
    );
    final respuesta = await http
        .get(uriSettings, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) return;
    final decodificado = jsonDecode(respuesta.body);
    if (decodificado is! Map<String, dynamic>) return;
    final urlDonacion = (decodificado['donation_url'] ?? '').toString().trim();
    if (urlDonacion.isEmpty) return;
    await sp.setString(kPrefDonationUrl, urlDonacion);
  } catch (_) {
    // Silencioso — mismo criterio que ingest_trigger.
  }
}
