import 'package:flavor_news_hub/core/models/item.dart';
import 'package:flavor_news_hub/core/models/source_summary.dart';
import 'package:flavor_news_hub/features/widgets/widget_titulares_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Tests del contrato de `WidgetTitularesWriter` hacia el almacén nativo.
///
/// El writer es la pieza que alimenta `TitularesWidgetProvider.kt`, justo la
/// zona que ha dado crashes recientes (filtros transversales, modo noche).
/// No podemos pintar el widget Android desde un test de Dart, pero sí
/// blindar el contrato de datos que el Kotlin asume: siempre 10 slots,
/// los sobrantes vaciados, y `source` nulo sin reventar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  Item titular(int id, {String? nombreFuente, String imagen = ''}) {
    return Item(
      id: id,
      slug: 'titular-$id',
      title: 'Titular $id',
      mediaUrl: imagen,
      source: nombreFuente == null
          ? null
          : SourceSummary(id: id, slug: 'fuente-$id', name: nombreFuente),
    );
  }

  group('WidgetTitularesWriter', () {
    test('rellena los slots ocupados con título, fuente, id e imagen', () async {
      await WidgetTitularesWriter.escribir([
        titular(101, nombreFuente: 'La Marea', imagen: 'https://img/1.jpg'),
        titular(102, nombreFuente: 'El Salto', imagen: 'https://img/2.jpg'),
      ]);

      expect(almacen.datos['titular_1_titulo'], 'Titular 101');
      expect(almacen.datos['titular_1_fuente'], 'La Marea');
      expect(almacen.datos['titular_1_id'], '101');
      expect(almacen.datos['titular_1_imagen'], 'https://img/1.jpg');

      expect(almacen.datos['titular_2_titulo'], 'Titular 102');
      expect(almacen.datos['titular_2_fuente'], 'El Salto');
      expect(almacen.datos['titular_2_id'], '102');
    });

    test('siempre escribe los 10 slots y vacía los sobrantes', () async {
      await WidgetTitularesWriter.escribir([
        titular(1, nombreFuente: 'A'),
        titular(2, nombreFuente: 'B'),
      ]);

      // Los 4 campos de cada uno de los 10 slots → 40 claves.
      expect(almacen.datos, hasLength(40));

      // Slots 3..10 vaciados para que al menguar el feed se limpie el widget.
      for (var slot = 3; slot <= 10; slot++) {
        expect(almacen.datos['titular_${slot}_titulo'], '');
        expect(almacen.datos['titular_${slot}_fuente'], '');
        expect(almacen.datos['titular_${slot}_id'], '');
        expect(almacen.datos['titular_${slot}_imagen'], '');
      }
    });

    test('lista vacía limpia los 10 slots por completo', () async {
      await WidgetTitularesWriter.escribir([]);

      for (var slot = 1; slot <= 10; slot++) {
        expect(almacen.datos['titular_${slot}_titulo'], '');
        expect(almacen.datos['titular_${slot}_id'], '');
      }
    });

    test('source nulo no rompe: fuente queda vacía', () async {
      await WidgetTitularesWriter.escribir([titular(7, nombreFuente: null)]);

      expect(almacen.datos['titular_1_titulo'], 'Titular 7');
      expect(almacen.datos['titular_1_fuente'], '');
    });

    test('trunca a 10 aunque lleguen más titulares', () async {
      final muchos = List.generate(25, (i) => titular(i + 1, nombreFuente: 'F$i'));

      await WidgetTitularesWriter.escribir(muchos);

      expect(almacen.datos['titular_10_titulo'], 'Titular 10');
      // No existe un slot 11: el writer solo maneja 10.
      expect(almacen.datos.containsKey('titular_11_titulo'), isFalse);
    });

    test('dispara updateWidget una vez sobre el provider correcto', () async {
      await WidgetTitularesWriter.escribir([titular(1, nombreFuente: 'A')]);

      expect(almacen.redibujados, ['TitularesWidgetProvider']);
    });
  });
}
