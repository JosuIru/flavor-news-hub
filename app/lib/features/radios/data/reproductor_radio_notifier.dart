import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      state = EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: actual,
        mensajeError: error.toString(),
      );
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

  Future<void> parar() async {
    _epochActual++;
    state = EstadoReproductor.detenido;
    await _player.stop();
  }

  Future<void> _reproducir(modelo_radio.Radio radio) async {
    final miEpoch = ++_epochActual;
    // Sólo puede haber un AudioPlayer activo con la sesión de audio del
    // sistema (just_audio_background registra una única MediaSession).
    // Si el reproductor de música/podcast está sonando, lo paramos
    // antes de arrancar la radio — si no, el segundo `setAudioSource`
    // falla con "Failed to set source".
    await _ref.read(reproductorEpisodioProvider.notifier).parar();
    if (miEpoch != _epochActual) return;
    state = EstadoReproductor(estado: EstadoPlayback.cargando, radioActual: radio);
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
      state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: radio);
    } catch (error) {
      if (miEpoch != _epochActual) return;
      state = EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: radio,
        mensajeError: error.toString(),
      );
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
        state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual);
      }
      return;
    }

    final ps = _player.processingState;
    if (ps == ProcessingState.idle) {
      state = EstadoReproductor.detenido;
      return;
    }
    if (ps == ProcessingState.loading || ps == ProcessingState.buffering) {
      state = EstadoReproductor(estado: EstadoPlayback.cargando, radioActual: actual);
      return;
    }
    // Regla 1: `ready` o `completed`. Sólo cambiamos a `reproduciendo`
    // cuando sí está sonando; otros casos los mantenemos para que la
    // suspensión transitoria del SO no rompa la sesión.
    if (reproduciendo && state.estado != EstadoPlayback.reproduciendo) {
      state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual);
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
