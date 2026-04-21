import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_provider.dart';
import '../data/colectivos_directorio_notifier.dart';
import '../data/filtros_colectivos.dart';
import 'collective_card.dart';

/// Directorio filtrable de colectivos verificados.
/// Mismo patrón que el feed (AsyncNotifier, scroll infinito, pull-to-refresh),
/// más un bottom sheet con los filtros para no consumir una ruta aparte.
class CollectiveDirectoryScreen extends ConsumerStatefulWidget {
  const CollectiveDirectoryScreen({super.key});

  @override
  ConsumerState<CollectiveDirectoryScreen> createState() => _EstadoDirectorio();
}

class _EstadoDirectorio extends ConsumerState<CollectiveDirectoryScreen> {
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
    final textos = AppLocalizations.of(context);
    final asyncEstado = ref.watch(colectivosDirectorioProvider);
    final filtros = ref.watch(filtrosColectivosProvider);

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
              isLabelVisible: !filtros.estaVacio,
              child: const Icon(Icons.tune),
            ),
            tooltip: textos.filtersTitle,
            onPressed: () => _abrirFiltros(context),
          ),
        ],
      ),
      body: RefreshIndicator(
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
      padding: const EdgeInsets.only(top: 4, bottom: 16),
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
