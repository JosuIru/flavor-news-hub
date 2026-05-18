import 'package:flutter/material.dart';
import 'package:flavor_news_hub/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/widgets/barra_filtros_activos.dart';
import '../../movimientos/data/movimientos_provider.dart';
import '../data/colectivos_directorio_notifier.dart';
import 'collective_card.dart';

/// Pestaña "Colectivos" del shell con dos subsecciones:
///  1. **Noticias** — items de fuentes marcadas como "voz de
///     movimiento" y colectivos. Aplica los filtros transversales
///     completos (topics + territorio + idiomas), igual que el feed
///     general.
///  2. **Directorio** — listado filtrable de colectivos verificados.
///     Aplica topics + territorio (idioma no aplica: el directorio es
///     content-agnostic).
///
/// El AppBar es común a las dos subsecciones; el botón de filtros y la
/// barra de chips se adaptan a la tab activa para mostrar sólo los
/// ejes relevantes.
class CollectiveDirectoryScreen extends StatelessWidget {
  const CollectiveDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: _CuerpoColectivos(),
    );
  }
}

class _CuerpoColectivos extends ConsumerStatefulWidget {
  const _CuerpoColectivos();

  @override
  ConsumerState<_CuerpoColectivos> createState() => _EstadoCuerpoColectivos();
}

class _EstadoCuerpoColectivos extends ConsumerState<_CuerpoColectivos> {
  // Necesitamos saber qué tab está activa para que el badge del botón
  // de filtros y la barra de chips muestren sólo los ejes relevantes.
  late final TabController _tabController;
  int _indiceTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    _tabController = controller;
    if (!_listenerRegistrado) {
      _tabController.addListener(_alCambiarTab);
      _listenerRegistrado = true;
    }
  }

  bool _listenerRegistrado = false;

  void _alCambiarTab() {
    if (!mounted) return;
    if (_indiceTab != _tabController.index) {
      setState(() => _indiceTab = _tabController.index);
    }
  }

  @override
  void dispose() {
    if (_listenerRegistrado) {
      _tabController.removeListener(_alCambiarTab);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final transversal = ref.watch(filtrosTransversalesProvider);
    final notifier = ref.read(filtrosTransversalesProvider.notifier);
    final esTabNoticias = _indiceTab == 0;
    // Noticias aplica los 3 ejes (topics + territorio + idioma);
    // directorio aplica sólo topics + territorio.
    final hayFiltrosTab = esTabNoticias
        ? !transversal.estaVacio
        : (transversal.tieneTopics || transversal.tieneTerritorio);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.directoryTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: hayFiltrosTab,
              child: const Icon(Icons.tune),
            ),
            tooltip: textos.filtersTitle,
            onPressed: () => _abrirFiltros(context, esTabNoticias),
          ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: textos.colectivosTabNoticias),
            Tab(text: textos.colectivosTabDirectorio),
          ],
        ),
      ),
      body: Column(
        children: [
          BarraChipsFiltrosActivos(
            slugsTopics: transversal.slugsTopics,
            codigoTerritorio: transversal.codigoTerritorio,
            // Idiomas sólo en la tab Noticias — en Directorio no
            // aplican y mostrarlos sería confuso ("¿por qué hay un chip
            // que no afecta a esta lista?").
            codigosIdiomas: esTabNoticias
                ? transversal.codigosIdiomasOverride
                : const [],
            onQuitarTopic: notifier.alternarTopic,
            onQuitarIdioma: esTabNoticias ? notifier.alternarIdioma : null,
            onQuitarTerritorio: () => notifier.establecerTerritorio(null),
            onLimpiarTodo: () {
              notifier.limpiarTopics();
              notifier.establecerTerritorio(null);
              if (esTabNoticias) notifier.limpiarIdiomas();
            },
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _TabNoticiasMovimientos(),
                _TabDirectorioColectivos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFiltros(BuildContext context, bool incluirIdiomas) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BottomSheetFiltrosColectivos(
        incluirIdiomas: incluirIdiomas,
      ),
    );
  }
}

/// Subpestaña "Noticias": items de fuentes marcadas como movimiento.
/// Replica la pantalla `/movimientos` pero sin AppBar propio (vive
/// dentro del Scaffold compartido). Pull-to-refresh respeta el provider
/// del feed de movimientos.
class _TabNoticiasMovimientos extends ConsumerWidget {
  const _TabNoticiasMovimientos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncItems = ref.watch(feedMovimientosProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(feedMovimientosProvider),
      child: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  Text(e.toString(), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        textos.movimientosEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              if (indice == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    textos.movimientosSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                );
              }
              final item = items[indice - 1];
              final fuente = item.source?.name ?? '';
              return ListTile(
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: fuente.isEmpty
                    ? null
                    : Text(fuente, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/items/${item.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

/// Subpestaña "Directorio": listado filtrable de colectivos verificados.
/// Mismo patrón que el feed principal — AsyncNotifier, scroll infinito,
/// pull-to-refresh.
class _TabDirectorioColectivos extends ConsumerStatefulWidget {
  const _TabDirectorioColectivos();

  @override
  ConsumerState<_TabDirectorioColectivos> createState() => _EstadoDirectorio();
}

class _EstadoDirectorio extends ConsumerState<_TabDirectorioColectivos> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_alScrollear);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_alScrollear);
    _scrollController.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(colectivosDirectorioProvider.notifier).cargarSiguiente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncEstado = ref.watch(colectivosDirectorioProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(colectivosDirectorioProvider.notifier).refrescar(),
      child: asyncEstado.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _PantallaErrorDirectorio(
          mensaje: error.toString(),
          onReintentar: () =>
              ref.read(colectivosDirectorioProvider.notifier).refrescar(),
        ),
        data: (estado) => _ContenidoDirectorio(
          estado: estado,
          controller: _scrollController,
        ),
      ),
    );
  }
}

