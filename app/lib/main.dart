import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/preferences_provider.dart';
import 'features/notifications/data/preferencias_notif.dart';
import 'features/notifications/data/servicio_notificaciones.dart';

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

  final sharedPrefs = await SharedPreferences.getInstance();

  // Workmanager arranca antes de la UI para poder restaurar la tarea
  // periódica de notificaciones si el usuario la tenía activa.
  await inicializarWorkmanager();
  final codigoFrecuencia = sharedPrefs.getString('fnh.pref.notifFrecuencia');
  if (codigoFrecuencia != null) {
    final frecuencia = FrecuenciaNotif.values.firstWhere(
      (f) => f.name == codigoFrecuencia,
      orElse: () => FrecuenciaNotif.nunca,
    );
    if (frecuencia.esActiva) {
      await aplicarFrecuenciaNotif(frecuencia);
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const FlavorNewsHubApp(),
    ),
  );
}
