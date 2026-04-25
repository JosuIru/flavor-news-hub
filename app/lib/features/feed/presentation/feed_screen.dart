import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../donations/presentation/donaciones_sheet.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/seed_loader.dart';
import '../data/feed_notifier.dart';
import '../data/filtros_feed.dart';
import 'item_card.dart';

/// Feed cronológico paginado con:
///  - pull-to-refresh,
///  - scroll infinito (pide siguiente página al acercarse al final),
///  - acción "Filtros" en la AppBar,
///  - badge sobre el icono cuando hay filtros activos.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
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
      ref.read(feedProvider.notifier).cargarSiguiente();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final asyncEstadoFeed = ref.watch(feedProvider);
    final filtros = ref.watch(filtrosFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.feedTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: textos.donationsTitle,
            onPressed: () => mostrarSheetDonaciones(context),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: textos.videosTitle,
            onPressed: () => context.push('/videos'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: !filtros.estaVacio,
              child: const Icon(Icons.tune),
            ),
            tooltip: textos.filtersTitle,
            onPressed: () => context.push('/filters'),
          ),
        ],
      ),
      body: Column(
        children: [
          const _BarraFiltrosActivos(),
          Expanded(
            child: RefreshIndicator(
        onRefresh: () => ref.read(feedProvider.notifier).refrescar(),
        child: asyncEstadoFeed.when(
          // Durante pull-to-refresh o `invalidateSelf`, mantenemos la
          // lista previa visible en vez de parpadear al estado de carga.
          // Sólo mostramos la pantalla de carga la primera vez.
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => _PantallaCarga(mensaje: textos.feedLoading),
          error: (error, stackTrace) => _PantallaError(
            mensajeError: error.toString(),
            onReintentar: () => ref.read(feedProvider.notifier).refrescar(),
            textos: textos,
          ),
          data: (estado) {
            if (estado.estaVacio) {
              // Si hay filtros activos es mucho más probable que el
              // vacío venga de filtros que dejan fuera todo, que no de
              // "no hay contenido": ofrecemos botón directo para
              // limpiarlos en vez de dejar al usuario atrapado.
              if (!filtros.estaVacio) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_off,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          textos.feedEmptyWithFilters,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.refresh),
                          label: Text(textos.filtersClear),
                          onPressed: () {
                            ref.read(filtrosFeedProvider.notifier).limpiar();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }
              return _PantallaVacia(mensaje: textos.feedEmpty);
            }
            final guardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
            final utiles = ref.watch(utilesProvider).valueOrNull ?? const <int>{};
            final leidos = ref.watch(leidosProvider).valueOrNull ?? const <int>{};
            final indiceBase = estado.modoOffline ? 1 : 0; // +1 si hay banner offline
            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: estado.items.length + 1 + indiceBase,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, indice) {
                if (estado.modoOffline && indice == 0) {
                  return _AvisoOffline(textos: textos);
                }
                final indiceItem = indice - indiceBase;
                if (indiceItem == estado.items.length) {
                  return _PiePaginado(
                    cargando: estado.cargandoMasPaginas,
                    hayMas: estado.hayMasPaginas,
                    errorAlPaginar: estado.errorAlPaginar,
                    onReintentar: () => ref.read(feedProvider.notifier).cargarSiguiente(),
                  );
                }
                final item = estado.items[indiceItem];
                return ItemCard(
                  item: item,
                  estaGuardado: guardados.contains(item.id),
                  esUtil: utiles.contains(item.id),
                  estaLeido: leidos.contains(item.id),
                  onTap: () => context.push('/items/${item.id}'),
                  onSourceTap: (idSource) => context.push('/sources/$idSource'),
                  onTopicTap: (slug) async {
                    await ref.read(filtrosFeedProvider.notifier).alternarTopic(slug);
                  },
                  onGuardarAlternar: () =>
                      ref.read(guardadosProvider.notifier).alternar(item),
                  onUtilAlternar: () =>
                      ref.read(utilesProvider.notifier).alternar(item),
                );
              },
            );
          },
        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra horizontal de chips dismissables visible debajo del AppBar
/// cuando hay filtros activos. Sin filtros, ocupa altura cero.
///
/// Antes el usuario podía pulsar "Ver noticias de este medio" en la
/// ficha de una source y volver al feed sin pista visual de que
/// estaba filtrando — sólo el badge naranja en el icono "tune" del
/// AppBar lo delataba, y mucha gente lo pasaba por alto. Esta barra
/// hace explícito qué filtros están activos y permite quitarlos uno
/// por uno con un toque sin abrir la pantalla de filtros.
class _BarraFiltrosActivos extends ConsumerWidget {
  const _BarraFiltrosActivos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(filtrosFeedProvider);
    if (filtros.estaVacio) return const SizedBox.shrink();

    final textos = AppLocalizations.of(context);
    final notifier = ref.read(filtrosFeedProvider.notifier);
    final esquema = Theme.of(context).colorScheme;

    final chips = <Widget>[];

    if (filtros.idSource != null) {
      // Resolvemos el nombre del medio desde el seed bundleado. Si no
      // está en seed (caso raro: medio recién añadido en una instancia
      // y aún no propagado al app), caemos a "Medio #N".
      final fuentes = ref.watch(sourcesSeedProvider).valueOrNull ?? const [];
      String nombre = 'Medio #${filtros.idSource}';
      for (final s in fuentes) {
        if (s.id == filtros.idSource) {
          nombre = s.name;
          break;
        }
      }
      chips.add(InputChip(
        avatar: Icon(Icons.podcasts, size: 18, color: esquema.primary),
        label: Text(nombre),
        onDeleted: () => notifier.establecerSource(null),
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    for (final slug in filtros.slugsTopics) {
      // Capitalizamos el slug para presentación; el `name` real del
      // topic vendría de cargar el provider de topics, pero el slug
      // capitalizado da una representación suficientemente clara y
      // evita una segunda dependencia asíncrona.
      final etiqueta = slug.isEmpty
          ? slug
          : '${slug[0].toUpperCase()}${slug.substring(1).replaceAll('-', ' ')}';
      chips.add(InputChip(
        label: Text(etiqueta),
        onDeleted: () => notifier.alternarTopic(slug),
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    final territorio = filtros.codigoTerritorio;
    if (territorio != null && territorio.isNotEmpty) {
      chips.add(InputChip(
        avatar: Icon(Icons.place_outlined, size: 18, color: esquema.primary),
        label: Text(territorio),
        onDeleted: () => notifier.establecerTerritorio(null),
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    if (filtros.codigosIdiomas.isNotEmpty) {
      chips.add(InputChip(
        avatar: Icon(Icons.language, size: 18, color: esquema.primary),
        label: Text(filtros.codigosIdiomas.map((c) => c.toUpperCase()).join(', ')),
        onDeleted: notifier.limpiarIdiomas,
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    return Material(
      color: esquema.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < chips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        chips[i],
                      ],
                    ],
                  ),
                ),
              ),
              if (chips.length > 1)
                TextButton(
                  onPressed: notifier.limpiar,
                  child: Text(textos.filtersClear),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Center(child: Text(mensaje)),
      ],
    );
  }
}

class _PantallaVacia extends StatelessWidget {
  const _PantallaVacia({required this.mensaje});
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _PantallaError extends StatelessWidget {
  const _PantallaError({
    required this.mensajeError,
    required this.onReintentar,
    required this.textos,
  });

  final String mensajeError;
  final VoidCallback onReintentar;
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                textos.feedError,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                mensajeError,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
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

class _AvisoOffline extends StatelessWidget {
  const _AvisoOffline({required this.textos});
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      color: esquema.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: esquema.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textos.feedOfflineBanner,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PiePaginado extends StatelessWidget {
  const _PiePaginado({
    required this.cargando,
    required this.hayMas,
    required this.errorAlPaginar,
    required this.onReintentar,
  });

  final bool cargando;
  final bool hayMas;
  final String? errorAlPaginar;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (errorAlPaginar != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          children: [
            Text(errorAlPaginar!, textAlign: TextAlign.center),
            TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (!hayMas) {
      return const SizedBox(height: 32);
    }
    return const SizedBox(height: 24);
  }
}
