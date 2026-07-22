import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/preferences_provider.dart';
import 'core/providers/user_agent_provider.dart';
import 'core/services/ingest_trigger.dart';
import 'core/services/registro_errores.dart';
import 'core/services/settings_sync.dart';
import 'core/widgets/pantalla_error.dart';
import 'features/notifications/data/preferencias_notif.dart';
import 'features/notifications/data/servicio_notificaciones.dart';

/// Punto de entrada. Instala primero la red de seguridad de errores y
/// luego arranca dentro de una zona protegida para que ningún fallo
/// —ni del framework, ni asíncrono, ni en el propio arranque— tumbe la
/// app sin dejar rastro. Con distribución directa y usuarios reales, un
/// crash silencioso en arranque es la peor pérdida: el usuario ve negro y
/// desinstala. Aquí siempre queda un informe local que puede compartir.
void main() {
  // Errores del framework (build/layout/paint): los pintamos en consola en
  // debug y registramos el informe local en todos los casos.
  FlutterError.onError = (detalles) {
    FlutterError.presentError(detalles);
    RegistroErrores.instancia.registrar(detalles.exception, detalles.stack);
  };

  // Recuadro rojo por defecto → aviso sobrio que no asusta al usuario.
  ErrorWidget.builder = (detalles) => WidgetErrorSobrio(detalles: detalles);

  // Errores asíncronos que no atrapa ninguna zona (callbacks de plugins,
  // motores nativos). Devolver true marca el error como gestionado.
  PlatformDispatcher.instance.onError = (error, stack) {
    RegistroErrores.instancia.registrar(error, stack);
    return true;
  };

  runZonedGuarded(_arrancar, (error, stack) {
    RegistroErrores.instancia.registrar(error, stack);
    // CLAVE: solo sustituimos la UI por la pantalla de error si el arranque
    // falló ANTES de montar la app. Una vez montada, un error asíncrono
    // suelto (p.ej. un provider que se dispone a mitad) NO debe reemplazar la
    // UI viva: hacer `runApp` aquí desmontaría el ProviderScope y los
    // providers en vuelo fallarían con "container disposed", disparando más
    // errores → cascada. Montada la app, basta con registrar el informe.
    if (!_appMontada) {
      runApp(const AppErrorArranque(alReintentar: _arrancar));
    }
  });
}

/// Si la app llegó a montarse (runApp en `_arrancar`). A partir de ahí, los
/// errores asíncronos solo se registran; no reemplazan la UI.
bool _appMontada = false;

/// Guarda de idempotencia: `JustAudioBackground.init` lanza
/// "already initialized" si se llama dos veces. Sin esto, el botón
/// "Reintentar" de la pantalla de error re-ejecutaba `_arrancar`, volvía a
/// invocarlo y petaba de nuevo → el usuario no podía salir nunca.
bool _audioBackgroundInicializado = false;

/// Secuencia de arranque. Extraída de `main` para poder relanzarla desde la
/// pantalla de error sin reiniciar el proceso.
///
/// Cargamos SharedPreferences antes de montar la UI para que el tema y el
/// idioma apliquen desde el primer frame (sin flash de default →
/// preferencia guardada).
///
/// `JustAudioBackground.init` habilita controles en la notificación del
/// sistema para las radios en vivo (seguir escuchando con pantalla
/// bloqueada, botones bluetooth, Android Auto).
Future<void> _arrancar() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences es la ÚNICA dependencia dura del arranque: sin ella
  // no podemos aplicar tema/idioma ni sobreescribir el provider. El resto
  // de inicializaciones nativas (audio en segundo plano, workmanager,
  // notificaciones, info de paquete) son features opcionales: si alguna
  // falla en un fabricante hostil (Xiaomi/Huawei con gestión agresiva de
  // background, OEM sin canal de notificación de audio…), NO deben tumbar
  // la app entera a la pantalla de error. Por eso cada una va en su propio
  // try/catch y `runApp` se ejecuta siempre.
  final sharedPrefs = await SharedPreferences.getInstance();

  // Controles de audio en la notificación del sistema (radio con pantalla
  // bloqueada, botones bluetooth, Android Auto). Opcional: sin esto la
  // radio sigue sonando, solo pierde los controles en la notificación.
  if (!_audioBackgroundInicializado) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'org.flavornewshub.audio',
        androidNotificationChannelName: 'Radios en directo',
        androidNotificationOngoing: true,
      );
      _audioBackgroundInicializado = true;
    } catch (error, pila) {
      RegistroErrores.instancia.registrar(error, pila);
    }
  }

  // Resolvemos el User-Agent una sola vez al arranque para que el
  // cliente HTTP del backend pueda enviarlo síncronamente. El plugin
  // lo usa como variante de cliente en su panel de uso anónimo. Si
  // `PackageInfo` falla, caemos a un UA con versión desconocida en vez
  // de abortar el arranque.
  String versionApp = '0.0.0';
  try {
    final infoPaquete = await PackageInfo.fromPlatform();
    versionApp = infoPaquete.version;
  } catch (error, pila) {
    RegistroErrores.instancia.registrar(error, pila);
  }
  final userAgent = construirUserAgent(version: versionApp);

  // Workmanager + tarea periódica de titulares. Opcional: si el runtime
  // de background no arranca, la app funciona igual (sin notificaciones
  // ni refresco del widget con la app cerrada). Todo dentro del try para
  // que un fallo de registro no impida montar la UI.
  try {
    await inicializarWorkmanager();
    final codigoFrecuencia = sharedPrefs.getString('fnh.pref.notifFrecuencia');
    final frecuenciaGuardada = codigoFrecuencia != null
        ? FrecuenciaNotif.values.firstWhere(
            (f) => f.name == codigoFrecuencia,
            orElse: () => FrecuenciaNotif.nunca,
          )
        : FrecuenciaNotif.nunca;
    await aplicarFrecuenciaNotif(frecuenciaGuardada);
  } catch (error, pila) {
    RegistroErrores.instancia.registrar(error, pila);
  }

  // Despertamos la ingesta del backend. En sitios con poco tráfico
  // web wp-cron tarda en disparar — esto asegura que al abrir la app
  // el backend acaba de pasar por los feeds. Fire-and-forget: no
  // bloqueamos el arranque esperando la respuesta.
  unawaited(dispararIngestaBackend(sharedPrefs));

  // Sincronizar ajustes públicos (URL de donaciones actual del backend,
  // etc.) para que admin pueda cambiarlos sin release nueva de APK.
  unawaited(sincronizarAjustesPublicos(sharedPrefs));

  // La inicialización crítica terminó: a partir de aquí la app está montada y
  // ningún error asíncrono debe reemplazar la UI (ver el handler en `main`).
  _appMontada = true;
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        userAgentProvider.overrideWithValue(userAgent),
      ],
      child: const FlavorNewsHubApp(),
    ),
  );
}
