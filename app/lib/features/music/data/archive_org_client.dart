import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/api_provider.dart';
import 'funkwhale_client.dart' show PistaFunkwhale;

/// Cliente de búsqueda musical en Internet Archive (archive.org).
///
/// Archive.org aloja millones de grabaciones de dominio público y bajo
/// licencias abiertas — conciertos en vivo, música libre, grabaciones
/// históricas. La API es totalmente pública, no exige auth.
///
/// Flujo en dos pasos:
///  1. `advancedsearch.php` — búsqueda textual en la colección
///     `opensource_audio` (música libre, excluye podcasts y news).
///     Devuelve identificadores pero no URLs de streaming.
///  2. Por cada identificador, `/metadata/{id}` lista los archivos del
///     item; elegimos el primer MP3 jugable.
///
/// Paralelizamos el paso 2 y limitamos a pocos resultados para que el
/// tiempo de búsqueda se mantenga razonable — Archive.org es el catálogo
/// más rico pero también el más lento en resolverse.
class ArchiveOrgClient {
  ArchiveOrgClient({required this.httpClient});

  final http.Client httpClient;

  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _timeoutMetadata = Duration(seconds: 8);
  static const Set<String> _formatosMp3Preferidos = {
    'VBR MP3',
    '128Kbps MP3',
    '64Kbps MP3',
    'MP3',
  };

  Future<List<PistaFunkwhale>> buscarPistas(String consulta, {int limit = 5}) async {
    if (consulta.trim().isEmpty) return const [];
    return _consultarYResolver(
      'mediatype:audio AND collection:opensource_audio AND ($consulta)',
      limit: limit,
    );
  }

  /// Últimas subidas a opensource_audio, ordenadas por fecha de publicación.
  Future<List<PistaFunkwhale>> traerNovedades({int limit = 5}) async {
    return _consultarYResolver(
      'mediatype:audio AND collection:opensource_audio',
      limit: limit,
      ordenarPorFecha: true,
    );
  }

  Future<List<PistaFunkwhale>> _consultarYResolver(
    String q, {
    required int limit,
    bool ordenarPorFecha = false,
  }) async {
    // Dart `queryParameters` no duplica claves; construimos la URL a mano
    // para los múltiples `fl[]` y `sort[]`.
    final base = 'https://archive.org/advancedsearch.php';
    final params = <String>[
      'q=${Uri.encodeQueryComponent(q)}',
      'output=json',
      'rows=$limit',
      'fl[]=identifier',
      'fl[]=title',
      'fl[]=creator',
      'fl[]=runtime',
      if (ordenarPorFecha) 'sort[]=${Uri.encodeQueryComponent('publicdate desc')}',
    ];
    final uriFinal = Uri.parse('$base?${params.join('&')}');
    try {
      final resp = await httpClient
          .get(uriFinal, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decodificado = jsonDecode(resp.body);
      if (decodificado is! Map<String, dynamic>) return const [];
      final docs = decodificado['response']?['docs'];
      if (docs is! List) return const [];
      final identificadores = docs
          .whereType<Map<String, dynamic>>()
          .map((d) => {
                'id': (d['identifier'] ?? '').toString(),
                'title': (d['title'] ?? '').toString(),
                'creator': _primerValor(d['creator']),
                'runtime': (d['runtime'] ?? '').toString(),
              })
          .where((d) => (d['id'] as String).isNotEmpty)
          .toList();
      if (identificadores.isEmpty) return const [];
      // Resolvemos los MP3 en paralelo; los que fallen se descartan.
      final resultados = await Future.wait(
        identificadores.map((info) => _resolverItem(info).catchError((_) => null)),
      );
      return resultados.whereType<PistaFunkwhale>().toList(growable: false);
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<PistaFunkwhale?> _resolverItem(Map<String, Object> info) async {
    final identificador = info['id'] as String;
    final url = Uri.parse('https://archive.org/metadata/$identificador');
    final resp = await httpClient.get(url).timeout(_timeoutMetadata);
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final decodificado = jsonDecode(resp.body);
    if (decodificado is! Map<String, dynamic>) return null;
    final files = decodificado['files'];
    if (files is! List) return null;
    // Primer archivo MP3 en formato preferido.
    Map<String, dynamic>? mp3;
    for (final formato in _formatosMp3Preferidos) {
      for (final f in files) {
        if (f is Map<String, dynamic> && f['format'] == formato) {
          mp3 = f;
          break;
        }
      }
      if (mp3 != null) break;
    }
    if (mp3 == null) return null;

    final nombreArchivo = (mp3['name'] ?? '').toString();
    if (nombreArchivo.isEmpty) return null;

    final listenUrl =
        'https://archive.org/download/$identificador/${Uri.encodeComponent(nombreArchivo)}';
    final duration = int.tryParse('${mp3['length'] ?? ''}'.split('.').first) ?? 0;
    final metadata = decodificado['metadata'];
    final creator = metadata is Map<String, dynamic>
        ? _primerValor(metadata['creator'])
        : (info['creator'] as String? ?? '');
    final titleItem = metadata is Map<String, dynamic>
        ? (metadata['title'] ?? info['title']).toString()
        : (info['title'] as String? ?? '');
    final cover = 'https://archive.org/services/img/$identificador';

    return PistaFunkwhale(
      id: identificador.hashCode,
      title: titleItem.isEmpty ? nombreArchivo : titleItem,
      artist: creator,
      album: '',
      listenUrl: listenUrl,
      coverUrl: cover,
      duration: duration,
      instanciaOrigen: 'archive.org',
      genero: '',
    );
  }

  /// Archive.org a veces devuelve `creator` como string y otras como lista.
  String _primerValor(dynamic v) {
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return v.first.toString();
    return '';
  }
}

final archiveOrgClientProvider = Provider<ArchiveOrgClient>((ref) {
  return ArchiveOrgClient(httpClient: ref.watch(httpClientProvider));
});
