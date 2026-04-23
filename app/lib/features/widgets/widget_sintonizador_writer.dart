import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../../core/models/radio.dart' as modelo_radio;

/// Empuja al widget "Sintonizador" (radio madera) la lista completa de
/// radios disponibles. El widget mantiene internamente su propio índice
/// ('radio actual') en SharedPreferences para navegar con los botones
/// ◄ / ► sin tener que hablar con Flutter.
///
/// Estrategia: escribimos un JSON con {id, name, territory} de cada radio
/// activa. El provider Kotlin lo parsea al re-renderizar. Limitamos a 40
/// para no inflar SharedPreferences (typical widget sólo muestra 1 a la
/// vez, pero el array entero permite ◄/► sin tener que re-llamar).
class WidgetSintonizadorWriter {
  static const String _nombreProvider = 'SintonizadorWidgetProvider';
  static const int _maxRadios = 40;

  static Future<void> escribir(List<modelo_radio.Radio> todasLasRadios) async {
    final visibles = todasLasRadios.take(_maxRadios).map((r) => {
          'id': r.id,
          'name': r.name,
          'territory': r.territory,
        }).toList();
    await HomeWidget.saveWidgetData<String>(
      'sintonizador_radios',
      jsonEncode(visibles),
    );
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
  }
}
