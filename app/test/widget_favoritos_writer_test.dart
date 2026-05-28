import 'package:flavor_news_hub/core/models/radio.dart' as modelo_radio;
import 'package:flavor_news_hub/features/widgets/widget_favoritos_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Contrato de `WidgetFavoritosWriter` → `FavoritosWidgetProvider.kt`.
/// El widget tiene 3 filas: el writer filtra por ids favoritas, ordena
/// alfabéticamente (mismo criterio que la app) y vacía las filas sobrantes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  modelo_radio.Radio radio(int id, String nombre, {String territorio = ''}) {
    return modelo_radio.Radio(
      id: id,
      slug: 'radio-$id',
      name: nombre,
      territory: territorio,
    );
  }

  group('WidgetFavoritosWriter', () {
    test('solo escribe las radios favoritas, ordenadas alfabéticamente', () async {
      final todas = [
        radio(1, 'Zeta Radio'),
        radio(2, 'Antena Libre', territorio: 'Bilbo'),
        radio(3, 'No favorita'),
        radio(4, 'Madre Tierra'),
      ];

      await WidgetFavoritosWriter.escribir({1, 2, 4}, todas);

      // Orden alfabético: Antena Libre, Madre Tierra, Zeta Radio.
      expect(almacen.datos['fav_radio_1_nombre'], 'Antena Libre');
      expect(almacen.datos['fav_radio_1_territorio'], 'Bilbo');
      expect(almacen.datos['fav_radio_1_id'], '2');
      expect(almacen.datos['fav_radio_2_nombre'], 'Madre Tierra');
      expect(almacen.datos['fav_radio_3_nombre'], 'Zeta Radio');
      expect(almacen.redibujados, ['FavoritosWidgetProvider']);
    });

    test('rellena las 3 filas y vacía las no usadas', () async {
      await WidgetFavoritosWriter.escribir({1}, [radio(1, 'Única')]);

      expect(almacen.datos['fav_radio_1_nombre'], 'Única');
      for (final fila in [2, 3]) {
        expect(almacen.datos['fav_radio_${fila}_id'], '');
        expect(almacen.datos['fav_radio_${fila}_nombre'], '');
        expect(almacen.datos['fav_radio_${fila}_territorio'], '');
      }
    });

    test('muestra como máximo 3 aunque haya más favoritas', () async {
      final todas = List.generate(5, (i) => radio(i + 1, 'Radio ${i + 1}'));

      await WidgetFavoritosWriter.escribir({1, 2, 3, 4, 5}, todas);

      // 3 filas × 3 campos = 9 claves; no hay fila 4.
      expect(almacen.datos, hasLength(9));
      expect(almacen.datos.containsKey('fav_radio_4_nombre'), isFalse);
    });

    test('sin favoritas vacía las 3 filas', () async {
      await WidgetFavoritosWriter.escribir({}, [radio(1, 'Una')]);

      for (final fila in [1, 2, 3]) {
        expect(almacen.datos['fav_radio_${fila}_nombre'], '');
      }
    });
  });
}
