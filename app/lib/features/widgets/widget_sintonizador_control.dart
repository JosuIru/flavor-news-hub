import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// Callback de interactividad del widget "Sintonizador".
///
/// `home_widget` 0.6 permite registrar un callback Dart que se ejecuta
/// en un isolate background cuando el widget dispara un broadcast — sin
/// tener que abrir la app. Lo usamos para arrancar/detener la radio
/// desde los botones ▶ / ■ directamente.
///
/// El callback tiene que ser top-level y estar anotado con
/// `@pragma('vm:entry-point')` para que el AOT compiler no lo elimine.
///
/// URIs que manejamos:
///   flavornews://sintonizador/play?url=...&titulo=...&id=N
///   flavornews://sintonizador/stop
///
/// Limitaciones conocidas:
///  - Si la app principal está abierta y reproduciendo otra radio, este
///    isolate lanzará un AudioPlayer independiente. No deseable pero
///    raro en la práctica: el usuario usa widget O usa app, no ambos.
///  - Android solo permite foreground service desde una actividad
///    visible recientemente; un widget "dormido" sin interacción
///    previa puede no poder arrancar playback. Si falla, el stream
///    se detiene silenciosamente.
@pragma('vm:entry-point')
Future<void> manejadorInteractividadSintonizador(Uri? uri) async {
  if (uri == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  if (uri.scheme != 'flavornews' || uri.host != 'sintonizador') return;
  final accion = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  try {
    if (accion == 'play') {
      final url = uri.queryParameters['url'] ?? '';
      final titulo = uri.queryParameters['titulo'] ?? 'Radio';
      final idRadio = uri.queryParameters['id'] ?? '0';
      if (url.isEmpty) return;
      await _arrancar(url, titulo, idRadio);
    } else if (accion == 'stop') {
      await _detener();
    }
  } catch (e) {
    // Nunca lanzamos desde el isolate del widget: el sistema reintenta
    // y acabaría en bucle. Dejamos log para debug.
    debugPrint('[Sintonizador widget] fallo en $accion: $e');
  }
}

AudioPlayer? _playerFondo;
bool _justAudioBackgroundInicializado = false;

/// Contador que invalida operaciones de `_arrancar` en curso si llega
/// un `_detener` o un `_arrancar` posterior. Cada operación captura el
/// valor al entrar y comprueba en cada `await` si sigue siendo el actual;
/// si no, aborta sin tocar el player. Antes, dos clicks rápidos podían
/// dejar dos `setAudioSource` en flight, o un stop después del play
/// quedaba "comido" porque el play seguía completándose detrás.
int _epocaWidget = 0;

Future<void> _actualizarUiWidget() async {
  await HomeWidget.updateWidget(
    name: 'SintonizadorWidgetProvider',
    androidName: 'SintonizadorWidgetProvider',
  );
}

Future<void> _arrancar(String url, String titulo, String idRadio) async {
  final miEpoca = ++_epocaWidget;
  if (!_justAudioBackgroundInicializado) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'org.flavornewshub.audio',
        androidNotificationChannelName: 'Radios en directo',
        androidNotificationOngoing: true,
      );
    } catch (_) {
      // Si el isolate principal ya lo inicializó, la segunda llamada
      // lanza — ignoramos y seguimos.
    }
    _justAudioBackgroundInicializado = true;
  }
  if (miEpoca != _epocaWidget) return;

  // Si había una sesión previa (cambio de emisora desde el widget) la
  // paramos de forma limpia antes de cargar la nueva. Sin esto el
  // segundo `setAudioSource` puede solapar con la primera y
  // just_audio_background lanza "Failed to set source".
  if (_playerFondo != null) {
    try {
      await _playerFondo!.stop();
    } catch (_) {}
    if (miEpoca != _epocaWidget) return;
  } else {
    _playerFondo = AudioPlayer();
  }

  // Estado "cargando" antes del setAudioSource para que el widget
  // muestre la barra de progreso y el botón ▶ → `…` durante el
  // buffereo (1-3 s típico en radios libres).
  await HomeWidget.saveWidgetData<String>('sintonizador_estado', 'cargando');
  await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', idRadio);
  await _actualizarUiWidget();

  try {
    await _playerFondo!.setAudioSource(
      AudioSource.uri(
        Uri.parse(url),
        tag: MediaItem(id: idRadio, title: titulo, album: 'Flavor News Hub'),
      ),
    );
    if (miEpoca != _epocaWidget) return;
    await _playerFondo!.play();
    if (miEpoca != _epocaWidget) return;
  } catch (error) {
    debugPrint('[Sintonizador widget] setAudioSource/play falló: $error');
    if (miEpoca != _epocaWidget) return;
    await HomeWidget.saveWidgetData<String>('sintonizador_estado', '');
    await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', '');
    await _actualizarUiWidget();
    return;
  }

  // Marcamos qué estamos reproduciendo. El provider Kotlin lo lee para
  // saber si ◄/► también deben cambiar el playback (no sólo el dial)
  // y para alternar la paleta del dial (LEDs apagados ↔ ámbar).
  await HomeWidget.saveWidgetData<String>('sintonizador_estado', 'reproduciendo');
  await _actualizarUiWidget();
}

Future<void> _detener() async {
  // Invalidamos cualquier `_arrancar` en vuelo: cuando éste vuelva del
  // próximo await comprobará la época y abortará en lugar de pisar el
  // estado "" que ponemos aquí.
  _epocaWidget++;
  // Pintamos parado YA en la UI antes del stop() del player. Si
  // Android tarda en liberar el AudioFocus, el usuario igual ve el
  // dial apagado al instante.
  await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', '');
  await HomeWidget.saveWidgetData<String>('sintonizador_estado', '');
  await _actualizarUiWidget();
  try {
    await _playerFondo?.stop();
    await _playerFondo?.dispose();
  } catch (_) {}
  _playerFondo = null;
}
