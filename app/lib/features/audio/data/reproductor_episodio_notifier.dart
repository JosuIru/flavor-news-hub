import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../../core/models/item.dart';
import '../../radios/data/reproductor_radio_notifier.dart';

/// Estado del reproductor de episodio. Distinto del de radio porque aquí hay
/// duración conocida, posición, seek y además una cola de reproducción.
enum EstadoEpisodio { detenido, cargando, reproduciendo, pausado, error }

/// Función que pide más tracks cuando la cola se agota. La devuelve quien
/// arranca la reproducción (normalmente la pantalla de música, que sabe
/// cómo consultar Audius/Funkwhale/Jamendo en paralelo). Devuelve `null`
/// cuando no hay más que traer.
typedef ProveedorSiguientes = Future<List<Item>?> Function(Item ultimoReproducido);

@immutable
class EstadoReproductorEpisodio {
  const EstadoReproductorEpisodio({
    required this.estado,
    this.episodioActual,
    this.cola = const <Item>[],
    this.indiceEnCola = 0,
    this.posicion = Duration.zero,
    this.duracion = Duration.zero,
    this.velocidad = 1.0,
    this.sleepTimerRestante,
    this.mensajeError,
  });

  final EstadoEpisodio estado;
  final Item? episodioActual;
  final List<Item> cola;
  final int indiceEnCola;
  final Duration posicion;
  final Duration duracion;
  final double velocidad;
  /// Si está activo, cuánto falta para que el player pare por sí solo.
  /// `null` = no hay timer.
  final Duration? sleepTimerRestante;
  final String? mensajeError;

  static const detenido = EstadoReproductorEpisodio(estado: EstadoEpisodio.detenido);

  bool get tienePrevio => indiceEnCola > 0;
  bool get tieneSiguiente => indiceEnCola < cola.length - 1;

  bool reproduciendoEpisodio(int idEpisodio) =>
      episodioActual?.id == idEpisodio && estado == EstadoEpisodio.reproduciendo;

  EstadoReproductorEpisodio copyWith({
    EstadoEpisodio? estado,
    Item? episodioActual,
    List<Item>? cola,
    int? indiceEnCola,
    Duration? posicion,
    Duration? duracion,
    double? velocidad,
    Duration? sleepTimerRestante,
    bool limpiarSleepTimer = false,
    String? mensajeError,
    bool limpiarError = false,
  }) {
    return EstadoReproductorEpisodio(
      estado: estado ?? this.estado,
      episodioActual: episodioActual ?? this.episodioActual,
      cola: cola ?? this.cola,
      indiceEnCola: indiceEnCola ?? this.indiceEnCola,
      posicion: posicion ?? this.posicion,
      duracion: duracion ?? this.duracion,
      velocidad: velocidad ?? this.velocidad,
      sleepTimerRestante: limpiarSleepTimer
          ? null
          : (sleepTimerRestante ?? this.sleepTimerRestante),
      mensajeError: limpiarError ? null : (mensajeError ?? this.mensajeError),
    );
  }
}

/// Controla un `AudioPlayer` con cola.
///
/// - `reproducir` sin `cola` reproduce un único track (comportamiento legacy).
/// - `reproducir` con `cola` reproduce esa cola empezando por `indiceInicial`.
/// - Al terminar un track (`ProcessingState.completed`), avanza al siguiente
///   de la cola automáticamente.
/// - Si se agota la cola y hay un `proveedorSiguientes` activo, le pedimos
///   más tracks (p. ej. "más del mismo artista") y extendemos.
class ReproductorEpisodioNotifier extends StateNotifier<EstadoReproductorEpisodio> {
  ReproductorEpisodioNotifier(this._ref) : super(EstadoReproductorEpisodio.detenido) {
    _player.playbackEventStream.listen((_) {
      final actual = state.episodioActual;
      if (actual == null) return;
      final nuevoEstado = _estadoDesdePlayer();
      state = state.copyWith(
        estado: nuevoEstado,
        posicion: _player.position,
        duracion: _player.duration ?? state.duracion,
      );
      // `processingState == completed` sólo dispara una vez por track.
      if (_player.processingState == ProcessingState.completed) {
        _alTerminarTrack();
      }
    }, onError: (Object error, StackTrace st) {
      state = state.copyWith(
        estado: EstadoEpisodio.error,
        mensajeError: error.toString(),
      );
    });

    _player.positionStream.listen((posicion) {
      if (state.episodioActual == null) return;
      state = state.copyWith(posicion: posicion);
    });

    _player.durationStream.listen((duracion) {
      if (duracion == null || state.episodioActual == null) return;
      state = state.copyWith(duracion: duracion);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final Ref _ref;
  ProveedorSiguientes? _proveedorSiguientes;
  bool _extendiendoCola = false;
  Timer? _sleepTimer;

  EstadoEpisodio _estadoDesdePlayer() {
    if (_player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering) {
      return EstadoEpisodio.cargando;
    }
    if (_player.playing) return EstadoEpisodio.reproduciendo;
    if (_player.processingState == ProcessingState.ready) return EstadoEpisodio.pausado;
    if (_player.processingState == ProcessingState.completed) return EstadoEpisodio.detenido;
    return EstadoEpisodio.detenido;
  }

  /// Reproduce `episodio`. Si `cola` llega con la llamada, se interpreta
  /// como lista de reproducción y `indiceInicial` marca dónde arranca;
  /// si no, se reproduce como track único (cola de tamaño 1).
  Future<void> reproducir(
    Item episodio, {
    List<Item>? cola,
    int indiceInicial = 0,
    ProveedorSiguientes? proveedorSiguientes,
  }) async {
    if (episodio.audioUrl.isEmpty) return;
    _proveedorSiguientes = proveedorSiguientes;
    final colaFinal = cola != null && cola.isNotEmpty ? cola : [episodio];
    final indiceFinal = cola != null && cola.isNotEmpty
        ? indiceInicial.clamp(0, colaFinal.length - 1)
        : 0;

    // Pausa/reanudación del mismo track: evita recargar el source.
    if (state.episodioActual?.id == episodio.id &&
        state.estado == EstadoEpisodio.pausado &&
        cola == null) {
      await _player.play();
      return;
    }

    state = EstadoReproductorEpisodio(
      estado: EstadoEpisodio.cargando,
      episodioActual: episodio,
      cola: colaFinal,
      indiceEnCola: indiceFinal,
    );
    await _cargarYReproducir(episodio);
  }

  Future<void> _cargarYReproducir(Item episodio) async {
    // Sólo puede haber un AudioPlayer activo con la sesión de fondo del
    // sistema. Si la radio está sonando, la paramos antes — si no, este
    // `setAudioSource` falla con un error y el usuario ve "error" sin
    // saber por qué.
    await _ref.read(reproductorRadioProvider.notifier).parar();
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(episodio.audioUrl),
          tag: MediaItem(
            id: '${episodio.id}',
            title: episodio.title,
            album: episodio.source?.name ?? 'Flavor News Hub',
            artist: episodio.source?.name,
            artUri: episodio.mediaUrl.isNotEmpty ? Uri.tryParse(episodio.mediaUrl) : null,
          ),
        ),
      );
      await _player.play();
    } catch (error) {
      state = state.copyWith(
        estado: EstadoEpisodio.error,
        mensajeError: error.toString(),
      );
    }
  }

