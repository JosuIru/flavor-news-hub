import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/data/reproductor_episodio_notifier.dart';
import '../../radios/data/reproductor_radio_notifier.dart';

/// Shell con NavigationBar inferior que envuelve las 4 destinaciones
/// principales: Feed, Radios (streaming en vivo), Directorio de colectivos
/// y Ajustes.
///
/// Las pantallas de detalle (item, source, collective, radio-detalle) viven
/// fuera del shell, a pantalla completa y con back button, porque son
/// contextos concretos de una acción, no pestañas persistentes.
///
/// Cuando hay audio en marcha (radio o música), por encima de la NavigationBar
/// aparece un mini-player persistente con pausa/stop — es el único control
/// garantizado si el usuario cerró el sheet del reproductor o la
/// notificación del sistema no está visible.
class ShellScreen extends ConsumerWidget {
  const ShellScreen({required this.child, required this.rutaActual, super.key});

  final Widget child;
  final String rutaActual;

  static const List<String> _rutasPorIndice = ['/', '/audio', '/tv', '/collectives', '/settings'];

  int _indiceDesdeRuta(String ruta) {
    if (ruta.startsWith('/settings')) return 4;
    if (ruta.startsWith('/collectives')) return 3;
    if (ruta.startsWith('/tv')) return 2;
    // `/radios` se queda como alias histórico de `/audio` para no romper
    // los deep-links que ya existieran; el shell los trata igual.
    if (ruta.startsWith('/audio') || ruta.startsWith('/radios')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final indice = _indiceDesdeRuta(rutaActual);

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniReproductor(textos: textos),
          NavigationBar(
            selectedIndex: indice,
            onDestinationSelected: (nuevoIndice) {
              final nuevaRuta = _rutasPorIndice[nuevoIndice];
              if (GoRouterState.of(context).uri.toString() != nuevaRuta) {
                context.go(nuevaRuta);
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.article_outlined),
                selectedIcon: const Icon(Icons.article),
                label: textos.tabFeed,
              ),
              NavigationDestination(
                icon: const Icon(Icons.headphones_outlined),
                selectedIcon: const Icon(Icons.headphones),
                label: textos.tabAudio,
              ),
              NavigationDestination(
                icon: const Icon(Icons.tv_outlined),
                selectedIcon: const Icon(Icons.tv),
                label: textos.tabTv,
              ),
              NavigationDestination(
                icon: const Icon(Icons.groups_outlined),
                selectedIcon: const Icon(Icons.groups),
                label: textos.tabDirectory,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: textos.tabSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barrita pegada encima de la NavigationBar que muestra la pista actual
/// y controles mínimos (pausa/reanudar + stop). Se pinta sólo cuando
/// hay algo sonando o cargando; si todo está parado no ocupa espacio.
class _MiniReproductor extends ConsumerWidget {
  const _MiniReproductor({required this.textos});

  final AppLocalizations textos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadoEpisodio = ref.watch(reproductorEpisodioProvider);
    final estadoRadio = ref.watch(reproductorRadioProvider);

    final episodioActivo = estadoEpisodio.episodioActual != null &&
        (estadoEpisodio.estado == EstadoEpisodio.reproduciendo ||
            estadoEpisodio.estado == EstadoEpisodio.pausado ||
            estadoEpisodio.estado == EstadoEpisodio.cargando);
    final radioActiva = estadoRadio.radioActual != null &&
        (estadoRadio.estado == EstadoPlayback.reproduciendo ||
            estadoRadio.estado == EstadoPlayback.cargando);

    if (!episodioActivo && !radioActiva) {
      return const SizedBox.shrink();
    }

    final esquema = Theme.of(context).colorScheme;

    if (episodioActivo) {
      final episodio = estadoEpisodio.episodioActual!;
      final cargando = estadoEpisodio.estado == EstadoEpisodio.cargando;
      final reproduciendo = estadoEpisodio.estado == EstadoEpisodio.reproduciendo;
      return _Barra(
        color: esquema.surfaceContainerHigh,
        icono: Icons.music_note,
        titulo: episodio.title,
        subtitulo: episodio.source?.name,
        cargando: cargando,
        reproduciendo: reproduciendo,
        onPlayPause: () {
          final notifier = ref.read(reproductorEpisodioProvider.notifier);
          if (reproduciendo) {
            notifier.pausar();
          } else {
            notifier.reanudar();
          }
        },
        onStop: () => ref.read(reproductorEpisodioProvider.notifier).parar(),
      );
    }

    final radio = estadoRadio.radioActual!;
    final cargando = estadoRadio.estado == EstadoPlayback.cargando;
    return _Barra(
      color: esquema.surfaceContainerHigh,
      icono: Icons.radio,
      titulo: radio.name,
      subtitulo: radio.territory.isEmpty ? null : radio.territory,
      cargando: cargando,
      reproduciendo: estadoRadio.estado == EstadoPlayback.reproduciendo,
      onPlayPause: () => ref.read(reproductorRadioProvider.notifier).parar(),
      onStop: () => ref.read(reproductorRadioProvider.notifier).parar(),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.color,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.cargando,
    required this.reproduciendo,
    required this.onPlayPause,
    required this.onStop,
  });

  final Color color;
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final bool cargando;
  final bool reproduciendo;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: color,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icono, color: esquema.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Text(
                        subtitulo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: esquema.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              if (cargando)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: onPlayPause,
                  icon: Icon(reproduciendo ? Icons.pause : Icons.play_arrow),
                ),
              IconButton(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
