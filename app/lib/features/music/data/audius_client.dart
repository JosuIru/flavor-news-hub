import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/api_provider.dart';
import 'funkwhale_client.dart' show PistaFunkwhale;

/// Cliente de la API pública de Audius (`api.audius.co/v1`).
///
/// Audius es una plataforma musical descentralizada. La API es de lectura
/// pública, sin auth ni client_id; sólo pide `app_name` para identificar
/// consumidores. El endpoint `/tracks/{id}/stream` devuelve un 302 al MP3
/// real en el creator node correspondiente — `just_audio` sigue el
/// redirect automáticamente.
class AudiusClient {
  AudiusClient({required this.httpClient});

  final http.Client httpClient;

  static final Uri _apiBase = Uri.parse('https://api.audius.co/v1/');
  static const String _appName = 'FlavorNewsHub';
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<PistaFunkwhale>> buscarPistas(String consulta, {int limit = 15}) async {
    if (consulta.trim().isEmpty) return const [];
    return _ejecutar(_apiBase.resolve('tracks/search').replace(queryParameters: {
      'query': consulta,
      'limit': '$limit',
      'app_name': _appName,
    }));
  }

  /// Tracks trending en Audius (rotación algorítmica de últimos populares).
  /// Buena semilla para descubrir sin idea previa.
  Future<List<PistaFunkwhale>> traerNovedades({int limit = 10}) async {
    return _ejecutar(_apiBase.resolve('tracks/trending').replace(queryParameters: {
      'limit': '$limit',
      'app_name': _appName,
    }));
  }

  Future<List<PistaFunkwhale>> _ejecutar(Uri uri) async {
    try {
      final resp = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decodificado = jsonDecode(resp.body);
      if (decodificado is! Map<String, dynamic>) return const [];
      final datos = decodificado['data'];
      if (datos is! List) return const [];
      return datos
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
    final idExterno = (raw['id'] ?? '').toString();
    final trackIdNumerico = raw['track_id'];
    if (idExterno.isEmpty) return null;
    final title = (raw['title'] ?? '').toString();
    if (title.isEmpty) return null;

    // Stream URL estable — la API resuelve al node correcto vía 302.
    final listenUrl = 'https://api.audius.co/v1/tracks/$idExterno/stream?app_name=$_appName';

    final artist = _extraerArtista(raw);
    final cover = _extraerCover(raw);
    final duration = raw['duration'] is int
        ? raw['duration'] as int
        : int.tryParse('${raw['duration'] ?? 0}') ?? 0;

    return PistaFunkwhale(
      id: trackIdNumerico is int
          ? trackIdNumerico
          : int.tryParse('$trackIdNumerico') ?? idExterno.hashCode,
      title: title,
      artist: artist,
      album: (raw['album_backlink']?['album_name'] ?? '').toString(),
      listenUrl: listenUrl,
      coverUrl: cover,
      duration: duration,
      instanciaOrigen: 'audius.co',
      genero: (raw['genre'] ?? '').toString(),
    );
  }

  String _extraerArtista(Map<String, dynamic> raw) {
    final user = raw['user'];
    if (user is Map<String, dynamic>) {
      final name = (user['name'] ?? '').toString();
      if (name.isNotEmpty) return name;
      final handle = (user['handle'] ?? '').toString();
      if (handle.isNotEmpty) return '@$handle';
    }
    return '';
  }

  /// Audius devuelve el artwork como objeto `{150x150, 480x480, 1000x1000}`.
  /// 480 es el mejor compromiso para tarjetas en móvil.
  String _extraerCover(Map<String, dynamic> raw) {
    final artwork = raw['artwork'];
    if (artwork is Map<String, dynamic>) {
      return (artwork['480x480'] ?? artwork['150x150'] ?? artwork['1000x1000'] ?? '').toString();
    }
    return '';
  }
}

/// Audius siempre está disponible — no hay nada que configurar. El provider
/// es un `Provider` simple, no un `StateNotifierProvider`: la presencia del
/// cliente no depende del estado persistido.
final audiusClientProvider = Provider<AudiusClient>((ref) {
  return AudiusClient(httpClient: ref.watch(httpClientProvider));
});
