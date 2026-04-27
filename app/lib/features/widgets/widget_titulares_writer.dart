import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/models/item.dart';

/// Escribe los titulares más recientes en el almacén del widget Android.
///
/// Lo invoca `FeedNotifier` tras una carga exitosa. No falla si el widget
/// no está presente — `HomeWidget.updateWidget` simplemente no tiene
/// efecto si no hay widgets colocados.
///
/// Cantidad: 10 items. El widget Kotlin pinta una `ListView` scrolleable;
/// el sistema sólo construye los visibles, así que mantener el almacén
/// con 10 no impacta perceptiblemente el redibujado.
class WidgetTitularesWriter {
  static const String _nombreProvider = 'TitularesWidgetProvider';
  static const int _cantidad = 10;

  static Future<void> escribir(List<Item> items) async {
    final seleccion = items.take(_cantidad).toList();
    debugPrint('[WidgetTitularesWriter] escribiendo ${seleccion.length} titulares');
    // Rellenamos siempre los 10 slots para que al vaciar el feed se limpie.
    for (var i = 0; i < _cantidad; i++) {
      final clave = i + 1;
      if (i < seleccion.length) {
        final it = seleccion[i];
        await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', it.title);
        await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', it.source?.name ?? '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_id', it.id.toString());
        // Imagen miniatura: la `RemoteViewsFactory` Kotlin descarga la
        // URL una vez por refresco y la decodifica en bitmap pequeño
        // antes de pasarla por IPC al systemui (los RemoteViews tienen
        // tope de tamaño total, ~1MB en API 30+).
        await HomeWidget.saveWidgetData<String>('titular_${clave}_imagen', it.mediaUrl);
      } else {
        await HomeWidget.saveWidgetData<String>('titular_${clave}_titulo', '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_fuente', '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_id', '');
        await HomeWidget.saveWidgetData<String>('titular_${clave}_imagen', '');
      }
    }
    // Pide al sistema que redibuje el widget.
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
    debugPrint('[WidgetTitularesWriter] updateWidget disparado');
  }
}
