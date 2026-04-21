import 'package:home_widget/home_widget.dart';

import '../../core/models/item.dart';

/// Escribe los 3 titulares más recientes en el almacén del widget Android.
///
/// Lo invoca `FeedNotifier` tras una carga exitosa. No falla si el widget
/// no está presente — `HomeWidget.updateWidget` simplemente no tiene
/// efecto si no hay widgets colocados.
class WidgetTitularesWriter {
  static const String _nombreProvider = 'TitularesWidgetProvider';
  static const int _cantidad = 3;

  static Future<void> escribir(List<Item> items) async {
    final seleccion = items.take(_cantidad).toList();
    // Rellenamos siempre los 3 slots para que al vaciar el feed se limpie.
    for (var i = 0; i < _cantidad; i++) {
      final clave = i + 1;
      if (i < seleccion.length) {
        final it = seleccion[i];
        await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', it.title);
        await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', it.source?.name ?? '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_id', it.id.toString());
      } else {
        await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_id', '');
      }
    }
    // Pide al sistema que redibuje el widget.
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
  }
}
