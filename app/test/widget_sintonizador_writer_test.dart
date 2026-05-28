import 'dart:convert';

import 'package:flavor_news_hub/core/models/radio.dart' as modelo_radio;
import 'package:flavor_news_hub/features/widgets/widget_sintonizador_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Contrato de `WidgetSintonizadorWriter` → `SintonizadorWidgetProvider.kt`.
/// El writer serializa la lista de radios a JSON (id/name/territory/stream_url)
/// que el Kotlin parsea para navegar con ◄/► sin volver a llamar a Flutter.
/// Verifica la forma del JSON y el tope de 40 radios.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  modelo_radio.Radio radio(int id) {
    return modelo_radio.Radio(
      id: id,
      slug: 'radio-$id',
      name: 'Radio $id',
      territory: 'Territorio $id',
      streamUrl: 'https://stream/$id.mp3',
    );
  }

  List<dynamic> radiosCodificadas() {
    return jsonDecode(almacen.datos['sintonizador_radios'] as String) as List;
  }

  group('WidgetSintonizadorWriter', () {
    test('serializa cada radio con id, name, territory y stream_url', () async {
      await WidgetSintonizadorWriter.escribir([radio(1)]);

      final lista = radiosCodificadas();
      expect(lista, hasLength(1));
      expect(lista.first, {
        'id': 1,
        'name': 'Radio 1',
        'territory': 'Territorio 1',
        'stream_url': 'https://stream/1.mp3',
      });
      expect(almacen.redibujados, ['SintonizadorWidgetProvider']);
    });

    test('respeta el tope de 40 radios', () async {
      final muchas = List.generate(60, (i) => radio(i + 1));

      await WidgetSintonizadorWriter.escribir(muchas);

      final lista = radiosCodificadas();
      expect(lista, hasLength(40));
      expect((lista.last as Map)['id'], 40);
    });

    test('lista vacía produce un array JSON vacío', () async {
      await WidgetSintonizadorWriter.escribir([]);

      expect(radiosCodificadas(), isEmpty);
    });
  });
}
