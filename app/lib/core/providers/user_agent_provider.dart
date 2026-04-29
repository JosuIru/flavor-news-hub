import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/canal_distribucion.dart';

/// Cabecera `User-Agent` que la app envía al backend `flavor-news/v1`.
///
/// Antes el cliente HTTP no la fijaba: `package:http` enviaba el UA por
/// defecto de Dart, igual para todas las instalaciones, así que el
/// contador "User-agents distintos" del panel del plugin colapsaba todo
/// el tráfico de la app en un único hash. Con un UA estable e
/// informativo (versión + plataforma + canal) la métrica empieza a
/// servir como variante de cliente — sin filtrar identidad.
///
/// Provider síncrono: se sobreescribe en `main.dart` después de
/// resolver `PackageInfo.fromPlatform()`.
final userAgentProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'userAgentProvider debe sobreescribirse en main.dart con una instancia real.',
  );
});

/// Construye el UA en la forma `FlavorNewsHub/<version> (<plataforma>; <canal>)`.
///
/// Se mantiene fijo para todas las instalaciones del mismo build — no
/// es un identificador por dispositivo. Sólo distingue versión, sistema
/// operativo y canal de distribución (libre / playstore).
String construirUserAgent({required String version}) {
  final plataforma = _nombrePlataforma();
  return 'FlavorNewsHub/$version ($plataforma; $canalDistribucion)';
}

String _nombrePlataforma() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isLinux) return 'Linux';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isFuchsia) return 'Fuchsia';
  return 'Unknown';
}
