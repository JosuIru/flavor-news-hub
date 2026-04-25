import 'package:home_widget/home_widget.dart';

/// Fuerza un repintado de todos los AppWidgetProviders Android. Útil
/// cuando cambia algo que el widget renderiza desde Kotlin (textos
/// localizados, política de filtros, tema) y no hay un evento natural
/// que dispare un `updateAppWidget`.
///
/// El package `home_widget` permite invocar el provider por nombre.
/// Todos los providers de la app están aquí — si añades uno nuevo,
/// recuérdate de incluirlo.
class WidgetsRefrescador {
  static const List<String> _proveedores = [
    'TitularesWidgetProvider',
    'ReproductorRadioWidgetProvider',
    'ReproductorMusicaWidgetProvider',
    'FavoritosWidgetProvider',
    'BuscadorWidgetProvider',
    'SintonizadorWidgetProvider',
  ];

  static Future<void> repintarTodos() async {
    for (final nombre in _proveedores) {
      try {
        await HomeWidget.updateWidget(name: nombre, androidName: nombre);
      } catch (_) {
        // Si un provider concreto no está colocado por el usuario,
        // updateWidget puede fallar — no hace falta romper el lote.
      }
    }
  }
}
