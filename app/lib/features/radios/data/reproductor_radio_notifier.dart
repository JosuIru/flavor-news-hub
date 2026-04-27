import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/models/radio.dart' as modelo_radio;
import '../../audio/data/reproductor_episodio_notifier.dart';

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
    _player.playbackEventStream.listen((_) {
      _sincronizarEstadoConPlayer();
    }, onError: (Object error, StackTrace st) {
      final actual = state.radioActual;
      _aplicarEstado(EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: actual,
        mensajeError: error.toString(),
      ));
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;

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
    _epochActual++;
    _aplicarEstado(EstadoReproductor.detenido);
    await _player.stop();
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
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(radio.streamUrl),
          tag: MediaItem(
            id: '${radio.id}',
            title: radio.name,
            album: radio.territory.isEmpty ? 'Flavor News Hub' : radio.territory,
            artist: radio.territory,
          ),
        ),
      );
      if (miEpoch != _epochActual) return;
      await _player.play();
      if (miEpoch != _epochActual) return;
      _aplicarEstado(EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: radio));
    } catch (error) {
      if (miEpoch != _epochActual) return;
      _aplicarEstado(EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: radio,
        mensajeError: error.toString(),
      ));
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
    if (actual == null) return;
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
    _player.dispose();
    super.dispose();
  }
}

final reproductorRadioProvider =
    StateNotifierProvider<ReproductorRadioNotifier, EstadoReproductor>(
  (ref) => ReproductorRadioNotifier(ref),
);
