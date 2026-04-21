import 'package:home_widget/home_widget.dart';

import '../audio/data/reproductor_episodio_notifier.dart';

/// Actualiza el widget Android de "Reproductor música" con el estado del
/// `reproductorEpisodioProvider`. El widget pinta título, artista, portada
/// y el icono según el estado.
///
/// Importante: este writer también vale para pódcasts — la pantalla de
/// música y la lista de programas de radio comparten el mismo notifier,
/// así que el widget refleja lo último que sonó independientemente del
/// origen.
class WidgetMusicaWriter {
  static const String _nombreProvider = 'ReproductorMusicaWidgetProvider';

  static Future<void> escribir(EstadoReproductorEpisodio estado) async {
    final episodio = estado.episodioActual;
    final titulo = episodio?.title ?? '';
    final artista = episodio?.source?.name ?? '';
    final portada = episodio?.mediaUrl ?? '';
    final codigoEstado = switch (estado.estado) {
      EstadoEpisodio.reproduciendo => 'reproduciendo',
      EstadoEpisodio.pausado => 'pausado',
      EstadoEpisodio.cargando => 'cargando',
      EstadoEpisodio.error => 'error',
      EstadoEpisodio.detenido => 'detenido',
    };
    final posicionCola = estado.cola.length > 1
        ? '${estado.indiceEnCola + 1}/${estado.cola.length}'
        : '';
    await HomeWidget.saveWidgetData<String>('musica_titulo', titulo);
    await HomeWidget.saveWidgetData<String>('musica_artista', artista);
    await HomeWidget.saveWidgetData<String>('musica_portada', portada);
    await HomeWidget.saveWidgetData<String>('musica_estado', codigoEstado);
    await HomeWidget.saveWidgetData<String>('musica_posicion_cola', posicionCola);
    await HomeWidget.updateWidget(
      name: _nombreProvider,
      androidName: _nombreProvider,
    );
  }
}
