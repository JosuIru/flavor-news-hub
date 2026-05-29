import 'package:flutter/material.dart';

/// Muestra un SnackBar de confirmación con acción "Deshacer". Pensado para
/// acciones de un solo toque y sin diálogo (guardar, marcar útil, silenciar)
/// que conviene poder revertir si se tocan sin querer al hacer scroll.
///
/// Limpia el SnackBar anterior para no apilarlos cuando el usuario encadena
/// varias acciones seguidas.
void mostrarSnackBarDeshacer(
  BuildContext context, {
  required String mensaje,
  required String etiquetaDeshacer,
  required VoidCallback onDeshacer,
}) {
  final mensajero = ScaffoldMessenger.of(context);
  mensajero.clearSnackBars();
  mensajero.showSnackBar(
    SnackBar(
      content: Text(mensaje),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: etiquetaDeshacer,
        onPressed: onDeshacer,
      ),
    ),
  );
}
