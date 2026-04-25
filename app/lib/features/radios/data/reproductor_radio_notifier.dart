import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/models/radio.dart' as modelo_radio;
import '../../audio/data/reproductor_episodio_notifier.dart';
import 'reproductor_estatica.dart';

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
      _estatica.detener();
      state = EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: actual,
        mensajeError: error.toString(),
      );
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final ReproductorEstatica _estatica = ReproductorEstatica();
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
    await _estatica.detener();
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
    // Estática: arranca en cuanto entramos en `cargando`. Es un player
    // local sin MediaItem, no compite con la sesión del sistema. Al
    // pasar a `reproduciendo` se hace fade-out en `_sincronizarEstado…`.
    unawaited(_estatica.iniciar());
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
      unawaited(_estatica.detener());
    } catch (error) {
      if (miEpoch != _epochActual) return;
      unawaited(_estatica.detener());
      state = EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: radio,
        mensajeError: error.toString(),
      );
    }
  }

  /// Deriva el estado del player y lo aplica al state de Riverpod si hay
  /// una radio asociada. Cubre todos los `ProcessingState` para que el
  /// icono no se quede congelado en transiciones (ej. usuario pulsa stop
  /// y el player emite `ready+!playing` antes de `idle+!playing`).
  void _sincronizarEstadoConPlayer() {
    final actual = state.radioActual;
    if (actual == null) return;
    final ps = _player.processingState;
    final reproduciendo = _player.playing;
    if (ps == ProcessingState.idle) {
      state = EstadoReproductor.detenido;
      return;
    }
    if (ps == ProcessingState.loading || ps == ProcessingState.buffering) {
      if (state.estado != EstadoPlayback.cargando) {
        state = EstadoReproductor(estado: EstadoPlayback.cargando, radioActual: actual);
      }
      return;
    }
    // ready o completed.
    if (reproduciendo) {
      if (state.estado != EstadoPlayback.reproduciendo) {
        state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual);
        // El stream conectó por su cuenta (p. ej. al recuperar foco de
        // audio) sin pasar por `_reproducir`. Aseguramos que la estática
        // se baja también en este camino.
        unawaited(_estatica.detener());
      }
    } else {
      // Player pausado externamente (foco de audio cedido a otra app o
      // notificación pause). En streams en directo equivale a parar.
      _estatica.detener();
      state = EstadoReproductor.detenido;
    }
  }

  @override
  void dispose() {
    _estatica.dispose();
    _player.dispose();
    super.dispose();
  }
}

final reproductorRadioProvider =
    StateNotifierProvider<ReproductorRadioNotifier, EstadoReproductor>(
  (ref) => ReproductorRadioNotifier(ref),
);
