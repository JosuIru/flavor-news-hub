import 'package:flavor_news_hub/core/models/radio.dart';
import 'package:flavor_news_hub/features/radios/data/reproductor_radio_notifier.dart';
import 'package:flavor_news_hub/features/widgets/widget_radio_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Contrato de `WidgetRadioWriter` → `ReproductorRadioWidgetProvider.kt`.
/// Verifica el mapeo de cada `EstadoPlayback` al código de texto que el
/// Kotlin interpreta, y que sin radio actual el nombre queda vacío.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  final radio = Radio(id: 1, slug: 'cuac', name: 'CUAC FM');

  group('WidgetRadioWriter', () {
    test('estado reproduciendo: nombre y código correctos', () async {
      await WidgetRadioWriter.escribir(
        EstadoReproductor(estado: EstadoPlayback.reproduciendo, radioActual: radio),
      );

      expect(almacen.datos['radio_nombre'], 'CUAC FM');
      expect(almacen.datos['radio_estado'], 'reproduciendo');
      expect(almacen.redibujados, ['ReproductorRadioWidgetProvider']);
    });

    test('cada EstadoPlayback se mapea a su código', () async {
      const esperados = {
        EstadoPlayback.reproduciendo: 'reproduciendo',
        EstadoPlayback.cargando: 'cargando',
        EstadoPlayback.error: 'error',
        EstadoPlayback.detenido: 'detenido',
      };
      for (final entrada in esperados.entries) {
        await WidgetRadioWriter.escribir(
          EstadoReproductor(estado: entrada.key, radioActual: radio),
        );
        expect(almacen.datos['radio_estado'], entrada.value);
      }
    });

    test('sin radio actual el nombre queda vacío', () async {
      await WidgetRadioWriter.escribir(EstadoReproductor.detenido);

      expect(almacen.datos['radio_nombre'], '');
      expect(almacen.datos['radio_estado'], 'detenido');
    });
  });
}
