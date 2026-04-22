import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../music/presentation/musica_screen.dart';
import '../../radios/presentation/radios_screen.dart';
import 'podcasts_body.dart';

/// Pestaña "Audio" del shell: agrupa radios libres en directo,
/// podcasts de medios del directorio y búsqueda de música federada.
/// Tres `Tab`s dentro de un solo Scaffold.
class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.radio), text: textos.tabRadios),
              Tab(icon: const Icon(Icons.podcasts), text: textos.tabPodcasts),
              Tab(icon: const Icon(Icons.library_music), text: textos.tabMusic),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RadiosBody(),
            PodcastsBody(),
            MusicaBody(),
          ],
        ),
      ),
    );
  }
}
