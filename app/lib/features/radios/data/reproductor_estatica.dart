import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Reproductor secundario que emite un loop de ruido sucio (estática
/// filtrada) durante la carga de una radio. Funciona como feedback
/// nostálgico mientras el stream principal busca sintonía.
///
/// Diseño:
///  - Vive en una instancia de `AudioPlayer` independiente del player
///    principal de radios. Sin `MediaItem` ni `just_audio_background`,
///    así no compite por la sesión de audio del sistema (la radio
///    sigue siendo la única que aparece en la notificación).
///  - El asset es corto (~3s); se reproduce con `LoopMode.one`.
///  - `iniciar()` aplica fade-in para que entre con suavidad.
///  - `detener()` aplica fade-out y luego pausa — así no hay un corte
///    seco cuando el stream conecta y empieza a sonar de verdad.
class ReproductorEstatica {
  ReproductorEstatica();

  static const String _rutaAsset = 'assets/audio/static.mp3';
  static const double _volumenObjetivo = 0.45;
  static const Duration _duracionFade = Duration(milliseconds: 220);

  final AudioPlayer _player = AudioPlayer();
  bool _fuenteCargada = false;
  Future<void>? _cargaEnCurso;
  Timer? _temporizadorFade;
  /// Flag puesto a true por `detener()` para que un `iniciar()` que aún
  /// esté esperando a `_asegurarCargado()` aborte cuando vuelva del
  /// await. Sin él, si el usuario pulsa stop justo mientras se carga el
  /// asset por primera vez (~setAsset lento), la estática arrancaba a
  /// sonar después de que la radio ya se había detenido.
  bool _detencionSolicitada = false;

  Future<void> _asegurarCargado() async {
    if (_fuenteCargada) return;
    _cargaEnCurso ??= _cargarFuente();
    await _cargaEnCurso;
  }

  Future<void> _cargarFuente() async {
    await _player.setAsset(_rutaAsset);
    await _player.setLoopMode(LoopMode.one);
    await _player.setVolume(0);
    _fuenteCargada = true;
  }

  Future<void> iniciar() async {
    _detencionSolicitada = false;
    _temporizadorFade?.cancel();
    try {
      await _asegurarCargado();
    } catch (_) {
      // Si el asset no se puede cargar (caso raro), simplemente no hay
      // estática; no tiene sentido propagar el error y bloquear la radio.
      return;
    }
    if (_detencionSolicitada) return;
    await _player.setVolume(0);
    if (_detencionSolicitada) return;
    if (!_player.playing) {
      await _player.play();
    }
    if (_detencionSolicitada) {
      if (_player.playing) await _player.pause();
      return;
    }
    _fundirHasta(_volumenObjetivo);
  }

  Future<void> detener() async {
    _detencionSolicitada = true;
    _temporizadorFade?.cancel();
    if (!_fuenteCargada) {
      // Carga aún en curso o nunca arrancada. El flag bastará para que
      // `iniciar()` aborte cuando vuelva del await.
      if (_player.playing) await _player.pause();
      return;
    }
    _fundirHasta(0, alAcabar: () async {
      if (_player.playing) {
        await _player.pause();
      }
    });
  }

  /// Fundido lineal hasta `objetivo` en `_duracionFade`. Lo hace en pasos
  /// pequeños con un Timer; `just_audio` no expone una API de envolvente
  /// nativa, pero 12 pasos en 220 ms son imperceptibles.
  void _fundirHasta(double objetivo, {Future<void> Function()? alAcabar}) {
    const pasos = 12;
    final volumenInicial = _player.volume;
    final delta = (objetivo - volumenInicial) / pasos;
    final intervalo = Duration(microseconds: _duracionFade.inMicroseconds ~/ pasos);
    var paso = 0;
    _temporizadorFade?.cancel();
    _temporizadorFade = Timer.periodic(intervalo, (timer) async {
      paso++;
      final volumenSiguiente = paso >= pasos
          ? objetivo
          : (volumenInicial + delta * paso).clamp(0.0, 1.0);
      await _player.setVolume(volumenSiguiente);
      if (paso >= pasos) {
        timer.cancel();
        if (alAcabar != null) await alAcabar();
      }
    });
  }

  Future<void> dispose() async {
    _temporizadorFade?.cancel();
    await _player.dispose();
  }
}
