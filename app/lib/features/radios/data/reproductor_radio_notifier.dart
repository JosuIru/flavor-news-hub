import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/models/radio.dart' as modelo_radio;

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
  ReproductorRadioNotifier() : super(EstadoReproductor.detenido) {
    _player.playbackEventStream.listen((evento) {
      final actual = state.radioActual;
      if (actual == null) return;
      if (_player.processingState == ProcessingState.ready && _player.playing) {
        state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: actual);
      } else if (_player.processingState == ProcessingState.idle && !_player.playing) {
        state = EstadoReproductor.detenido;
      }
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

  Future<void> alternar(modelo_radio.Radio radio) async {
    if (state.radioActual?.id == radio.id &&
        (state.estado == EstadoPlayback.reproduciendo || state.estado == EstadoPlayback.cargando)) {
      await parar();
      return;
    }
    await _reproducir(radio);
  }

  Future<void> parar() async {
    await _player.stop();
    state = EstadoReproductor.detenido;
  }

  Future<void> _reproducir(modelo_radio.Radio radio) async {
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
      await _player.play();
      state = EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: radio);
    } catch (error) {
      state = EstadoReproductor(
        estado: EstadoPlayback.error,
        radioActual: radio,
        mensajeError: error.toString(),
      );
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
  (ref) => ReproductorRadioNotifier(),
);
