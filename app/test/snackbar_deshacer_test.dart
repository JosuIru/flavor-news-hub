import 'package:flavor_news_hub/core/widgets/snackbar_deshacer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del SnackBar de deshacer compartido por las acciones de un toque
/// (guardar, marcar útil, silenciar fuente).
void main() {
  Widget appConBoton(VoidCallback onDeshacer) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => mostrarSnackBarDeshacer(
              context,
              mensaje: 'Guardado',
              etiquetaDeshacer: 'Deshacer',
              onDeshacer: onDeshacer,
            ),
            child: const Text('accion'),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra mensaje y acción de deshacer', (tester) async {
    await tester.pumpWidget(appConBoton(() {}));
    await tester.tap(find.text('accion'));
    await tester.pump();

    expect(find.text('Guardado'), findsOneWidget);
    expect(find.text('Deshacer'), findsOneWidget);
  });

  testWidgets('pulsar Deshacer ejecuta el callback', (tester) async {
    var deshecho = 0;
    await tester.pumpWidget(appConBoton(() => deshecho++));
    await tester.tap(find.text('accion'));
    await tester.pump(); // dispara el SnackBar
    await tester.pump(const Duration(seconds: 1)); // completa la animación de entrada

    await tester.tap(find.text('Deshacer'));
    await tester.pump();

    expect(deshecho, 1);
  });

  testWidgets('una segunda acción reemplaza al SnackBar anterior', (tester) async {
    await tester.pumpWidget(appConBoton(() {}));
    await tester.tap(find.text('accion'));
    await tester.pump();
    // Segundo toque: no deben quedar dos SnackBars apilados.
    await tester.tap(find.text('accion'));
    await tester.pump();

    expect(find.text('Guardado'), findsOneWidget);
  });
}
