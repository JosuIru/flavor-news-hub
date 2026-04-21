import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import 'archive_org_client.dart';
import 'audius_client.dart';
import 'jamendo_client.dart';

/// Pista resultado de búsqueda en Funkwhale. Modelo minimal: sólo lo que
/// la UI necesita para listar y reproducir.
class PistaFunkwhale {
  const PistaFunkwhale({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.listenUrl,
    required this.coverUrl,
    required this.duration,
    required this.instanciaOrigen,
    this.genero = '',
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final String listenUrl;
  final String coverUrl;
  final int duration;

  /// Host de la instancia Funkwhale de donde vino la pista. Útil para
  /// mostrar al usuario "fuente: open.audio" cuando hay varias configuradas.
  final String instanciaOrigen;

  /// Género o tag principal (p. ej. "Punk", "Jazz"). Lo usamos como
  /// fallback para autoplay cuando la cola de búsqueda se agota y no hay
  /// más pistas del mismo artista.
  final String genero;
}

/// Cliente HTTP para la API pública de una instancia Funkwhale.
///
/// Funkwhale 2.x expone `/api/v2/tracks/`; las instancias 1.x (minoritarias
/// en 2026) aún usan `/api/v1/tracks/`. Probamos v2 primero y caemos a v1
/// si v2 responde 404. Sin auth: trabajamos sólo con catálogo público.
class FunkwhaleClient {
  FunkwhaleClient({required this.instanciaBase, required this.httpClient});

  final Uri instanciaBase;
  final http.Client httpClient;

  static const Duration _timeout = Duration(seconds: 12);

  Future<List<PistaFunkwhale>> buscarPistas(String consulta, {int limit = 20}) async {
    if (consulta.trim().isEmpty) return const [];
    final resultadoV2 = await _buscarEnApi('api/v2/tracks/', consulta, limit);
    if (resultadoV2 != null) return resultadoV2;
    return (await _buscarEnApi('api/v1/tracks/', consulta, limit)) ?? const [];
  }

  /// Últimas subidas a la instancia, ordenadas por fecha de creación
  /// descendente. Sin query → no es búsqueda, es el feed de novedades.
  Future<List<PistaFunkwhale>> traerNovedades({int limit = 10}) async {
    final resultadoV2 = await _novedadesEnApi('api/v2/tracks/', limit);
    if (resultadoV2 != null) return resultadoV2;
    return (await _novedadesEnApi('api/v1/tracks/', limit)) ?? const [];
  }

  Future<List<PistaFunkwhale>?> _novedadesEnApi(String ruta, int limit) async {
    final uri = instanciaBase.resolve(ruta).replace(queryParameters: {
      'ordering': '-creation_date',
      'page_size': '$limit',
      'playable': 'true',
    });
    return _pedirYParsear(uri);
  }

  /// Devuelve null cuando la ruta no existe (404) — el caller debe probar
  /// otra versión. Listas vacías significan "sin resultados", no "ruta
  /// inexistente".
  Future<List<PistaFunkwhale>?> _buscarEnApi(String ruta, String consulta, int limit) async {
    final uri = instanciaBase.resolve(ruta).replace(queryParameters: {
      'q': consulta,
      'page_size': '$limit',
      'playable': 'true',
    });
    return _pedirYParsear(uri);
  }

  Future<List<PistaFunkwhale>?> _pedirYParsear(Uri uri) async {
    try {
      final resp = await httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (resp.statusCode == 404) return null;
      if (resp.statusCode < 200 || resp.statusCode >= 300) return const [];
      final decodificado = jsonDecode(resp.body);
      if (decodificado is! Map<String, dynamic>) return const [];
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
    final id = _asInt(raw['id']);
    final title = _asString(raw['title']);
    if (id == 0 || title.isEmpty) return null;
    final listenUrl = _extraerListenUrl(raw);
    if (listenUrl.isEmpty) return null;
    return PistaFunkwhale(
      id: id,
      title: title,
      artist: _extraerArtista(raw),
      album: _extraerAlbum(raw),
      listenUrl: listenUrl,
      coverUrl: _extraerCover(raw),
      duration: _extraerDuracion(raw),
      instanciaOrigen: instanciaBase.host,
      genero: _extraerGenero(raw),
    );
  }

  /// Funkwhale guarda tags libres, no un género canonizado. Tomamos el
  /// primer tag como aproximación de género.
  String _extraerGenero(Map<String, dynamic> raw) {
    final tags = raw['tags'];
    if (tags is List && tags.isNotEmpty) {
      final primero = tags.first;
      if (primero is String && primero.isNotEmpty) return primero;
    }
    return '';
  }

  String _extraerArtista(Map<String, dynamic> raw) {
    final credit = raw['artist_credit'];
    if (credit is List && credit.isNotEmpty) {
      final primero = credit.first;
      if (primero is Map<String, dynamic>) {
        final creditStr = _asString(primero['credit']);
        if (creditStr.isNotEmpty) return creditStr;
        final artistObj = primero['artist'];
        if (artistObj is Map<String, dynamic>) {
          return _asString(artistObj['name']);
        }
      }
    }
    final artist = raw['artist'];
    if (artist is Map<String, dynamic>) return _asString(artist['name']);
    return '';
  }

  String _extraerAlbum(Map<String, dynamic> raw) {
    final album = raw['album'];
    if (album is Map<String, dynamic>) return _asString(album['title']);
    return '';
  }

  String _extraerListenUrl(Map<String, dynamic> raw) {
    final directa = _asString(raw['listen_url']);
    if (directa.isNotEmpty) return _absolutizar(directa);
    final uploads = raw['uploads'];
    if (uploads is List && uploads.isNotEmpty) {
      final primero = uploads.first;
      if (primero is Map<String, dynamic>) {
        final url = _asString(primero['listen_url']);
        if (url.isNotEmpty) return _absolutizar(url);
      }
    }
    return '';
  }

  String _extraerCover(Map<String, dynamic> raw) {
    final album = raw['album'];
    if (album is Map<String, dynamic>) {
      final cover = album['cover'];
      if (cover is Map<String, dynamic>) {
        final urls = cover['urls'];
        if (urls is Map<String, dynamic>) {
          final urlMedium = _asString(urls['medium_square_crop']);
          if (urlMedium.isNotEmpty) return _absolutizar(urlMedium);
          final urlOriginal = _asString(urls['original']);
          if (urlOriginal.isNotEmpty) return _absolutizar(urlOriginal);
        }
      }
    }
    return '';
  }

  int _extraerDuracion(Map<String, dynamic> raw) {
    final uploads = raw['uploads'];
    if (uploads is List && uploads.isNotEmpty) {
      final primero = uploads.first;
      if (primero is Map<String, dynamic>) {
        return _asInt(primero['duration']);
      }
    }
    return 0;
  }

  String _absolutizar(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return instanciaBase.resolve(url.startsWith('/') ? url.substring(1) : url).toString();
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static String _asString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }
}

/// Lista de instancias Funkwhale configuradas por el usuario. Una búsqueda
/// pregunta a TODAS en paralelo y mezcla resultados. Así el usuario puede
/// añadir su instancia favorita + open.audio + tanukitunes… y ver todo en
/// un solo listado.
const String _clavePrefInstancias = 'fnh.pref.funkwhaleInstances';

final funkwhaleInstanciasProvider =
    StateNotifierProvider<_InstanciasFunkwhaleNotifier, List<String>>((ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  return _InstanciasFunkwhaleNotifier(sp);
});

class _InstanciasFunkwhaleNotifier extends StateNotifier<List<String>> {
  _InstanciasFunkwhaleNotifier(this._sp) : super(_leerInicial(_sp));

  final SharedPreferences _sp;

  /// Instancia por defecto cuando el usuario no ha configurado ninguna.
  /// `open.audio` es la instancia pública más grande (4700+ usuarios),
  /// corre Funkwhale oficial y no exige registro para consultar el
  /// catálogo público. Buen punto de arranque razonable.
  static const String instanciaDefault = 'https://open.audio/';

  static List<String> _leerInicial(SharedPreferences sp) {
    final list = sp.getStringList(_clavePrefInstancias);
    if (list != null) return List.unmodifiable(list);
    // Migración desde la clave antigua de instancia única.
    final antigua = sp.getString('fnh.pref.funkwhaleInstance');
    if (antigua != null && antigua.isNotEmpty) {
      return List.unmodifiable([_normalizar(antigua)]);
    }
    // Primera ejecución: sembramos una instancia pública conocida para que
    // la pantalla de música funcione desde el primer momento sin fricción.
    return const [instanciaDefault];
  }

  static String _normalizar(String url) {
    final limpia = url.trim();
    if (limpia.isEmpty) return '';
    return limpia.endsWith('/') ? limpia : '$limpia/';
  }

  Future<void> anadir(String url) async {
    final normalizada = _normalizar(url);
    if (normalizada.isEmpty) return;
    if (state.contains(normalizada)) return;
    state = List.unmodifiable([...state, normalizada]);
    await _persistir();
  }

  Future<void> eliminar(String url) async {
    state = List.unmodifiable(state.where((u) => u != url));
    await _persistir();
  }

  Future<void> _persistir() async {
    await _sp.setStringList(_clavePrefInstancias, state);
  }
}

/// Clientes Funkwhale derivados de la lista de instancias. Uno por URL
/// válida.
final funkwhaleClientsProvider = Provider<List<FunkwhaleClient>>((ref) {
  final instancias = ref.watch(funkwhaleInstanciasProvider);
  final http = ref.watch(httpClientProvider);
  return instancias
      .map((u) => Uri.tryParse(u))
      .whereType<Uri>()
      .where((u) => u.hasScheme)
      .map((u) => FunkwhaleClient(instanciaBase: u, httpClient: http))
      .toList(growable: false);
});

/// Consulta activa. El widget actualiza este provider con debounce.
final consultaMusicaProvider = StateProvider<String>((_) => '');

/// Resultados mezclados de TODAS las fuentes de música configuradas:
/// instancias Funkwhale + (opcionalmente) Jamendo. Ejecución en paralelo
/// con `Future.wait`; los fallos individuales se tratan como "sin
/// resultados" — la mezcla sigue igual para el resto.
/// Ejecuta una búsqueda en TODAS las fuentes (Audius + Funkwhale configuradas
/// + Jamendo si hay client_id) y devuelve los resultados intercalados.
///
/// Recibe los clientes explícitamente para poder usarse tanto desde un
/// `Provider` (que usa `Ref`) como desde un widget (que usa `WidgetRef`) —
/// ambos tipos de ref exponen `read`, pero no son asignables entre sí.
Future<List<PistaFunkwhale>> buscarMusicaEnClientes({
  required String consulta,
  required AudiusClient clientAudius,
  required List<FunkwhaleClient> clientsFunkwhale,
  required ArchiveOrgClient clientArchive,
  JamendoClient? clientJamendo,
}) async {
  // Archive.org es más lento (doble round-trip: search + metadata por item)
  // y lo limitamos a pocos resultados para no retrasar toda la búsqueda.
  const limitArchive = 5;
  final totalFuentesRapidas =
      clientsFunkwhale.length + (clientJamendo != null ? 1 : 0) + 1; // +1 audius
  final perFuenteRapida = (30 / totalFuentesRapidas).ceil().clamp(5, 30);
  final futuros = <Future<List<PistaFunkwhale>>>[
    clientAudius.buscarPistas(consulta, limit: perFuenteRapida).catchError((_) => const <PistaFunkwhale>[]),
    clientArchive.buscarPistas(consulta, limit: limitArchive).catchError((_) => const <PistaFunkwhale>[]),
    for (final c in clientsFunkwhale)
      c.buscarPistas(consulta, limit: perFuenteRapida).catchError((_) => const <PistaFunkwhale>[]),
    if (clientJamendo != null)
      clientJamendo.buscarPistas(consulta, limit: perFuenteRapida).catchError((_) => const <PistaFunkwhale>[]),
  ];
  final listas = await Future.wait(futuros);
  return _intercalarRondaRobin(listas);
}

final resultadosMusicaProvider = FutureProvider.autoDispose<List<PistaFunkwhale>>((ref) async {
  final consulta = ref.watch(consultaMusicaProvider).trim();
  if (consulta.length < 2) return const [];
  return buscarMusicaEnClientes(
    consulta: consulta,
    clientAudius: ref.watch(audiusClientProvider),
    clientArchive: ref.watch(archiveOrgClientProvider),
    clientsFunkwhale: ref.watch(funkwhaleClientsProvider),
    clientJamendo: ref.watch(jamendoClientProvider),
  );
});

/// Géneros sugeridos para arranque rápido de descubrimiento. Mezcla de
/// etiquetas que cubren bien el material libre/indie disponible en las
/// cuatro plataformas que consultamos. No es exhaustivo — son atajos.
const List<String> generosMusicalesSugeridos = [
  'punk',
  'hardcore',
  'indie',
  'hip hop',
  'electronic',
  'ambient',
  'jazz',
  'folk',
  'reggae',
  'metal',
  'techno',
  'dub',
  'experimental',
  'rap',
  'rock',
  'classical',
];

/// Últimas subidas a todas las plataformas musicales. Se usa como contenido
/// por defecto cuando el usuario aún no ha escrito nada en el buscador —
/// evita la sensación de "pantalla en blanco" al entrar.
final novedadesMusicaProvider = FutureProvider.autoDispose<List<PistaFunkwhale>>((ref) async {
  final clientAudius = ref.watch(audiusClientProvider);
  final clientArchive = ref.watch(archiveOrgClientProvider);
  final clientsFunkwhale = ref.watch(funkwhaleClientsProvider);
  final clientJamendo = ref.watch(jamendoClientProvider);
  final futuros = <Future<List<PistaFunkwhale>>>[
    clientAudius.traerNovedades(limit: 10).catchError((_) => const <PistaFunkwhale>[]),
    clientArchive.traerNovedades(limit: 5).catchError((_) => const <PistaFunkwhale>[]),
    for (final c in clientsFunkwhale)
      c.traerNovedades(limit: 10).catchError((_) => const <PistaFunkwhale>[]),
    if (clientJamendo != null)
      clientJamendo.traerNovedades(limit: 10).catchError((_) => const <PistaFunkwhale>[]),
  ];
  final listas = await Future.wait(futuros);
  return _intercalarRondaRobin(listas);
});

List<T> _intercalarRondaRobin<T>(List<List<T>> listas) {
  final salida = <T>[];
  final indices = List<int>.filled(listas.length, 0);
  var algunoAvanzando = true;
  while (algunoAvanzando) {
    algunoAvanzando = false;
    for (var i = 0; i < listas.length; i++) {
      if (indices[i] < listas[i].length) {
        salida.add(listas[i][indices[i]]);
        indices[i]++;
        algunoAvanzando = true;
      }
    }
  }
  return salida;
}
