import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import 'funkwhale_client.dart' show PistaFunkwhale;

/// Cliente de la API pública de Jamendo (`api.jamendo.com/v3.0`).
///
/// Jamendo aloja música bajo licencias Creative Commons / royalty-free.
/// La API exige un `client_id` que cada desarrollador obtiene gratis en
/// <https://devportal.jamendo.com/>. No se comparte uno común porque las
/// cuotas están por client_id — si fuera público y lo usaran miles de
/// instalaciones, se bloquearía para todos. El usuario configura el suyo
/// una vez y a partir de ahí la búsqueda lo incluye automáticamente.
class JamendoClient {
  JamendoClient({required this.clientId, required this.httpClient});

  final String clientId;
  final http.Client httpClient;

  static final Uri _apiBase = Uri.parse('https://api.jamendo.com/v3.0/');
  static const Duration _timeout = Duration(seconds: 12);

  /// Reusamos `PistaFunkwhale` como shape común de "pista reproducible":
  /// simplifica la UI y la mezcla round-robin con Funkwhale en el mismo
  /// listado. `instanciaOrigen` se pone a "jamendo.com" para identificar.
  Future<List<PistaFunkwhale>> buscarPistas(String consulta, {int limit = 15}) async {
    if (clientId.isEmpty || consulta.trim().isEmpty) return const [];
    return _ejecutar({
      'client_id': clientId,
      'format': 'json',
      'limit': '$limit',
      'search': consulta,
      'include': 'musicinfo',
      'audioformat': 'mp31',
    });
  }

  /// Últimos tracks publicados en Jamendo, ordenados por fecha de lanzamiento.
  Future<List<PistaFunkwhale>> traerNovedades({int limit = 10}) async {
    if (clientId.isEmpty) return const [];
    return _ejecutar({
      'client_id': clientId,
      'format': 'json',
      'limit': '$limit',
      'order': 'releasedate_desc',
      'include': 'musicinfo',
      'audioformat': 'mp31',
    });
  }

  Future<List<PistaFunkwhale>> _ejecutar(Map<String, String> query) async {
    final uri = _apiBase.resolve('tracks/').replace(queryParameters: query);
    try {
      final resp = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decodificado = jsonDecode(resp.body);
      if (decodificado is! Map<String, dynamic>) return const [];
      // Jamendo envuelve todo en `headers` + `results`. Si `headers.code`
      // != 0, la petición falló (cliente inválido, cuota, etc.).
      final headers = decodificado['headers'];
      if (headers is Map<String, dynamic> && headers['code'] != 0) {
        return const [];
      }
      final resultados = decodificado['results'];
      if (resultados is! List) return const [];
      return resultados
          .whereType<Map<String, dynamic>>()
          .map(_mapearTrack)
          .where((p) => p != null)
          .cast<PistaFunkwhale>()
          .toList(growable: false);
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  PistaFunkwhale? _mapearTrack(Map<String, dynamic> raw) {
    final id = int.tryParse((raw['id'] ?? '').toString()) ?? 0;
    final title = (raw['name'] ?? '').toString();
    final audio = (raw['audio'] ?? '').toString();
    if (id == 0 || title.isEmpty || audio.isEmpty) return null;
    final durationAny = raw['duration'];
    final duration = durationAny is int
        ? durationAny
        : (durationAny is num
            ? durationAny.toInt()
            : int.tryParse('${durationAny ?? 0}') ?? 0);
    return PistaFunkwhale(
      id: id,
      title: title,
      artist: (raw['artist_name'] ?? '').toString(),
      album: (raw['album_name'] ?? '').toString(),
      listenUrl: audio,
      coverUrl: (raw['album_image'] ?? raw['image'] ?? '').toString(),
      duration: duration,
      instanciaOrigen: 'jamendo.com',
      genero: _extraerGeneroJamendo(raw),
    );
  }

  /// Jamendo devuelve géneros en `musicinfo.tags.genres` como lista.
  String _extraerGeneroJamendo(Map<String, dynamic> raw) {
    final musicinfo = raw['musicinfo'];
    if (musicinfo is Map<String, dynamic>) {
      final tags = musicinfo['tags'];
      if (tags is Map<String, dynamic>) {
        final generos = tags['genres'];
        if (generos is List && generos.isNotEmpty) {
          final primero = generos.first;
          if (primero is String && primero.isNotEmpty) return primero;
        }
      }
    }
    return '';
  }
}

/// `client_id` Jamendo persistido. Vacío = Jamendo no contribuye.
const String _clavePrefJamendoClientId = 'fnh.pref.jamendoClientId';

final jamendoClientIdProvider =
    StateNotifierProvider<_JamendoClientIdNotifier, String>((ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  return _JamendoClientIdNotifier(sp);
});

class _JamendoClientIdNotifier extends StateNotifier<String> {
  _JamendoClientIdNotifier(this._sp)
      : super(_sp.getString(_clavePrefJamendoClientId) ?? '');
  final SharedPreferences _sp;

  Future<void> establecer(String valor) async {
    final limpio = valor.trim();
    state = limpio;
    if (limpio.isEmpty) {
      await _sp.remove(_clavePrefJamendoClientId);
    } else {
      await _sp.setString(_clavePrefJamendoClientId, limpio);
    }
  }
}

final jamendoClientProvider = Provider<JamendoClient?>((ref) {
  final clientId = ref.watch(jamendoClientIdProvider);
  if (clientId.isEmpty) return null;
  return JamendoClient(
    clientId: clientId,
    httpClient: ref.watch(httpClientProvider),
  );
});
