import 'package:flavor_news_hub/features/widgets/widgets_refrescador.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Tests de `WidgetsRefrescador`, el orquestador que dispara el workmanager
/// para repintar todos los widgets cuando cambia algo global (idioma, tema,
/// política de filtros). Su garantía clave: un provider que el usuario no
/// tiene colocado hace fallar `updateWidget`, y eso NO debe abortar el lote
/// — el resto de widgets se repintan igual.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  const todosLosProveedores = [
    'TitularesWidgetProvider',
    'VideosWidgetProvider',
    'PodcastsWidgetProvider',
    'ReproductorRadioWidgetProvider',
    'ReproductorMusicaWidgetProvider',
    'FavoritosWidgetProvider',
    'BuscadorWidgetProvider',
    'SintonizadorWidgetProvider',
  ];

  group('WidgetsRefrescador', () {
    test('repinta los ocho providers de la app', () async {
      await WidgetsRefrescador.repintarTodos();

      expect(almacen.redibujados, todosLosProveedores);
    });

    test('un provider sin colocar no aborta el lote', () async {
      // Falla justo el primero: los siete restantes deben repintarse igual.
      almacen.proveedoresQueFallan.add('TitularesWidgetProvider');

      await WidgetsRefrescador.repintarTodos();

      expect(almacen.redibujados, [
        'VideosWidgetProvider',
        'PodcastsWidgetProvider',
        'ReproductorRadioWidgetProvider',
        'ReproductorMusicaWidgetProvider',
        'FavoritosWidgetProvider',
        'BuscadorWidgetProvider',
        'SintonizadorWidgetProvider',
      ]);
    });

    test('aunque fallen todos, repintarTodos no propaga la excepción', () async {
      almacen.proveedoresQueFallan.addAll(todosLosProveedores);

      // No debe lanzar.
      await WidgetsRefrescador.repintarTodos();

      expect(almacen.redibujados, isEmpty);
    });
  });
}
