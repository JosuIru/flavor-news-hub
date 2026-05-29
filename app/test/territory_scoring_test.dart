import 'package:flavor_news_hub/core/models/item.dart';
import 'package:flavor_news_hub/core/models/source_summary.dart';
import 'package:flavor_news_hub/core/utils/territory_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests del scoring local-primero que ordena el feed: la pieza que decide
/// qué titulares ve antes el usuario. Lógica pura, alto valor, sin tests
/// hasta ahora. Cubre el factor de envejecimiento territorial, el boost de
/// movimientos y la diversificación anti-monopolio por fuente.
void main() {
  // Punto temporal fijo para que el envejecimiento sea determinista.
  final ahora = DateTime.utc(2026, 1, 10, 12);
  Duration dias(num n) => Duration(microseconds: (Duration(days: 1).inMicroseconds * n).round());

  group('prioridadLocal', () {
    int prioridad({
      String country = '',
      String region = '',
      String city = '',
      String network = '',
      required String base,
    }) =>
        prioridadLocal(
          country: country,
          region: region,
          city: city,
          network: network,
          territorioBase: base,
        );

    test('sin territorio base, prioridad 0', () {
      expect(prioridad(country: 'España', base: ''), 0);
    });

    test('match de ciudad da la prioridad máxima (4)', () {
      expect(prioridad(country: 'Argentina', city: 'Buenos Aires', base: 'Buenos Aires'), 4);
    });

    test('match de región da 3', () {
      expect(prioridad(country: 'España', region: 'Bizkaia', base: 'Bizkaia'), 3);
    });

    test('match de país da 2', () {
      // OJO: usamos 'spain' a propósito. La clave 'españa' del mapa lleva ñ,
      // pero el lookup normaliza la ñ a 'n' ('espana'), así que esa entrada
      // es inalcanzable y 'España' como base NO resuelve a país (bug latente
      // en TerritoryNormalizer). 'spain' sí casa.
      expect(prioridad(country: 'España', region: 'Madrid', base: 'spain'), 2);
    });

    test('base "España" con ñ no resuelve hoy (bug documentado)', () {
      // Captura el comportamiento actual para que un futuro arreglo del
      // normalizador haga fallar este test y obligue a actualizarlo.
      expect(prioridad(country: 'España', base: 'España'), 0);
    });

    test('match de red transnacional da 1', () {
      expect(prioridad(network: 'Internacional', base: 'Internacional'), 1);
    });

    test('sin coincidencia, 0', () {
      expect(prioridad(country: 'Francia', base: 'España'), 0);
    });

    test('lo más específico gana: ciudad por encima de país', () {
      // Base "Buenos Aires" desglosa a país Argentina + ciudad Buenos Aires.
      // Un medio de la propia ciudad puntúa 4, no 2.
      expect(prioridad(country: 'Argentina', city: 'Buenos Aires', base: 'Buenos Aires'), 4);
      // Otro medio argentino de distinta ciudad cae a país (2).
      expect(prioridad(country: 'Argentina', city: 'Mendoza', base: 'Buenos Aires'), 2);
    });
  });

  group('fechaEfectivaLocal', () {
    DateTime efectiva({
      required DateTime publishedAt,
      String country = '',
      String region = '',
      String city = '',
      String network = '',
      String base = '',
      bool esMovimiento = false,
    }) =>
        fechaEfectivaLocal(
          publishedAt: publishedAt,
          country: country,
          region: region,
          city: city,
          network: network,
          territorioBase: base,
          esMovimiento: esMovimiento,
          ahora: ahora,
        );

    test('sin territorio ni movimiento, devuelve la fecha original', () {
      final publicado = ahora.subtract(dias(10));
      expect(efectiva(publishedAt: publicado, country: 'España'), publicado);
    });

    test('sin coincidencia territorial (factor 1.0), fecha intacta', () {
      final publicado = ahora.subtract(dias(10));
      expect(efectiva(publishedAt: publicado, country: 'Francia', base: 'España'), publicado);
    });

    test('match de región (0.5): el item envejece la mitad', () {
      final publicado = ahora.subtract(dias(10));
      // Edad real 10 días → ajustada 5 → la fecha efectiva sube 5 días.
      expect(
        efectiva(publishedAt: publicado, country: 'España', region: 'Bizkaia', base: 'Bizkaia'),
        ahora.subtract(dias(5)),
      );
    });

    test('boost de movimiento (0.85) aun sin territorio base', () {
      final publicado = ahora.subtract(dias(10));
      expect(
        efectiva(publishedAt: publicado, esMovimiento: true),
        ahora.subtract(dias(8.5)),
      );
    });

    test('territorio y movimiento se componen (0.5 * 0.85)', () {
      final publicado = ahora.subtract(dias(10));
      expect(
        efectiva(
          publishedAt: publicado,
          country: 'España',
          region: 'Bizkaia',
          base: 'Bizkaia',
          esMovimiento: true,
        ),
        ahora.subtract(dias(4.25)),
      );
    });

    test('un item con fecha futura no se altera', () {
      final futuro = ahora.add(dias(2));
      expect(
        efectiva(publishedAt: futuro, country: 'España', region: 'Bizkaia', base: 'Bizkaia'),
        futuro,
      );
    });
  });

  group('ordenarItemsLocalPrimero', () {
    Item item(int id, {required DateTime fecha, SourceSummary? source}) => Item(
          id: id,
          slug: 'item-$id',
          title: 'Titular $id',
          publishedAt: fecha.toIso8601String(),
          source: source,
        );

    SourceSummary medio(int id, {String region = '', String country = '', bool movimiento = false}) =>
        SourceSummary(
          id: id,
          slug: 'medio-$id',
          name: 'Medio $id',
          region: region,
          country: country,
          esMovimiento: movimiento,
        );

    test('un local algo más viejo sube por encima de un global reciente', () {
      final local = item(1, fecha: ahora.subtract(dias(4)), source: medio(1, region: 'Bizkaia'));
      final global = item(2, fecha: ahora.subtract(dias(3)), source: medio(2, country: 'Francia'));
      final lista = [global, local];

      // Local: edad 4d * 0.5 = 2d efectivos. Global: 3d sin ajuste.
      // 2d < 3d → el local queda más "reciente" y va primero.
      ordenarItemsLocalPrimero(lista, 'Bizkaia');

      expect(lista.map((i) => i.id), [1, 2]);
    });

    test('sin territorio base mantiene orden cronológico descendente', () {
      final viejo = item(1, fecha: ahora.subtract(dias(5)), source: medio(1));
      final nuevo = item(2, fecha: ahora.subtract(dias(1)), source: medio(2));
      final lista = [viejo, nuevo];

      ordenarItemsLocalPrimero(lista, '');

      expect(lista.map((i) => i.id), [2, 1]);
    });

    test('diversifica: no deja más de N seguidos de la misma fuente', () {
      final prolifico = medio(99);
      final otro = medio(7);
      // 5 items del mismo medio, recientes, y 2 de otro algo más viejos.
      final lista = [
        item(1, fecha: ahora.subtract(dias(1)), source: prolifico),
        item(2, fecha: ahora.subtract(dias(2)), source: prolifico),
        item(3, fecha: ahora.subtract(dias(3)), source: prolifico),
        item(4, fecha: ahora.subtract(dias(4)), source: otro),
        item(5, fecha: ahora.subtract(dias(5)), source: prolifico),
        item(6, fecha: ahora.subtract(dias(6)), source: otro),
      ];

      ordenarItemsLocalPrimero(lista, '', maxConsecutivosPorFuente: 2);

      // En ninguna ventana de 3 consecutivos deben ser los 3 del mismo medio.
      for (var i = 0; i + 2 < lista.length; i++) {
        final ids = {lista[i].source?.id, lista[i + 1].source?.id, lista[i + 2].source?.id};
        expect(ids.length, greaterThan(1), reason: 'tres seguidos de la misma fuente en $i');
      }
      // No se pierde ni duplica ningún item.
      expect(lista.map((i) => i.id).toSet(), {1, 2, 3, 4, 5, 6});
    });
  });
}
