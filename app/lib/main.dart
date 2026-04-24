import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/preferences_provider.dart';
import 'core/services/ingest_trigger.dart';
import 'core/services/settings_sync.dart';
import 'features/notifications/data/preferencias_notif.dart';
import 'features/notifications/data/servicio_notificaciones.dart';
import 'features/widgets/widget_sintonizador_control.dart';

/// Punto de entrada. Cargamos SharedPreferences antes de montar la UI
/// para que el tema y el idioma apliquen desde el primer frame (sin
/// flash de default → preferencia guardada).
///
/// `JustAudioBackground.init` habilita controles en la notificación del
/// sistema para las radios en vivo (seguir escuchando con pantalla
/// bloqueada, botones bluetooth, Android Auto).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.flavornewshub.audio',
    androidNotificationChannelName: 'Radios en directo',
    androidNotificationOngoing: true,
  );

  // Callback del widget sintonizador: permite play/stop sin abrir la app
  // despachando un isolate Dart en background. Ver widget_sintonizador_control.dart.
  HomeWidget.registerInteractivityCallback(manejadorInteractividadSintonizador);

  final sharedPrefs = await SharedPreferences.getInstance();

  // Workmanager arranca antes de la UI. Siempre registramos el worker
  // periódico (aunque las notificaciones estén off): lo usamos para
  // refrescar los widgets Android de titulares en segundo plano.
  await inicializarWorkmanager();
  final codigoFrecuencia = sharedPrefs.getString('fnh.pref.notifFrecuencia');
  final frecuenciaGuardada = codigoFrecuencia != null
      ? FrecuenciaNotif.values.firstWhere(
          (f) => f.name == codigoFrecuencia,
          orElse: () => FrecuenciaNotif.nunca,
        )
      : FrecuenciaNotif.nunca;
  await aplicarFrecuenciaNotif(frecuenciaGuardada);

  // Despertamos la ingesta del backend. En sitios con poco tráfico
  // web wp-cron tarda en disparar — esto asegura que al abrir la app
  // el backend acaba de pasar por los feeds. Fire-and-forget: no
  // bloqueamos el arranque esperando la respuesta.
  unawaited(dispararIngestaBackend(sharedPrefs));

  // Sincronizar ajustes públicos (URL de donaciones actual del backend,
  // etc.) para que admin pueda cambiarlos sin release nueva de APK.
  unawaited(sincronizarAjustesPublicos(sharedPrefs));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const FlavorNewsHubApp(),
    ),
  );
}
