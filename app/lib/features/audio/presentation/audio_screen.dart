import 'package:flutter/material.dart';
import 'package:flavor_news_hub/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/idioma_contenido/sheet_politica_idioma_contenido.dart';
import '../../music/presentation/musica_screen.dart';
import '../../radios/presentation/radios_screen.dart';
import 'podcasts_body.dart';

/// Pestaña "Audio" del shell: agrupa radios libres en directo,
/// podcasts de medios del directorio y búsqueda de música federada.
/// Tres `Tab`s dentro de un solo Scaffold.
class AudioScreen extends ConsumerStatefulWidget {
  const AudioScreen({super.key, this.pestanaInicial});

  /// Pestaña con la que abrir la pantalla: `radios`, `podcasts` o
  /// `musica`. Llega por query param desde deep links (la cabecera del
  /// widget de podcasts usa `flavornews://audio?tab=podcasts`). `null`
  /// = comportamiento de siempre, abrir en Radios.
  final String? pestanaInicial;

  /// Índice de la pestaña dentro del `TabBar`. Nombres desconocidos
  /// caen en Radios en vez de romper la navegación.
  static int indiceDePestana(String? nombre) => switch (nombre) {
        'podcasts' => 1,
        'musica' || 'music' => 2,
        _ => 0,
      };

  @override
  ConsumerState<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends ConsumerState<AudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: AudioScreen.indiceDePestana(widget.pestanaInicial),
    );
    // Escuchamos cambios de pestaña para que el AppBar se rebuilde
    // y el botón de filtros se adapte (mostrar/ocultar y enrutar al
    // sheet correcto según el tab activo).
    _tabController.addListener(_alCambiarTab);
  }

  void _alCambiarTab() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AudioScreen anterior) {
    super.didUpdateWidget(anterior);
    // Deep link con la pantalla ya montada (p. ej. tap en la cabecera del
    // widget de podcasts con la app abierta en Audio→Radios): GoRouter
    // reconstruye el widget pero reutiliza este State, así que el
    // `initialIndex` de initState no vuelve a aplicarse. Saltamos aquí a
    // la pestaña pedida. Sólo cuando el parámetro cambia y viene
    // explícito — una reconstrucción normal sin `tab` no debe devolver
    // al usuario a Radios.
    if (widget.pestanaInicial != anterior.pestanaInicial &&
        widget.pestanaInicial != null) {
      _tabController.animateTo(AudioScreen.indiceDePestana(widget.pestanaInicial));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_alCambiarTab);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final transversal = ref.watch(filtrosTransversalesProvider);
    // Para el badge del botón de filtros mostramos el indicador cuando
    // hay topics o idiomas globales activos (los que aplica Podcasts).
    final hayFiltrosPodcasts =
        transversal.tieneTopics || transversal.tieneIdiomasOverride;
    return Scaffold(
      appBar: AppBar(
        title: Text(textos.tabAudio),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
          // Filtros context-aware según pestaña activa:
          //  - Radios (0)   → política central de idioma de contenido
          //    (única dimensión filtrable: idioma; el directorio se
          //     ordena en cliente con favoritas + scoring local).
          //  - Podcasts (1) → bottom sheet de filtros locales
          //    (idioma + topic).
          //  - Música (2)   → sin filtros (Archive.org tiene su propia
          //    UI de búsqueda dentro de la pestaña).
          // Antes el botón saltaba siempre a Podcasts y luego abría su
          // sheet — desde Radios no había manera de llegar al filtro.
          if (_tabController.index != 2)
            IconButton(
              icon: Badge(
                isLabelVisible:
                    _tabController.index == 1 && hayFiltrosPodcasts,
                child: const Icon(Icons.tune),
              ),
              tooltip: textos.filtersTitle,
              onPressed: () {
                if (_tabController.index == 1) {
                  mostrarFiltrosPodcasts(context);
                } else {
                  SheetPoliticaIdiomaContenido.mostrar(context);
                }
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.radio), text: textos.tabRadios),
            Tab(icon: const Icon(Icons.podcasts), text: textos.tabPodcasts),
            Tab(icon: const Icon(Icons.library_music), text: textos.tabMusic),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RadiosBody(),
          PodcastsBody(),
          MusicaBody(),
        ],
      ),
    );
  }
}
