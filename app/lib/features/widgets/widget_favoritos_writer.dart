import 'package:home_widget/home_widget.dart';

import '../../core/models/radio.dart' as modelo_radio;

/// Empuja al widget Android de favoritos la lista de radios marcadas como
/// tales por el usuario. Muestra como máximo 3 (es el espacio del layout).
class WidgetFavoritosWriter {
  static const String _nombreProvider = 'FavoritosWidgetProvider';
  static const int _cantidadFilas = 3;

  static Future<void> escribir(
    Set<int> idsFavoritas,
    List<modelo_radio.Radio> todasLasRadios,
  ) async {
    // Filtrar y ordenar alfabéticamente — mismo criterio que en la app.
    final favoritas = todasLasRadios
        .where((r) => idsFavoritas.contains(r.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    for (var i = 0; i < _cantidadFilas; i++) {
      final clave = i + 1;
      if (i < favoritas.length) {
        final r = favoritas[i];
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_id', r.id.toString());
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_nombre', r.name);
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_territorio', r.territory);
      } else {
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_id', '');
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_nombre', '');
        await HomeWidget.saveWidgetData<String>('fav_radio_${clave}_territorio', '');
      }
    }
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
  }
}
