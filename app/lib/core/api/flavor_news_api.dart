import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/collective.dart';
import '../models/collective_submission.dart';
import '../models/item.dart';
import '../models/paginated_list.dart';
import '../models/radio.dart' as modelo_radio;
import '../models/source.dart';
import '../models/source_submission.dart';
import '../models/topic.dart';
import 'api_exception.dart';

/// Cliente HTTP del namespace `flavor-news/v1`.
///
/// Apto para múltiples instancias backend: `baseUrl` se inyecta y viene
/// de las preferencias del usuario (Ajustes → URL de la instancia).
class FlavorNewsApi {
  FlavorNewsApi({required this.baseUrl, required this.httpClient});

  /// URL base del namespace — debe acabar en `/`.
  final Uri baseUrl;

  final http.Client httpClient;

  static const Duration _tiempoMaximoPeticion = Duration(seconds: 20);

  // ---------- Items ----------

  Future<PaginatedList<Item>> fetchItems({
    int page = 1,
    int perPage = 20,
    String? topic,
    int? source,
    String? territory,
    String? language,
    DateTime? since,
    String? sourceType,
    String? excludeSourceType,
    String? search,
  }) async {
    final respuesta = await _get(
      'items',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (source != null && source > 0) 'source': '$source',
        if (territory != null && territory.isNotEmpty) 'territory': territory,
        if (language != null && language.isNotEmpty) 'language': language,
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (sourceType != null && sourceType.isNotEmpty) 'source_type': sourceType,
        if (excludeSourceType != null && excludeSourceType.isNotEmpty)
          'exclude_source_type': excludeSourceType,
        if (search != null && search.isNotEmpty) 's': search,
      },
    );
    final lista = _parsearLista<Item>(respuesta.body, Item.fromJson);
    return PaginatedList<Item>(
      items: lista,
      total: _leerEncabezadoEntero(respuesta, 'x-wp-total', fallback: lista.length),
      totalPages: _leerEncabezadoEntero(respuesta, 'x-wp-totalpages', fallback: 1),
      page: page,
      perPage: perPage,
    );
  }

  Future<Item> fetchItem(int id) async {
    final respuesta = await _get('items/$id');
    return Item.fromJson(_decodificarObjeto(respuesta.body));
  }

  // ---------- Sources ----------

  Future<PaginatedList<Source>> fetchSources({
    int page = 1,
    int perPage = 50,
    String? topic,
    String? territory,
    String? language,
    String? search,
  }) async {
    final respuesta = await _get(
      'sources',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (territory != null && territory.isNotEmpty) 'territory': territory,
        if (language != null && language.isNotEmpty) 'language': language,
        if (search != null && search.isNotEmpty) 's': search,
      },
    );
    final lista = _parsearLista<Source>(respuesta.body, Source.fromJson);
    return PaginatedList<Source>(
      items: lista,
      total: _leerEncabezadoEntero(respuesta, 'x-wp-total', fallback: lista.length),
      totalPages: _leerEncabezadoEntero(respuesta, 'x-wp-totalpages', fallback: 1),
      page: page,
      perPage: perPage,
    );
  }

  Future<Source> fetchSource(int id) async {
    final respuesta = await _get('sources/$id');
    return Source.fromJson(_decodificarObjeto(respuesta.body));
  }

  Future<SourceSubmissionResult> submitSource(SourceSubmission submission) async {
    final respuesta = await _post('sources/submit', body: submission.toJson());
    return SourceSubmissionResult.fromJson(_decodificarObjeto(respuesta.body));
  }

  // ---------- Collectives ----------

  Future<PaginatedList<Collective>> fetchCollectives({
    int page = 1,
    int perPage = 20,
    String? topic,
    String? territory,
    String? search,
  }) async {
    final respuesta = await _get(
      'collectives',
      query: {
        'page': '$page',
        'per_page': '$perPage',
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (territory != null && territory.isNotEmpty) 'territory': territory,
        if (search != null && search.isNotEmpty) 's': search,
      },
    );
    final lista = _parsearLista<Collective>(respuesta.body, Collective.fromJson);
    return PaginatedList<Collective>(
      items: lista,
      total: _leerEncabezadoEntero(respuesta, 'x-wp-total', fallback: lista.length),
      totalPages: _leerEncabezadoEntero(respuesta, 'x-wp-totalpages', fallback: 1),
      page: page,
      perPage: perPage,
    );
  }

  Future<Collective> fetchCollective(int id) async {
    final respuesta = await _get('collectives/$id');
    return Collective.fromJson(_decodificarObjeto(respuesta.body));
  }

  Future<CollectiveSubmissionResult> submitCollective(CollectiveSubmission submission) async {
    final respuesta = await _post('collectives/submit', body: submission.toJson());
    return CollectiveSubmissionResult.fromJson(_decodificarObjeto(respuesta.body));
  }

  // ---------- Topics ----------

  Future<List<Topic>> fetchTopics() async {
    final respuesta = await _get('topics');
    return _parsearLista<Topic>(respuesta.body, Topic.fromJson);
  }

  // ---------- Radios ----------

  Future<List<modelo_radio.Radio>> fetchRadios({
    String? territory,
    String? language,
    String? topic,
    String? search,
  }) async {
    final respuesta = await _get('radios', query: {
      'per_page': '100',
      if (territory != null && territory.isNotEmpty) 'territory': territory,
      if (language != null && language.isNotEmpty) 'language': language,
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      if (search != null && search.isNotEmpty) 's': search,
    });
    return _parsearLista<modelo_radio.Radio>(respuesta.body, modelo_radio.Radio.fromJson);
  }

  // ---------- Internos ----------

  Future<http.Response> _get(String ruta, {Map<String, String>? query}) async {
    final uri = baseUrl.resolve(ruta).replace(
          queryParameters: query?.isEmpty == true ? null : query,
        );
    try {
      final respuesta = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_tiempoMaximoPeticion);
      _lanzarSiHayError(respuesta);
      return respuesta;
    } on TimeoutException {
      throw const FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'network_error',
        message: 'Tiempo de espera agotado.',
      );
    } on SocketException catch (error) {
      throw FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'network_error',
        message: error.message,
      );
    }
  }

  Future<http.Response> _post(String ruta, {required Map<String, dynamic> body}) async {
    final uri = baseUrl.resolve(ruta);
    try {
      final respuesta = await httpClient
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_tiempoMaximoPeticion);
      _lanzarSiHayError(respuesta);
      return respuesta;
    } on TimeoutException {
      throw const FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'network_error',
        message: 'Tiempo de espera agotado.',
      );
    } on SocketException catch (error) {
      throw FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'network_error',
        message: error.message,
      );
    }
  }

  static void _lanzarSiHayError(http.Response respuesta) {
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return;
    }
    String codigoError = 'http_error';
    String mensajeError = 'HTTP ${respuesta.statusCode}';
    try {
      final decodificado = jsonDecode(respuesta.body);
      if (decodificado is Map<String, dynamic>) {
        codigoError = (decodificado['error'] as String?) ?? codigoError;
        mensajeError = (decodificado['message'] as String?) ?? mensajeError;
      }
    } on FormatException {
      // body no es JSON parseable: nos quedamos con los valores por defecto.
    }
    throw FlavorNewsApiException(
      statusCode: respuesta.statusCode,
      errorCode: codigoError,
      message: mensajeError,
    );
  }

  static List<T> _parsearLista<T>(String cuerpo, T Function(Map<String, dynamic>) deserializador) {
    final decodificado = jsonDecode(cuerpo);
    if (decodificado is! List) {
      throw const FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'bad_response',
        message: 'Se esperaba una lista JSON.',
      );
    }
    return decodificado
        .whereType<Map<String, dynamic>>()
        .map(deserializador)
        .toList(growable: false);
  }

  static Map<String, dynamic> _decodificarObjeto(String cuerpo) {
    final decodificado = jsonDecode(cuerpo);
    if (decodificado is! Map<String, dynamic>) {
      throw const FlavorNewsApiException(
        statusCode: 0,
        errorCode: 'bad_response',
        message: 'Se esperaba un objeto JSON.',
      );
    }
    return decodificado;
  }

  static int _leerEncabezadoEntero(http.Response respuesta, String nombreCabecera, {required int fallback}) {
    final valor = respuesta.headers[nombreCabecera.toLowerCase()];
    if (valor == null) return fallback;
    return int.tryParse(valor) ?? fallback;
  }
}
