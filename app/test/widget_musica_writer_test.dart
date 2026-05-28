import 'package:flavor_news_hub/core/models/item.dart';
import 'package:flavor_news_hub/core/models/source_summary.dart';
import 'package:flavor_news_hub/features/audio/data/reproductor_episodio_notifier.dart';
import 'package:flavor_news_hub/features/widgets/widget_musica_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/almacen_widget_falso.dart';

/// Contrato de `WidgetMusicaWriter` → `ReproductorMusicaWidgetProvider.kt`.
/// Comprueba el mapeo de estado, el volcado de título/artista/portada y la
/// regla de la posición en cola (solo visible con más de un track).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlmacenWidgetFalso almacen;
  setUp(() => almacen = AlmacenWidgetFalso()..instalar());
  tearDown(() => almacen.desinstalar());

  Item episodio(int id, {String artista = 'Artista', String portada = ''}) {
    return Item(
      id: id,
      slug: 'ep-$id',
      title: 'Episodio $id',
      mediaUrl: portada,
      source: SourceSummary(id: id, slug: 'src-$id', name: artista),
    );
  }

  group('WidgetMusicaWriter', () {
    test('vuelca título, artista, portada y estado', () async {
      await WidgetMusicaWriter.escribir(
        EstadoReproductorEpisodio(
          estado: EstadoEpisodio.reproduciendo,
          episodioActual: episodio(1, artista: 'Chico Sonido', portada: 'https://p/1.jpg'),
        ),
      );

      expect(almacen.datos['musica_titulo'], 'Episodio 1');
      expect(almacen.datos['musica_artista'], 'Chico Sonido');
      expect(almacen.datos['musica_portada'], 'https://p/1.jpg');
      expect(almacen.datos['musica_estado'], 'reproduciendo');
      expect(almacen.redibujados, ['ReproductorMusicaWidgetProvider']);
    });

    test('cada EstadoEpisodio se mapea a su código', () async {
      const esperados = {
        EstadoEpisodio.reproduciendo: 'reproduciendo',
        EstadoEpisodio.pausado: 'pausado',
        EstadoEpisodio.cargando: 'cargando',
        EstadoEpisodio.error: 'error',
        EstadoEpisodio.detenido: 'detenido',
      };
      for (final entrada in esperados.entries) {
        await WidgetMusicaWriter.escribir(
          EstadoReproductorEpisodio(estado: entrada.key, episodioActual: episodio(1)),
        );
        expect(almacen.datos['musica_estado'], entrada.value);
      }
    });

    test('posición de cola vacía con un solo track', () async {
      await WidgetMusicaWriter.escribir(
        EstadoReproductorEpisodio(
          estado: EstadoEpisodio.reproduciendo,
          episodioActual: episodio(1),
          cola: [episodio(1)],
        ),
      );

      expect(almacen.datos['musica_posicion_cola'], '');
    });

    test('posición de cola con varios tracks: indice+1/total', () async {
      await WidgetMusicaWriter.escribir(
        EstadoReproductorEpisodio(
          estado: EstadoEpisodio.reproduciendo,
          episodioActual: episodio(2),
          cola: [episodio(1), episodio(2), episodio(3)],
          indiceEnCola: 1,
        ),
      );

      expect(almacen.datos['musica_posicion_cola'], '2/3');
    });

    test('detenido sin episodio: campos vacíos', () async {
      await WidgetMusicaWriter.escribir(EstadoReproductorEpisodio.detenido);

      expect(almacen.datos['musica_titulo'], '');
      expect(almacen.datos['musica_artista'], '');
      expect(almacen.datos['musica_estado'], 'detenido');
    });
  });
}
