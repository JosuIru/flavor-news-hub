import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_provider.dart';
import '../../movimientos/data/movimientos_provider.dart';
import '../data/colectivos_directorio_notifier.dart';
import '../data/filtros_colectivos.dart';
import 'collective_card.dart';

/// Pestaña "Colectivos" del shell. Tiene dos subsecciones:
///  1. Noticias — items de fuentes marcadas como "voz de movimiento" y
///     colectivos. Antes esta sección sólo era accesible desde Ajustes
///     y la mayoría de usuarios no la descubría.
///  2. Directorio — listado filtrable de colectivos verificados (lo
///     que ocupaba toda esta pantalla antes).
///
/// El `DefaultTabController` mantiene la sub-pestaña activa mientras
/// el usuario navega dentro del shell; al salir y volver a la tab
/// Colectivos resetea a la primera (Noticias).
class CollectiveDirectoryScreen extends StatelessWidget {
  const CollectiveDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(textos.directoryTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: textos.searchTooltip,
              onPressed: () => context.push('/search'),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: textos.colectivosTabNoticias),
              Tab(text: textos.colectivosTabDirectorio),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TabNoticiasMovimientos(),
            _TabDirectorioColectivos(),
          ],
        ),
      ),
    );
  }
}

/// Subpestaña "Noticias": items de fuentes marcadas como movimiento.
/// Replica la pantalla `/movimientos` pero sin AppBar propio (vive
/// dentro del Scaffold del Shell). Pull-to-refresh respeta el provider
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
/// pull-to-refresh, bottom sheet con filtros.
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
    final filtros = ref.watch(filtrosColectivosProvider);

    return Stack(
      children: [
        RefreshIndicator(
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
        ),
        // FAB pequeño bottom-right para abrir filtros: aparece sólo en
        // esta tab, no contamina el AppBar global del Shell.
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'fab-filtros-colectivos',
            tooltip: AppLocalizations.of(context).filtersTitle,
            onPressed: () => _abrirFiltros(context),
            child: Badge(
              isLabelVisible: !filtros.estaVacio,
              child: const Icon(Icons.tune),
            ),
          ),
        ),
      ],
    );
  }

  void _abrirFiltros(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BottomSheetFiltros(),
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

/// Bottom sheet de filtros del directorio. Más compacto que la pantalla
/// de filtros del feed — aquí sólo hay dos ejes útiles (temática, territorio).
class _BottomSheetFiltros extends ConsumerStatefulWidget {
  const _BottomSheetFiltros();

  @override
  ConsumerState<_BottomSheetFiltros> createState() => _EstadoBottomSheetFiltros();
}

class _EstadoBottomSheetFiltros extends ConsumerState<_BottomSheetFiltros> {
  late final TextEditingController _controllerTerritorio;

  @override
  void initState() {
    super.initState();
    final actual = ref.read(filtrosColectivosProvider);
    _controllerTerritorio = TextEditingController(text: actual.codigoTerritorio ?? '');
  }

  @override
  void dispose() {
    _controllerTerritorio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosColectivosProvider);
    final notifier = ref.read(filtrosColectivosProvider.notifier);
    final asyncTopics = ref.watch(topicsProvider);

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
                  if (!filtros.estaVacio)
                    TextButton(
                      onPressed: () {
                        notifier.limpiar();
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
                        selected: filtros.slugsTopics.contains(topic.slug),
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
