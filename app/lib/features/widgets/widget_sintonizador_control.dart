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

Future<void> _arrancar(String url, String titulo, String idRadio) async {
  if (!_justAudioBackgroundInicializado) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'org.flavornewshub.audio',
        androidNotificationChannelName: 'Radios en directo',
        androidNotificationOngoing: true,
      );
      _justAudioBackgroundInicializado = true;
    } catch (_) {
      // Si el isolate principal ya lo inicializó, la segunda llamada
      // lanza — ignoramos y seguimos.
      _justAudioBackgroundInicializado = true;
    }
  }
  _playerFondo ??= AudioPlayer();
  await _playerFondo!.setAudioSource(
    AudioSource.uri(
      Uri.parse(url),
      tag: MediaItem(id: idRadio, title: titulo, album: 'Flavor News Hub'),
    ),
  );
  await _playerFondo!.play();
  // Marcamos qué estamos reproduciendo en el almacén compartido del
  // widget (HomeWidgetPlugin). Lo lee el provider Kotlin para saber
  // si ◄/► debe también cambiar el playback, no sólo el dial.
  await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', idRadio);
}

Future<void> _detener() async {
  await _playerFondo?.stop();
  await _playerFondo?.dispose();
  _playerFondo = null;
  await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', '');
}
