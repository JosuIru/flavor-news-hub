import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'preferencias_notif.dart';

/// Nombre único del trabajo periódico en WorkManager.
const String kNombreWorkerTitulares = 'fnh.worker.titulares';
const String kTagWorker = 'fnh.titulares';

const String _canalAndroidId = 'fnh_titulares';
const String _canalAndroidNombre = 'Titulares nuevos';

/// Punto de entrada del background isolate. Workmanager lo llama periódicamente
/// incluso con la app cerrada. TIENE que ser top-level (o static) para que
/// Dart pueda ubicarlo al arrancar el isolate.
@pragma('vm:entry-point')
void ejecutorWorker() {
  Workmanager().executeTask((nombre, _) async {
    if (nombre != kNombreWorkerTitulares) return true;
    try {
      final sp = await SharedPreferences.getInstance();
      await _comprobarYNotificar(sp);
    } catch (_) {
      // Nunca lanzamos desde el worker: Android podría marcar la tarea
      // como fallida y subir el intervalo entre ejecuciones.
    }
    return true;
  });
}

/// Comprueba si hay titulares nuevos consultando el backend con `since=`.
/// Si hay alguno, dispara una notificación con el total.
Future<void> _comprobarYNotificar(SharedPreferences sp) async {
  final urlBackend = sp.getString('fnh.pref.backendUrl');
  if (urlBackend == null || urlBackend.isEmpty) return;

  // Desde: la última comprobación guardada, o las últimas 24h si no hay.
  final ultimaRaw = sp.getString('fnh.pref.notifUltimaComprobacion');
  final desde = ultimaRaw != null
      ? (DateTime.tryParse(ultimaRaw) ?? DateTime.now().toUtc().subtract(const Duration(hours: 24)))
      : DateTime.now().toUtc().subtract(const Duration(hours: 24));

  final uri = Uri.parse(urlBackend).replace(queryParameters: {
    'per_page': '20',
    'since': desde.toIso8601String(),
    'exclude_source_type': 'video,youtube,podcast',
  });
  final uriItems = uri.replace(path: '${uri.path}/items'.replaceAll('//', '/'));

  final respuesta = await http
      .get(uriItems, headers: const {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));
  if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) return;

  final decodificado = jsonDecode(respuesta.body);
  if (decodificado is! List) return;

  // Respetamos fuentes silenciadas por el usuario (sourcing client-side).
  final bloqueadasCruda = sp.getStringList('fnh.pref.fuentesBloqueadas') ?? const [];
  final bloqueadas = bloqueadasCruda.map((s) => int.tryParse(s) ?? 0).toSet();
  final utilizables = decodificado.whereType<Map<String, dynamic>>().where((raw) {
    final idFuente = raw['source']?['id'];
    if (idFuente is num && bloqueadas.contains(idFuente.toInt())) return false;
    return true;
  }).toList();

  if (utilizables.isEmpty) return;

  final primero = utilizables.first;
  final tituloPrimero = (primero['title'] ?? '').toString();

  await _asegurarInicializado();
  await _mostrarNotificacionTitulares(
    cantidad: utilizables.length,
    tituloDestacado: tituloPrimero,
  );

  await sp.setString(
    'fnh.pref.notifUltimaComprobacion',
    DateTime.now().toUtc().toIso8601String(),
  );
}

bool _inicializado = false;
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

Future<void> _asegurarInicializado() async {
  if (_inicializado) return;
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(
    const InitializationSettings(android: androidInit),
  );
  // Crea el canal de notificación explícitamente — Android 8+ lo requiere.
  const canal = AndroidNotificationChannel(
    _canalAndroidId,
    _canalAndroidNombre,
    description: 'Avisos de nuevos titulares en Flavor News Hub',
    importance: Importance.defaultImportance,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(canal);
  _inicializado = true;
}

Future<void> _mostrarNotificacionTitulares({
  required int cantidad,
  required String tituloDestacado,
}) async {
  final titulo = cantidad == 1
      ? '1 nuevo titular'
      : '$cantidad nuevos titulares';
  const androidDetalle = AndroidNotificationDetails(
    _canalAndroidId,
    _canalAndroidNombre,
    channelDescription: 'Avisos de nuevos titulares en Flavor News Hub',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  await _plugin.show(
    100,
    titulo,
    tituloDestacado,
    const NotificationDetails(android: androidDetalle),
  );
}

/// API pública: registra o cancela la tarea periódica según la frecuencia
/// elegida por el usuario. Se llama desde la UI de settings y al arrancar
/// la app (para restaurar si quedó activa tras un reboot).
Future<void> aplicarFrecuenciaNotif(FrecuenciaNotif frecuencia) async {
  // Siempre cancelamos el trabajo previo para que el cambio tenga efecto
  // incluso cuando se pasa de 60m a 180m: `registerPeriodicTask` no
  // reprograma si la clave existe.
  await Workmanager().cancelByUniqueName(kNombreWorkerTitulares);
  if (!frecuencia.esActiva) return;
  await Workmanager().registerPeriodicTask(
    kNombreWorkerTitulares,
    kNombreWorkerTitulares,
    frequency: Duration(minutes: frecuencia.minutos),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    tag: kTagWorker,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
}

/// Llamar una vez desde `main()` antes de `runApp`. Inicializa el runtime
/// del Workmanager para que el callback de background pueda registrarse.
Future<void> inicializarWorkmanager() async {
  await Workmanager().initialize(
    ejecutorWorker,
    isInDebugMode: false,
  );
}