  Future<void> _alTerminarTrack() async {
    if (state.tieneSiguiente) {
      await siguiente();
      return;
    }
    // Cola agotada: intentamos extenderla pidiendo más al proveedor (p. ej.
    // "más pistas del mismo artista"). Evitamos bucles con `_extendiendoCola`.
    if (_proveedorSiguientes == null || _extendiendoCola) return;
    final ultimo = state.episodioActual;
    if (ultimo == null) return;
    _extendiendoCola = true;
    try {
      final adicionales = await _proveedorSiguientes!(ultimo);
      if (adicionales == null || adicionales.isEmpty) return;
      final colaAmpliada = [...state.cola, ...adicionales];
      state = state.copyWith(cola: colaAmpliada);
      await siguiente();
    } finally {
      _extendiendoCola = false;
    }
  }

  Future<void> siguiente() async {
    // Si aún hay algo en la cola, avanzamos directamente.
    if (state.tieneSiguiente) {
      final nuevoIndice = state.indiceEnCola + 1;
      final nuevoEpisodio = state.cola[nuevoIndice];
      state = state.copyWith(
        estado: EstadoEpisodio.cargando,
        episodioActual: nuevoEpisodio,
        indiceEnCola: nuevoIndice,
        posicion: Duration.zero,
        duracion: Duration.zero,
        limpiarError: true,
      );
      await _cargarYReproducir(nuevoEpisodio);
      return;
    }
    // Cola agotada pero el usuario pidió salto: activamos el mismo flujo
    // que el autoplay al terminar — proveedor por artista → género.
    await _alTerminarTrack();
  }

  Future<void> previo() async {
    if (!state.tienePrevio) return;
    final nuevoIndice = state.indiceEnCola - 1;
    final nuevoEpisodio = state.cola[nuevoIndice];
    state = state.copyWith(
      estado: EstadoEpisodio.cargando,
      episodioActual: nuevoEpisodio,
      indiceEnCola: nuevoIndice,
      posicion: Duration.zero,
      duracion: Duration.zero,
      limpiarError: true,
    );
    await _cargarYReproducir(nuevoEpisodio);
  }

  Future<void> pausar() async {
    await _player.pause();
  }

  Future<void> reanudar() async {
    await _player.play();
  }

  Future<void> parar() async {
    await _player.stop();
    state = EstadoReproductorEpisodio.detenido;
  }

  Future<void> saltar(Duration destino) async {
    await _player.seek(destino);
  }

  /// Cambia la velocidad de reproducción. Valores típicos: 0.75, 1.0, 1.25,
  /// 1.5, 2.0. `just_audio` lo aplica inmediatamente sin corte.
  Future<void> cambiarVelocidad(double velocidad) async {
    await _player.setSpeed(velocidad);
    state = state.copyWith(velocidad: velocidad);
  }

  /// Programa una parada automática. Si ya había un timer, lo reemplaza.
  /// Cuenta atrás en tiempo real (actualiza `sleepTimerRestante` cada
  /// segundo) para que la UI pueda mostrarlo.
  Future<void> programarSleepTimer(Duration duracion) async {
    cancelarSleepTimer();
    if (duracion <= Duration.zero) return;
    var restante = duracion;
    state = state.copyWith(sleepTimerRestante: restante);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      restante = restante - const Duration(seconds: 1);
      if (restante <= Duration.zero) {
        t.cancel();
        _sleepTimer = null;
        parar();
        state = state.copyWith(limpiarSleepTimer: true);
      } else {
        state = state.copyWith(sleepTimerRestante: restante);
      }
    });
  }

  void cancelarSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (state.sleepTimerRestante != null) {
      state = state.copyWith(limpiarSleepTimer: true);
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final reproductorEpisodioProvider =
    StateNotifierProvider<ReproductorEpisodioNotifier, EstadoReproductorEpisodio>(
  (ref) => ReproductorEpisodioNotifier(ref),
);
