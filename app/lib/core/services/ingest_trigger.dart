import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Despierta la ingesta del backend al arrancar la app. Útil en sitios con
/// poco tráfico web donde wp-cron de WordPress sólo dispara cuando alguien
/// visita la web — sin esto, las últimas noticias que ve el usuario pueden
/// ser de hace horas.
///
/// Fire-and-forget: nunca bloquea el arranque ni lanza excepciones al
/// caller. El backend tiene su propio rate-limit (10 min por defecto)
/// así que llamar en cada arranque es inofensivo.
Future<void> dispararIngestaBackend(SharedPreferences sp) async {
  final urlBackend = sp.getString('fnh.pref.backendUrl');
  if (urlBackend == null || urlBackend.isEmpty) return;
  try {
    final uri = Uri.parse(urlBackend);
    final uriIngest = uri.replace(
      path: '${uri.path}/ingest-trigger'.replaceAll('//', '/'),
    );
    await http
        .post(uriIngest, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    // Silencioso: si el backend está caído o el endpoint no existe
    // (plugin viejo) simplemente no disparamos. No queremos molestar al
    // usuario con errores de fondo.
  }
}
