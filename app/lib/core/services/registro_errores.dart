import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Último informe de error guardado, o null si no hay ninguno. La pantalla
/// de Ajustes lo observa para mostrar (o no) la opción de compartirlo.
/// Tras compartir o descartar, invalidar este provider refresca la vista.
final ultimoInformeErrorProvider = FutureProvider<InformeError?>((ref) {
  return RegistroErrores.instancia.leerUltimo();
});

/// Un error capturado y persistido, listo para mostrarse o compartirse.
@immutable
class InformeError {
  const InformeError({
    required this.fechaIso,
    required this.tipo,
    required this.mensaje,
    required this.stack,
  });

  final String fechaIso;
  final String tipo;
  final String mensaje;
  final String stack;

  Map<String, Object?> _aJson() => {
        'fecha': fechaIso,
        'tipo': tipo,
        'mensaje': mensaje,
        'stack': stack,
      };

  static InformeError? _desdeJson(String texto) {
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      return InformeError(
        fechaIso: mapa['fecha'] as String? ?? '',
        tipo: mapa['tipo'] as String? ?? '',
        mensaje: mapa['mensaje'] as String? ?? '',
        stack: mapa['stack'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Texto plano que el usuario comparte con quien mantiene la app. Sin
  /// datos personales: solo versión, plataforma y la traza del fallo.
  String comoTextoCompartible({required String version, required String plataforma}) {
    return '''
Informe de error · Flavor News Hub
Versión: $version
Plataforma: $plataforma
Fecha: $fechaIso

$tipo: $mensaje

$stack''';
  }
}

/// Almacén on-device del último error no controlado. No envía nada a
/// ningún servidor —coherente con el manifiesto: sin analítica—; solo
/// guarda la última traza para que el usuario pueda compartirla a mano si
/// quiere. Persiste en SharedPreferences (cacheado tras la primera carga,
/// así que `registrar` es seguro incluso desde el handler de un crash).
class RegistroErrores {
  RegistroErrores._();
  static final RegistroErrores instancia = RegistroErrores._();

  static const String _clave = 'fnh.error.ultimo';

  /// Trunca la traza para no inflar SharedPreferences si el stack es enorme.
  static const int _maxCaracteresStack = 8000;

  Future<void> registrar(Object error, StackTrace? stack, {DateTime? cuando}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fecha = (cuando ?? DateTime.now()).toUtc().toIso8601String();
      var traza = stack?.toString() ?? '';
      if (traza.length > _maxCaracteresStack) {
        traza = '${traza.substring(0, _maxCaracteresStack)}\n…(truncado)';
      }
      final informe = InformeError(
        fechaIso: fecha,
        tipo: error.runtimeType.toString(),
        mensaje: error.toString(),
        stack: traza,
      );
      await prefs.setString(_clave, jsonEncode(informe._aJson()));
    } catch (e) {
      // Registrar el error no debe a su vez romper nada. Si SharedPreferences
      // falla, lo dejamos pasar: el objetivo es no perder al usuario, no
      // garantizar el informe.
      debugPrint('[RegistroErrores] no se pudo persistir: $e');
    }
  }

  Future<InformeError?> leerUltimo() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clave);
    if (texto == null || texto.isEmpty) return null;
    return InformeError._desdeJson(texto);
  }

  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }
}
