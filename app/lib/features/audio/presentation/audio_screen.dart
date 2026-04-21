import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../music/presentation/musica_screen.dart';
import '../../radios/presentation/radios_screen.dart';

/// Pestaña "Audio" del shell: agrupa la escucha de radios libres en directo
/// y la búsqueda de música federada (Funkwhale). Dos `Tab`s dentro de un
/// solo Scaffold; el icono de búsqueda en la AppBar va siempre al buscador
/// global (que también incluye radios en sus resultados).
class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(textos.tabAudio),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: textos.searchTooltip,
              onPressed: () => context.push('/search'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.radio), text: textos.tabRadios),
              Tab(icon: const Icon(Icons.library_music), text: textos.tabMusic),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RadiosBody(),
            MusicaBody(),
          ],
        ),
      ),
    );
  }
}
