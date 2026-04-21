import 'package:home_widget/home_widget.dart';

import '../radios/data/reproductor_radio_notifier.dart';

/// Actualiza el widget Android de "Reproductor radio" con el estado del
/// `ReproductorRadioNotifier`. Se invoca desde un listener global en app.dart
/// cada vez que cambia el estado.
class WidgetRadioWriter {
  static const String _nombreProvider = 'ReproductorRadioWidgetProvider';

  static Future<void> escribir(EstadoReproductor estado) async {
    final nombre = estado.radioActual?.name ?? '';
    final codigoEstado = switch (estado.estado) {
      EstadoPlayback.reproduciendo => 'reproduciendo',
      EstadoPlayback.cargando => 'cargando',
      EstadoPlayback.error => 'error',
      EstadoPlayback.detenido => 'detenido',
    };
    await HomeWidget.saveWidgetData<String>('radio_nombre', nombre);
    await HomeWidget.saveWidgetData<String>('radio_estado', codigoEstado);
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
  }
}
