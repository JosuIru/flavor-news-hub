import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Puente a Picture-in-Picture de Android.
///
/// `activar(true)` durante la pantalla del reproductor hace que pulsar Home
/// pase la activity a PiP (el vídeo sigue visible en una ventana flotante).
/// `entrarAhora()` lo fuerza sin esperar al gesto de Home.
class PipService {
  static const MethodChannel _canal = MethodChannel('fnh/pip');
  static final StreamController<bool> _controladorModo =
      StreamController<bool>.broadcast();
  static bool _handlerInstalado = false;

  /// Emite `true`/`false` cuando la activity entra/sale de PiP.
  static Stream<bool> get cambiosDeModo {
    _asegurarHandler();
    return _controladorModo.stream;
  }

  static void _asegurarHandler() {
    if (_handlerInstalado) return;
    _handlerInstalado = true;
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'onModeChanged') {
        _controladorModo.add(llamada.arguments as bool? ?? false);
      }
    });
  }

  static Future<bool> soportado() async {
    if (!Platform.isAndroid) return false;
    try {
      final resultado = await _canal.invokeMethod<bool>('soportaPip');
      return resultado ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> activar(bool activo) async {
    if (!Platform.isAndroid) return;
    try {
      await _canal.invokeMethod<void>('setPipActive', activo);
    } on PlatformException {
      // Si el canal no está registrado (p. ej. en un build que aún no
      // incluye el cambio nativo), lo silenciamos para no romper la UI.
    }
  }

  static Future<bool> entrarAhora() async {
    if (!Platform.isAndroid) return false;
    try {
      final resultado = await _canal.invokeMethod<bool>('entrarEnPip');
      return resultado ?? false;
    } on PlatformException {
      return false;
    }
  }
}
