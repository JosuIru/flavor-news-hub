import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// Shell con NavigationBar inferior que envuelve las 4 destinaciones
/// principales: Feed, Radios (streaming en vivo), Directorio de colectivos
/// y Ajustes.
///
/// Las pantallas de detalle (item, source, collective, radio-detalle) viven
/// fuera del shell, a pantalla completa y con back button, porque son
/// contextos concretos de una acción, no pestañas persistentes.
class ShellScreen extends StatelessWidget {
  const ShellScreen({required this.child, required this.rutaActual, super.key});

  final Widget child;
  final String rutaActual;

  static const List<String> _rutasPorIndice = ['/', '/audio', '/collectives', '/settings'];

  int _indiceDesdeRuta(String ruta) {
    if (ruta.startsWith('/settings')) return 3;
    if (ruta.startsWith('/collectives')) return 2;
    // `/radios` se queda como alias histórico de `/audio` para no romper
    // los deep-links que ya existieran; el shell los trata igual.
    if (ruta.startsWith('/audio') || ruta.startsWith('/radios')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final indice = _indiceDesdeRuta(rutaActual);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
    );
  }
}
