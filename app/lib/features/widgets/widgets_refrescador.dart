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
    'VideosWidgetProvider',
    'PodcastsWidgetProvider',
    'ReproductorRadioWidgetProvider',
    'ReproductorMusicaWidgetProvider',
    'FavoritosWidgetProvider',
    'BuscadorWidgetProvider',
    'SintonizadorWidgetProvider',
  ];

  /// Repinta todos los providers en paralelo. Son ocho saltos
  /// independientes por el canal de plataforma y encadenarlos con
  /// `await` dentro de un bucle sumaba sus latencias en el hilo de UI
  /// justo al guardar ajustes, que es cuando se llama. Ninguno depende
  /// del anterior.
  static Future<void> repintarTodos() async {
    await Future.wait(_proveedores.map((nombre) async {
      try {
        await HomeWidget.updateWidget(name: nombre, androidName: nombre);
      } catch (_) {
        // Si un provider concreto no está colocado por el usuario,
        // updateWidget puede fallar — no hace falta romper el lote.
      }
    }));
  }
}