class _ContenidoDirectorio extends ConsumerWidget {
  const _ContenidoDirectorio({required this.estado, required this.controller});

  final EstadoDirectorioColectivos estado;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    if (estado.estaVacio) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  textos.directoryEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(textos.directoryAddCta),
                  onPressed: () => context.push('/collectives/submit'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: estado.items.length + 2, // +1 pie paginado, +1 CTA final
      separatorBuilder: (_, indice) => const Divider(height: 1),
      itemBuilder: (context, indice) {
        if (indice == estado.items.length) {
          return _PiePaginadoDirectorio(
            cargando: estado.cargandoMasPaginas,
            errorAlPaginar: estado.errorAlPaginar,
            onReintentar: () =>
                ref.read(colectivosDirectorioProvider.notifier).cargarSiguiente(),
            hayMas: estado.hayMasPaginas,
          );
        }
        if (indice == estado.items.length + 1) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(textos.directoryAddCta),
              onPressed: () => context.push('/collectives/submit'),
            ),
          );
        }
        final colectivo = estado.items[indice];
        return CollectiveCard(
          colectivo: colectivo,
          onTap: () => context.push('/collectives/${colectivo.id}'),
        );
      },
    );
  }
}

class _PiePaginadoDirectorio extends StatelessWidget {
  const _PiePaginadoDirectorio({
    required this.cargando,
    required this.errorAlPaginar,
    required this.onReintentar,
    required this.hayMas,
  });

  final bool cargando;
  final String? errorAlPaginar;
  final VoidCallback onReintentar;
  final bool hayMas;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (errorAlPaginar != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(
          children: [
            Text(errorAlPaginar!, textAlign: TextAlign.center),
            TextButton(onPressed: onReintentar, child: Text(textos.commonRetry)),
          ],
        ),
      );
    }
    if (!hayMas) return const SizedBox.shrink();
    return const SizedBox(height: 16);
  }
}

class _PantallaErrorDirectorio extends StatelessWidget {
  const _PantallaErrorDirectorio({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(mensaje, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: Text(textos.commonRetry),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet de filtros de Colectivos. `incluirIdiomas=true` cuando
/// se abre desde la tab Noticias (los items sí tienen idioma); `false`
/// desde la tab Directorio (los colectivos son content-agnostic).
class _BottomSheetFiltrosColectivos extends ConsumerStatefulWidget {
  const _BottomSheetFiltrosColectivos({required this.incluirIdiomas});

  final bool incluirIdiomas;

  @override
  ConsumerState<_BottomSheetFiltrosColectivos> createState() =>
      _EstadoBottomSheetFiltrosColectivos();
}

class _EstadoBottomSheetFiltrosColectivos
    extends ConsumerState<_BottomSheetFiltrosColectivos> {
  late final TextEditingController _controllerTerritorio;

  @override
  void initState() {
    super.initState();
    final actual = ref.read(filtrosTransversalesProvider);
    _controllerTerritorio =
        TextEditingController(text: actual.codigoTerritorio ?? '');
  }

  @override
  void dispose() {
    _controllerTerritorio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final transversal = ref.watch(filtrosTransversalesProvider);
    final notifier = ref.read(filtrosTransversalesProvider.notifier);
    final asyncTopics = ref.watch(topicsProvider);
    final hayFiltrosTab = widget.incluirIdiomas
        ? !transversal.estaVacio
        : (transversal.tieneTopics || transversal.tieneTerritorio);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      textos.filtersTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (hayFiltrosTab)
                    TextButton(
                      onPressed: () {
                        notifier.limpiarTopics();
                        notifier.establecerTerritorio(null);
                        if (widget.incluirIdiomas) notifier.limpiarIdiomas();
                        _controllerTerritorio.clear();
                      },
                      child: Text(textos.filtersClear),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                textos.filterByTopic,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              asyncTopics.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: LinearProgressIndicator(),
                ),
                error: (_, __) => Text(textos.feedError),
                data: (topics) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final topic in topics)
                      FilterChip(
                        label: Text(topic.name),
                        selected: transversal.slugsTopics.contains(topic.slug),
                        onSelected: (_) => notifier.alternarTopic(topic.slug),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                textos.filterByTerritory,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controllerTerritorio,
                decoration: const InputDecoration(
                  hintText: 'Bizkaia, Catalunya, Estado…',
                  border: OutlineInputBorder(),
                ),
                onChanged: notifier.establecerTerritorio,
              ),
              if (widget.incluirIdiomas) ...[
                const SizedBox(height: 24),
                Text(
                  textos.filterByLanguage,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final opcion in _opcionesIdioma)
                      FilterChip(
                        label: Text(opcion.etiqueta),
                        selected: transversal.codigosIdiomasOverride
                            .contains(opcion.codigo),
                        onSelected: (_) =>
                            notifier.alternarIdioma(opcion.codigo),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(textos.filtersApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionIdiomaColectivo {
  const _OpcionIdiomaColectivo({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}

const List<_OpcionIdiomaColectivo> _opcionesIdioma = [
  _OpcionIdiomaColectivo(codigo: 'es', etiqueta: 'Castellano'),
  _OpcionIdiomaColectivo(codigo: 'ca', etiqueta: 'Català'),
  _OpcionIdiomaColectivo(codigo: 'eu', etiqueta: 'Euskara'),
  _OpcionIdiomaColectivo(codigo: 'gl', etiqueta: 'Galego'),
  _OpcionIdiomaColectivo(codigo: 'en', etiqueta: 'English'),
];
