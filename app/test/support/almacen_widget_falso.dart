import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Intercepta el `MethodChannel('home_widget')` para que los tests de los
/// `*_writer` puedan comprobar qué se escribió en el almacén nativo y cuántas
/// veces se pidió redibujar cada widget, sin depender de plataforma Android.
///
/// Uso típico:
/// ```dart
/// late AlmacenWidgetFalso almacen;
/// setUp(() => almacen = AlmacenWidgetFalso()..instalar());
/// tearDown(() => almacen.desinstalar());
/// ```
class AlmacenWidgetFalso {
  static const MethodChannel _canal = MethodChannel('home_widget');

  /// id → último valor escrito con `saveWidgetData`.
  final Map<String, Object?> datos = <String, Object?>{};

  /// Nombre de provider de cada `updateWidget`, en orden de llamada.
  final List<String?> redibujados = <String?>[];

  /// Providers cuyo `updateWidget` debe lanzar, para simular un widget que el
  /// usuario no ha colocado. Replica el fallo real que el plugin propaga.
  final Set<String> proveedoresQueFallan = <String>{};

  void instalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (MethodCall llamada) async {
      switch (llamada.method) {
        case 'saveWidgetData':
          final argumentos = llamada.arguments as Map<Object?, Object?>;
          datos[argumentos['id'] as String] = argumentos['data'];
          return true;
        case 'updateWidget':
          final argumentos = llamada.arguments as Map<Object?, Object?>;
          final android = argumentos['android'] as String?;
          if (android != null && proveedoresQueFallan.contains(android)) {
            throw PlatformException(code: 'sin_widget', message: 'no colocado');
          }
          redibujados.add(android);
          return true;
        default:
          return null;
      }
    });
  }

  void desinstalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  }
}
