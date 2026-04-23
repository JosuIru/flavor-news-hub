import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
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

/// Comprueba si hay contenido nuevo (titulares, vídeos, podcasts) desde la
/// última comprobación y dispara una notificación combinada.
Future<void> _comprobarYNotificar(SharedPreferences sp) async {
  final urlBackend = sp.getString('fnh.pref.backendUrl');
  if (urlBackend == null || urlBackend.isEmpty) return;

  // Desde: la última comprobación guardada, o las últimas 24h si no hay.
  final ultimaRaw = sp.getString('fnh.pref.notifUltimaComprobacion');
  final desde = ultimaRaw != null
      ? (DateTime.tryParse(ultimaRaw) ?? DateTime.now().toUtc().subtract(const Duration(hours: 24)))
      : DateTime.now().toUtc().subtract(const Duration(hours: 24));

  // Pedimos TODO lo publicado desde `desde` (sin excluir video/podcast)
  // y luego lo clasificamos localmente por `source.feed_type`. Así con
  // una sola llamada cubrimos las 3 categorías y evitamos tres
  // peticiones seriales por cada ejecución del worker.
  final uri = Uri.parse(urlBackend).replace(queryParameters: {
    'per_page': '30',
    'since': desde.toIso8601String(),
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

  // Separamos en titulares (texto), vídeos y podcasts según el feed_type
  // de la fuente para poder construir un subtexto tipo "2 titulares · 1
  // vídeo · 1 podcast".
  final titulares = <Map<String, dynamic>>[];
  final videos = <Map<String, dynamic>>[];
  final podcasts = <Map<String, dynamic>>[];
  for (final raw in utilizables) {
    final feedType = (raw['source']?['feed_type'] ?? '').toString().toLowerCase();
    if (feedType == 'podcast') {
      podcasts.add(raw);
    } else if (feedType == 'youtube' || feedType == 'video' || feedType == 'peertube') {
      videos.add(raw);
    } else {
      titulares.add(raw);
    }
  }

  // El widget de titulares muestra sólo noticias de texto — los vídeos y
  // podcasts se notifican pero no ocupan slot del widget, que está
  // pensado como titulares rápidos.
  await _actualizarWidgetTitulares(titulares);

  if (utilizables.isEmpty) return;

  final notifActiva = sp.getBool('fnh.pref.notifActiva') ?? false;
  if (!notifActiva) return;

  await _asegurarInicializado();
  await _mostrarNotificacionContenidoNuevo(
    titulares: titulares,
    videos: videos,
    podcasts: podcasts,
  );

  await sp.setString(
    'fnh.pref.notifUltimaComprobacion',
    DateTime.now().toUtc().toIso8601String(),
  );
}

/// Empuja los 3 primeros titulares al almacén del widget Android sin
/// depender del modelo `Item` — el worker corre en un isolate donde
/// importar el resto de providers complicaría el arranque.
Future<void> _actualizarWidgetTitulares(List<Map<String, dynamic>> items) async {
  for (var i = 0; i < 3; i++) {
    final clave = i + 1;
    if (i < items.length) {
      final it = items[i];
      final titulo = (it['title'] ?? '').toString();
      final fuente = (it['source']?['name'] ?? '').toString();
      final id = (it['id'] ?? '').toString();
      await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', titulo);
      await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', fuente);
      await HomeWidget.saveWidgetData<String>('titular_${clave}_id', id);
    } else {
      await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', '');
      await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', '');
      await HomeWidget.saveWidgetData<String>('titular_${clave}_id', '');
    }
  }
  await HomeWidget.updateWidget(
    name: 'TitularesWidgetProvider',
    androidName: 'TitularesWidgetProvider',
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

Future<void> _mostrarNotificacionContenidoNuevo({
  required List<Map<String, dynamic>> titulares,
  required List<Map<String, dynamic>> videos,
  required List<Map<String, dynamic>> podcasts,
}) async {
  final partes = <String>[];
  if (titulares.isNotEmpty) {
    partes.add(titulares.length == 1 ? '1 titular' : '${titulares.length} titulares');
  }
  if (videos.isNotEmpty) {
    partes.add(videos.length == 1 ? '1 vídeo' : '${videos.length} vídeos');
  }
  if (podcasts.isNotEmpty) {
    partes.add(podcasts.length == 1 ? '1 podcast' : '${podcasts.length} podcasts');
  }
  if (partes.isEmpty) return;
  final titulo = 'Nuevo contenido: ${partes.join(' · ')}';

  // Elegimos un subtítulo destacado con preferencia: titular > vídeo >
  // podcast. Si el usuario sólo recibe novedad de un tipo el subtítulo
  // será de ese tipo; si son mezcla priorizamos lectura de texto.
  String destacado = '';
  if (titulares.isNotEmpty) {
    destacado = (titulares.first['title'] ?? '').toString();
  } else if (videos.isNotEmpty) {
    destacado = (videos.first['title'] ?? '').toString();
  } else if (podcasts.isNotEmpty) {
    destacado = (podcasts.first['title'] ?? '').toString();
  }

  const androidDetalle = AndroidNotificationDetails(
    _canalAndroidId,
    _canalAndroidNombre,
    channelDescription: 'Avisos de nuevo contenido en Flavor News Hub',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  await _plugin.show(
    100,
    titulo,
    destacado,
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
  // Frecuencia efectiva: la que eligió el usuario, o 60 min como
  // baseline cuando las notificaciones están apagadas — así el widget
  // de titulares sigue refrescándose aunque no queramos popups.
  // Guardamos la preferencia para que el worker sepa si puede notificar.
  final sp = await SharedPreferences.getInstance();
  await sp.setBool('fnh.pref.notifActiva', frecuencia.esActiva);
  final minutos = frecuencia.esActiva ? frecuencia.minutos : 60;
  await Workmanager().registerPeriodicTask(
    kNombreWorkerTitulares,
    kNombreWorkerTitulares,
    frequency: Duration(minutes: minutos),
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
