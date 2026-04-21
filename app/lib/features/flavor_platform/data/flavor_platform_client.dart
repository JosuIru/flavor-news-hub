import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'flavor_models.dart';

/// Cliente HTTP para la API pública (`flavor-network/v1`) de una instancia
/// cualquiera de Flavor Platform.
///
/// Cada petición se hace contra una `baseUrl` distinta — esa es la URL de
/// la "instancia Flavor" del colectivo (por ejemplo, `https://nodo.org`).
/// No mantenemos estado: es un cliente stateless que sólo sabe cómo hablar
/// con `/wp-json/flavor-network/v1/*`.
class FlavorPlatformClient {
  FlavorPlatformClient({required this.httpClient});
  final http.Client httpClient;

  static const Duration _timeout = Duration(seconds: 12);

  /// Deriva la URL del namespace a partir de la URL arbitraria del colectivo.
  /// Acepta tanto `https://nodo.org` como `https://nodo.org/algo/ruta/`.
  Uri? _apiBase(String flavorUrl) {
    final parsed = Uri.tryParse(flavorUrl);
    if (parsed == null || !parsed.hasScheme) return null;
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: '/wp-json/flavor-network/v1/',
    );
  }

  Future<List<FlavorEvento>> fetchEventos(String flavorUrl, {int perPage = 5}) async {
    final base = _apiBase(flavorUrl);
    if (base == null) return const [];
    return _fetchLista(
      base.resolve('events').replace(queryParameters: {'per_page': '$perPage'}),
      claveLista: 'eventos',
      deserializar: FlavorEvento.fromJson,
    );
  }

  Future<List<FlavorContenido>> fetchContenidos(String flavorUrl, {int perPage = 5}) async {
    final base = _apiBase(flavorUrl);
    if (base == null) return const [];
    return _fetchLista(
      base.resolve('content').replace(queryParameters: {'per_page': '$perPage'}),
      claveLista: 'contenidos',
      deserializar: FlavorContenido.fromJson,
    );
  }

  Future<List<FlavorPublicacionTablon>> fetchTablon(String flavorUrl, {int perPage = 5}) async {
    final base = _apiBase(flavorUrl);
    if (base == null) return const [];
    return _fetchLista(
      base.resolve('board').replace(queryParameters: {'per_page': '$perPage'}),
      claveLista: 'publicaciones',
      deserializar: FlavorPublicacionTablon.fromJson,
    );
  }

  Future<List<FlavorNode>> fetchDirectorio(String flavorUrl, {int perPage = 50}) async {
    final base = _apiBase(flavorUrl);
    if (base == null) return const [];
    return _fetchLista(
      base.resolve('directory').replace(queryParameters: {'per_page': '$perPage'}),
      claveLista: 'nodos',
      deserializar: FlavorNode.fromJson,
    );
  }

  /// Carga en paralelo los 3 flujos públicos de un nodo. Si uno falla,
  /// el resto se entrega igual — federación = best-effort, no all-or-nothing.
  Future<ActividadNodoFlavor> fetchActividad(String flavorUrl, {int perPage = 5}) async {
    final resultados = await Future.wait<dynamic>([
      fetchEventos(flavorUrl, perPage: perPage).catchError((_) => const <FlavorEvento>[]),
      fetchContenidos(flavorUrl, perPage: perPage).catchError((_) => const <FlavorContenido>[]),
      fetchTablon(flavorUrl, perPage: perPage).catchError((_) => const <FlavorPublicacionTablon>[]),
    ]);
    return ActividadNodoFlavor(
      eventos: resultados[0] as List<FlavorEvento>,
      contenidos: resultados[1] as List<FlavorContenido>,
      publicaciones: resultados[2] as List<FlavorPublicacionTablon>,
    );
  }

  Future<List<T>> _fetchLista<T>(
    Uri uri, {
    required String claveLista,
    required T Function(Map<String, dynamic>) deserializar,
  }) async {
    try {
      final resp = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decodificado = jsonDecode(resp.body);
      List<dynamic>? bruto;
      if (decodificado is Map<String, dynamic>) {
        final campo = decodificado[claveLista];
        if (campo is List) bruto = campo;
      } else if (decodificado is List) {
        bruto = decodificado;
      }
      if (bruto == null) return const [];
      return bruto
          .whereType<Map<String, dynamic>>()
          .map(deserializar)
          .toList(growable: false);
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
