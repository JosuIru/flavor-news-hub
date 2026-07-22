import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../audio/data/reproductor_episodio_notifier.dart';
import '../../widgets/widget_sintonizador_writer.dart';
import 'radios_favoritas_notifier.dart';

enum EstadoPlayback { detenido, cargando, reproduciendo, error }

@immutable
class EstadoReproductor {
  const EstadoReproductor({
    required this.estado,
    this.radioActual,
    this.mensajeError,
  });

  final EstadoPlayback estado;
  final modelo_radio.Radio? radioActual;
  final String? mensajeError;

  static const detenido = EstadoReproductor(estado: EstadoPlayback.detenido);

  bool reproduciendoRadio(int idRadio) =>
      radioActual?.id == idRadio && estado == EstadoPlayback.reproduciendo;

  bool cargandoRadio(int idRadio) =>
      radioActual?.id == idRadio && estado == EstadoPlayback.cargando;
}

class ReproductorRadioNotifier extends StateNotifier<EstadoReproductor> {
  ReproductorRadioNotifier(this._ref) : super(EstadoReproductor.detenido) {
    // El listener deriva el estado completo del player en cualquier evento.
    // Maneja todos los `ProcessingState` para que el icono refleje siempre
    // lo que hace el motor de audio (no sólo los dos casos extremos
    // ready+playing y idle+!playing).
    _subPlaybackEvent = _player.playbackEventStream.listen((_) {
      _sincronizarEstadoConPlayer();
    }, onError: (Object error, StackTrace st) {
      final actual = state.radioActual;
      _aplicarEstado(EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: actual,
        mensajeError: error.toString(),
      ));
    });
    // Fire-and-forget: si el usuario lo activó en Ajustes, deja la última
    // emisora lista para que el coche la arranque por Bluetooth. Lo
    // diferimos a un microtask para no leer providers durante la
    // construcción del notifier, y todo su cuerpo está protegido: nunca
    // debe tocar el arranque de la app.
    unawaited(Future.microtask(precargarUltimaEmisora));
  }

  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;

  /// Suscripción a los eventos del player. Se guarda para poder cancelarla
  /// en `dispose()` ANTES de `_player.dispose()`: sin esto, un evento
  /// tardío (buffering intermitente con red inestable) podía ejecutar el
  /// callback y hacer `state=` sobre un notifier ya dispuesto → crash
  /// "StateNotifier was used after being disposed". El notifier de
  /// episodios ya lo hace así a propósito.
  StreamSubscription<PlaybackEvent>? _subPlaybackEvent;

  /// Clave de SharedPreferences donde guardamos la última emisora
  /// reproducida (JSON del modelo `Radio`), para poder "armarla" al
  /// arrancar cuando el usuario usa el modo coche/Bluetooth.
  static const _claveUltimaEmisora = 'fnh.radio.ultimaEmisora';

  /// Emisora dejada lista en pausa por `precargarUltimaEmisora`. No está
  /// en el `state` (el usuario no la arrancó); si el player empieza a
  /// sonar (PLAY del coche), `_sincronizarEstadoConPlayer` la promueve a
  /// emisora activa. `null` = no hay nada armado.
  modelo_radio.Radio? _radioPrecargada;

  /// Contador que invalida flujos `_reproducir` en curso cuando el usuario
  /// pulsa parar o cambia de radio mientras la anterior aún cargaba.
  /// Cada llamada nueva incrementa el contador; los awaits internos
  /// comparan su epoch capturado con el actual y abortan si difieren —
  /// así un `_reproducir` lento no puede sobrescribir un `state=detenido`
  /// posterior con un `reproduciendo` obsoleto.
  int _epochActual = 0;

  Future<void> alternar(modelo_radio.Radio radio) async {
    final esLaMisma = state.radioActual?.id == radio.id;
    final estaSonandoOCargando = state.estado == EstadoPlayback.reproduciendo ||
        state.estado == EstadoPlayback.cargando;
    if (esLaMisma && estaSonandoOCargando) {
      await parar();
      return;
    }
    await _reproducir(radio);
  }

  /// Arranca incondicionalmente (sin toggle). Usado por deep links del
  /// widget Sintonizador, donde ▶/◄/► siempre significan "play esta
  /// emisora", nunca "toggle". Si la misma radio ya está sonando,
  /// re-arranca el stream — útil si el sistema lo silenció por
  /// duplicado de MediaSession.
  Future<void> reproducir(modelo_radio.Radio radio) async {
    await _reproducir(radio);
  }

  Future<void> parar() async {
    final miEpoch = ++_epochActual;
    // Durante la parada no debe haber nada armado: un evento rezagado del
    // player con `playing=true` (el stop aún no aterrizó) no puede
    // resucitar la UI vía promoción.
    _radioPrecargada = null;
    final radioDetenida = state.radioActual;
    _aplicarEstado(EstadoReproductor.detenido);
    await _player.stop();
    // Con el modo coche/Bluetooth activo, la emisora recién parada queda
    // armada de nuevo: el PLAY del volante la reanuda y la promoción
    // sincroniza la UI. Sin el ajuste, comportamiento de siempre.
    // El check de epoch evita pisar un `_reproducir` que haya arrancado
    // mientras esperábamos el stop.
    if (miEpoch != _epochActual || radioDetenida == null) return;
    try {
      if (_ref.read(preferenciasProvider).prepararUltimaRadioParaBluetooth) {
        _radioPrecargada = radioDetenida;
      }
    } catch (error) {
      debugPrint('[ReproductorRadio] rearmar tras parar falló: $error');
    }
  }

  /// Canal con `MainActivity` para detener el `RadioService` nativo
  /// (el que arranca el widget Sintonizador en background). Sin esto,
  /// si el usuario tiene la radio sonando vía widget y abre la app y
  /// arranca otra radio desde la UI, los dos streams suenan a la vez.
  static const _canalServicioRadioNativo = MethodChannel('fnh/radio_service');

  Future<void> _detenerServicioNativoSiActivo() async {
    try {
      await _canalServicioRadioNativo.invokeMethod('stop');
    } catch (error) {
      // En plataformas no Android (debug en desktop, tests) el canal no
      // tiene handler; ignoramos. El log nos avisa si Android empezara
      // a fallar de forma sistemática.
      debugPrint('[ReproductorRadio] stop servicio nativo no disponible: $error');
    }
  }

  Future<void> _reproducir(modelo_radio.Radio radio) async {
    final miEpoch = ++_epochActual;
    // El usuario elige emisora explícitamente: cualquier emisora "armada"
    // para el coche deja de tener sentido (esta la sustituye).
    _radioPrecargada = null;
    // Antes de tocar el AudioPlayer de la app, paramos el RadioService
    // nativo si estuviera sonando desde el widget. La parada es rápida
    // (un broadcast intra-proceso) y evitamos dos streams a la vez.
    await _detenerServicioNativoSiActivo();
    if (miEpoch != _epochActual) return;
    // Sólo puede haber un AudioPlayer activo con la sesión de audio del
    // sistema (just_audio_background registra una única MediaSession).
    // Si el reproductor de música/podcast está sonando, lo paramos
    // antes de arrancar la radio — si no, el segundo `setAudioSource`
    // falla con "Failed to set source".
    await _ref.read(reproductorEpisodioProvider.notifier).parar();
    if (miEpoch != _epochActual) return;
    _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.cargando, radioActual: radio));
    try {
      await _player.setAudioSource(_construirFuente(radio));
      if (miEpoch != _epochActual) return;
      await _player.play();
      if (miEpoch != _epochActual) return;
      _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: radio));
      // Recordamos la última emisora para poder "armarla" al arrancar si
      // el usuario tiene activado el modo coche/Bluetooth.
      unawaited(_guardarUltimaEmisora(radio));
    } catch (error) {
      if (miEpoch != _epochActual) return;
      _aplicarEstado(EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: radio,
        mensajeError: error.toString(),
      ));
    }
  }

  /// Construye la fuente de audio (stream + metadatos para la MediaSession
  /// del sistema) de una emisora. Centralizado para que la reproducción
  /// normal y la precarga del modo coche usen exactamente los mismos
  /// metadatos en la notificación y en el head-unit del coche.
  AudioSource _construirFuente(modelo_radio.Radio radio) {
    return AudioSource.uri(
      Uri.parse(radio.streamUrl),
      tag: MediaItem(
        id: '${radio.id}',
        title: radio.name,
        album: radio.territory.isEmpty ? 'Flavor News Hub' : radio.territory,
        artist: radio.territory,
      ),
    );
  }

  /// Deja lista en pausa la última emisora reproducida para que el PLAY
  /// del sistema de audio del coche (al conectar el Bluetooth) o del
  /// volante la reanude sin abrir la app. Sólo actúa si el usuario lo ha
  /// activado en Ajustes (`prepararUltimaRadioParaBluetooth`).
  ///
  /// Clave del diseño: `setAudioSource(..., preload: false)`. Registra la
  /// emisora en la MediaSession —para que el coche vea "algo que
  /// reproducir"— pero NO abre el stream hasta el PLAY: sin datos móviles
  /// gastados ni audio sonando en el arranque.
  ///
  /// Todo va envuelto en try/catch y sin await bloqueante en el arranque:
  /// pase lo que pase, nunca debe afectar al inicio de la app.
  Future<void> precargarUltimaEmisora() async {
    try {
      final activado =
          _ref.read(preferenciasProvider).prepararUltimaRadioParaBluetooth;
      if (!activado) return;
      // Sólo con el reproductor inactivo (arranque en frío). Si ya hay algo
      // sonando o armado, no peleamos por la única MediaSession del sistema.
      if (state.radioActual != null) return;
      if (_radioPrecargada != null) return;
      // Si el RadioService nativo del widget Sintonizador está sonando
      // (fuente = 'servicio'), su MediaSession ya atiende los botones
      // multimedia; armar otra aquí sólo podría desviarlos.
      final fuenteSintonizador =
          await HomeWidget.getWidgetData<String>('sintonizador_fuente');
      if (fuenteSintonizador == 'servicio') return;
      final radio = _leerUltimaEmisora();
      if (radio == null) return;
      await _player.setAudioSource(_construirFuente(radio), preload: false);
      _radioPrecargada = radio;
    } catch (error) {
      debugPrint('[ReproductorRadio] precargar última emisora falló: $error');
    }
  }

  Future<void> _guardarUltimaEmisora(modelo_radio.Radio radio) async {
    try {
      final almacenPreferencias = _ref.read(sharedPreferencesProvider);
      await almacenPreferencias.setString(
        _claveUltimaEmisora,
        jsonEncode(radio.toJson()),
      );
    } catch (error) {
      debugPrint('[ReproductorRadio] guardar última emisora falló: $error');
    }
  }

  modelo_radio.Radio? _leerUltimaEmisora() {
    try {
      final almacenPreferencias = _ref.read(sharedPreferencesProvider);
      final crudo = almacenPreferencias.getString(_claveUltimaEmisora);
      if (crudo == null || crudo.isEmpty) return null;
      final mapa = jsonDecode(crudo) as Map<String, dynamic>;
      final radio = modelo_radio.Radio.fromJson(mapa);
      // Sin stream no hay nada que armar; evitamos un setAudioSource con
      // URI vacío que reventaría.
      if (radio.streamUrl.isEmpty) return null;
      return radio;
    } catch (error) {
      debugPrint('[ReproductorRadio] leer última emisora falló: $error');
      return null;
    }
  }

  /// Deriva el estado del player y lo aplica al state de Riverpod.
  /// Cubre los `ProcessingState` con dos reglas que han ido apareciendo
  /// con la práctica:
  ///
  ///  1. Suspensión del SO (Doze, foco transitorio): `ready+!playing`
  ///     puede ser pausa momentánea, NO terminal. Sólo marcamos
  ///     `detenido` con `idle+!playing` (resultado de `stop()` real).
  ///     Si la pausa fue transitoria, el siguiente evento trae
  ///     `ready+playing=true` y nos resincronizamos sin perder la
  ///     sesión. Antes interpretábamos cualquier `!playing` como
  ///     terminal y la radio se cortaba sola con la pantalla
  ///     bloqueada (v0.9.81).
  ///
  ///  2. Carga en curso (`state.estado == cargando`): cuando
  ///     `_reproducir` cambia la fuente del AudioPlayer, just_audio
  ///     emite un `idle` transitorio entre la fuente vieja y la nueva.
  ///     Si ese `idle` lo trataramos como `detenido` borraríamos
  ///     `radioActual` a mitad de carga y el siguiente click del
  ///     usuario sería el "que parece funcionar" — el clásico bug
  ///     del "hay que darle dos veces". Por eso, mientras
  ///     `state.estado == cargando`, sólo aceptamos transición a
  ///     `reproduciendo` y descartamos cualquier evento intermedio.
  void _sincronizarEstadoConPlayer() {
    final actual = state.radioActual;
    if (actual == null) {
      // No hay emisora activa en la UI. Si hay una "armada" para el coche
      // (ver `precargarUltimaEmisora`) y el player empieza a sonar —el PLAY
      // del coche/volante por Bluetooth—, la promovemos a emisora activa
      // para que la UI y el widget Android reflejen lo que suena.
      //
      // El guard de `idle` importa: `play()` sobre un player parado pone
      // `playing=true` sin cargar nada — promover ahí pintaría
      // "reproduciendo" en silencio. Sólo promovemos cuando el motor está
      // de verdad cargando o listo.
      final precargada = _radioPrecargada;
      final ps = _player.processingState;
      if (precargada != null && _player.playing && ps != ProcessingState.idle) {
        _radioPrecargada = null;
        // Defensivo, espejo de `_reproducir`: si el RadioService nativo
        // del widget estuviera sonando, lo paramos para no acabar con dos
        // streams en paralelo.
        unawaited(_detenerServicioNativoSiActivo());
        final cargando =
            ps == ProcessingState.loading || ps == ProcessingState.buffering;
        _aplicarEstado(EstadoReproductor(
          estado: cargando ? EstadoPlayback.cargando : EstadoPlayback.reproduciendo,
          radioActual: precargada,
        ));
      }
      return;
    }
    final reproduciendo = _player.playing;

    // Regla 2: durante carga, sólo confirmamos `reproduciendo`. Los
    // eventos intermedios (idle/loading/buffering/ready+!playing) son
    // transitorios del cambio de source y no deben tocar el state.
    if (state.estado == EstadoPlayback.cargando) {
      if (reproduciendo) {
        _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual));
      }
      return;
    }

    final ps = _player.processingState;
    if (ps == ProcessingState.idle) {
      _aplicarEstado(EstadoReproductor.detenido);
      return;
    }
    if (ps == ProcessingState.loading || ps == ProcessingState.buffering) {
      _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.cargando, radioActual: actual));
      return;
    }
    // Regla 1: `ready` o `completed`. Sólo cambiamos a `reproduciendo`
    // cuando sí está sonando; otros casos los mantenemos para que la
    // suspensión transitoria del SO no rompa la sesión.
    if (reproduciendo && state.estado != EstadoPlayback.reproduciendo) {
      _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual));
    }
  }

  /// Asigna el nuevo estado al StateNotifier y empuja el cambio al
  /// widget Sintonizador. Centralizado aquí para que las claves del
  /// widget (`sintonizador_estado`, `sintonizador_reproduciendo_id`)
  /// queden siempre sincronizadas con el state real del player —
  /// antes las escribía un callback aparte y se podía desincronizar
  /// si el usuario abría la app y arrancaba la radio desde la UI.
  void _aplicarEstado(EstadoReproductor nuevoEstado) {
    state = nuevoEstado;
    unawaited(_empujarEstadoAlWidget(nuevoEstado));
  }

  Future<void> _empujarEstadoAlWidget(EstadoReproductor nuevoEstado) async {
    final claveEstado = switch (nuevoEstado.estado) {
      EstadoPlayback.cargando => 'cargando',
      EstadoPlayback.reproduciendo => 'reproduciendo',
      EstadoPlayback.detenido || EstadoPlayback.error => '',
    };
    final idActual = nuevoEstado.estado == EstadoPlayback.reproduciendo ||
            nuevoEstado.estado == EstadoPlayback.cargando
        ? '${nuevoEstado.radioActual?.id ?? ''}'
        : '';
    // `fuente` sirve al widget para decidir si ◄/► debe arrancar el
    // RadioService nativo o lanzar un deep link a la app: si la app
    // está reproduciendo, los dos streams paralelos sonarían a la vez.
    final fuente = claveEstado.isEmpty ? '' : 'app';
    try {
      await HomeWidget.saveWidgetData<String>('sintonizador_estado', claveEstado);
      await HomeWidget.saveWidgetData<String>('sintonizador_reproduciendo_id', idActual);
      await HomeWidget.saveWidgetData<String>('sintonizador_fuente', fuente);
      // Sincroniza el dial: cuando la app reproduce una emisora, la aguja
      // del Sintonizador salta a su posición. El índice se calcula sobre
      // la MISMA lista que ve el widget — mismos primeros `maxRadios` del
      // catálogo y, si la banda activa es FAV, filtrada por favoritas
      // (mismo criterio que `SintonizadorWidgetProvider.leerRadiosBanda`).
      // Si la emisora no está en esa lista (fuera del tope o no favorita
      // con banda FAV), el dial se queda donde estaba.
      if (idActual.isNotEmpty) {
        final catalogoRadios = _ref.read(radiosProvider).valueOrNull;
        if (catalogoRadios != null && catalogoRadios.isNotEmpty) {
          var radiosDelDial = catalogoRadios
              .take(WidgetSintonizadorWriter.maxRadios)
              .toList();
          final banda =
              await HomeWidget.getWidgetData<String>('sintonizador_banda');
          if (banda == 'favoritas') {
            final idsFavoritas = _ref.read(radiosFavoritasProvider);
            radiosDelDial = radiosDelDial
                .where((radio) => idsFavoritas.contains(radio.id))
                .toList();
          }
          final indiceEnDial =
              radiosDelDial.indexWhere((radio) => '${radio.id}' == idActual);
          if (indiceEnDial >= 0) {
            await HomeWidget.saveWidgetData<int>(
                'sintonizador_indice_actual', indiceEnDial);
          }
        }
      }
      await HomeWidget.updateWidget(
        name: 'SintonizadorWidgetProvider',
        androidName: 'SintonizadorWidgetProvider',
      );
    } catch (error) {
      // No queremos romper el playback si fallar la actualización del
      // widget (p. ej. en plataformas no-Android, donde home_widget
      // lanza UnimplementedError). El log nos sirve para detectar
      // si Android empieza a fallar de forma sistemática.
      debugPrint('[ReproductorRadio] empujar widget falló: $error');
    }
  }

  @override
  void dispose() {
    // Cancelar la suscripción ANTES de disponer el player: así ningún
    // evento en vuelo intenta tocar el estado de un notifier ya muerto.
    _subPlaybackEvent?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final reproductorRadioProvider =
    StateNotifierProvider<ReproductorRadioNotifier, EstadoReproductor>(
  (ref) => ReproductorRadioNotifier(ref),
);
