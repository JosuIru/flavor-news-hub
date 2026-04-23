import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/item.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/ingest_trigger.dart';
import '../../audio/presentation/audio_filters_header.dart';
import '../../videos/data/videos_provider.dart';
import '../data/tv_provider.dart';

/// Pestaña "TV" del shell: canales de TV (medios con
/// `medium_type=tv_station`) y sus últimas emisiones publicadas.
/// Patrón de UI calcado de AudioScreen — `DefaultTabController` con dos
/// subtabs dentro de un único Scaffold.
///
/// Nota legal: no embebemos streams en directo aquí. La política del
/// proyecto sólo permite embed de contenido CC; cuando haya streams
/// verificados como CC, entrarán en una tercera subtab "En directo".
class TvScreen extends ConsumerWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosTvProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(textos.tabTv),
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
              onPressed: () => mostrarFiltrosTv(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.tv), text: textos.tvTabMedios),
              Tab(
                icon: const Icon(Icons.fiber_new_outlined),
                text: textos.tvTabUltimas,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MediosTvBody(),
            _UltimasEmisionesBody(),
          ],
        ),
      ),
    );
  }
}

void mostrarFiltrosTv(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _BottomSheetFiltrosTv(),
  );
}

class _BottomSheetFiltrosTv extends ConsumerWidget {
  const _BottomSheetFiltrosTv();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosTvProvider);
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!filtros.estaVacio)
                    TextButton(
                      onPressed: () => ref.read(filtrosTvProvider.notifier).state =
                          FiltrosTv.vacios,
                      child: Text(textos.filtersClear),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                textos.filterByTopic,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              asyncTopics.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  textos.feedError,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (topics) {
                  final topicsUtiles = topics.where((t) => t.count > 0).toList();
                  if (topicsUtiles.isEmpty) {
                    return Text(
                      textos.filterTopicsOffline,
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  }
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final topic in topicsUtiles)
                        FilterChip(
                          label: Text(topic.name),
                          selected: filtros.slugsTopics.contains(topic.slug),
                          onSelected: (_) {
                            final current = ref.read(filtrosTvProvider);
                            ref.read(filtrosTvProvider.notifier).state =
                                current.alternarTopic(topic.slug);
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                textos.filterByLanguage,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final opcion in _opcionesIdioma)
                    FilterChip(
                      label: Text(opcion.etiqueta),
                      selected: filtros.codigosIdiomas.contains(opcion.codigo),
                      onSelected: (_) {
                        final current = ref.read(filtrosTvProvider);
                        ref.read(filtrosTvProvider.notifier).state =
                            current.alternarIdioma(opcion.codigo);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
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

class _OpcionIdiomaTv {
  const _OpcionIdiomaTv({required this.codigo, required this.etiqueta});

  final String codigo;
  final String etiqueta;
}

const List<_OpcionIdiomaTv> _opcionesIdioma = [
  _OpcionIdiomaTv(codigo: 'es', etiqueta: 'Castellano'),
  _OpcionIdiomaTv(codigo: 'ca', etiqueta: 'Català'),
  _OpcionIdiomaTv(codigo: 'eu', etiqueta: 'Euskara'),
  _OpcionIdiomaTv(codigo: 'gl', etiqueta: 'Galego'),
  _OpcionIdiomaTv(codigo: 'en', etiqueta: 'English'),
];

class _MediosTvBody extends ConsumerWidget {
  const _MediosTvBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSources = ref.watch(tvSourcesProvider);
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosTvProvider);

    return Column(
      children: [
        AudioFiltersHeader(
          title: textos.filtersTitle,
          topicLabel: textos.filterByTopic,
          languageLabel: textos.filterByLanguage,
          clearLabel: textos.filtersClear,
          activeTopicsCount: filtros.slugsTopics.length,
          activeLanguagesCount: filtros.codigosIdiomas.length,
          onOpenFilters: () => mostrarFiltrosTv(context),
          onClearFilters: () {
            ref.read(filtrosTvProvider.notifier).state = FiltrosTv.vacios;
          },
        ),
        Expanded(
          child: asyncSources.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _VacioOError(
              mensaje: err.toString(),
              onReintentar: () => ref.invalidate(tvSourcesProvider),
            ),
            data: (sources) {
              if (sources.isEmpty) {
                return _VacioOError(mensaje: textos.tvEmptyMedios);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  unawaited(dispararIngestaBackend(ref.read(sharedPreferencesProvider)));
                  ref.invalidate(tvSourcesProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _TileTv(source: sources[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de un canal: tap "enciende el canal" (modo TV 24h —
/// arranca el reproductor con el vídeo más reciente y va pasando
/// al siguiente automáticamente gracias al autoplay de
/// ReproductorVideoScreen filtrado por el source). El botón info
/// del trailing abre la ficha editorial del canal para quien quiera
/// ver datos del medio sin ponerse a mirarlo.
class _TileTv extends ConsumerWidget {
  const _TileTv({required this.source});
  final Source source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final subtitulo = [
      if (source.territory.isNotEmpty) source.territory,
      if (source.languages.isNotEmpty) source.languages.join(', '),
    ].join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: esquema.secondaryContainer,
        child: const Icon(Icons.tv),
      ),
      title: Text(source.name),
      subtitle: subtitulo.isEmpty ? null : Text(subtitulo),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: 'Ficha del canal',
        onPressed: () => context.push('/sources/${source.id}'),
      ),
      onTap: () => _encenderCanal(context, ref),
    );
  }

  Future<void> _encenderCanal(BuildContext context, WidgetRef ref) async {
    // Setear el filtro antes de navegar es esencial: el reproductor
    // al terminar un vídeo lee `videosProvider`, que usa estos
    // filtros, y así el "siguiente" es otro vídeo del mismo canal.
    ref.read(filtrosVideosProvider.notifier).state =
        FiltrosVideos.vacios.conSource(source.id);

    final api = ref.read(flavorNewsApiProvider);
    try {
      final pagina = await api.fetchItems(perPage: 1, source: source.id);
      if (!context.mounted) return;
      if (pagina.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Este canal no tiene vídeos disponibles aún.'),
          ),
        );
        return;
      }
      context.push('/videos/play/${pagina.items.first.id}');
    } catch (_) {
      if (!context.mounted) return;
      // Fallback: abrimos la ficha del canal, donde el usuario puede
      // al menos ver el canal e intentar entrar por el botón "Ver
      // vídeos".
      context.push('/sources/${source.id}');
    }
  }
}

class _UltimasEmisionesBody extends ConsumerWidget {
  const _UltimasEmisionesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(tvItemsRecientesProvider);
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosTvProvider);

    return Column(
      children: [
        AudioFiltersHeader(
          title: textos.filtersTitle,
          topicLabel: textos.filterByTopic,
          languageLabel: textos.filterByLanguage,
          clearLabel: textos.filtersClear,
          activeTopicsCount: filtros.slugsTopics.length,
          activeLanguagesCount: filtros.codigosIdiomas.length,
          onOpenFilters: () => mostrarFiltrosTv(context),
          onClearFilters: () {
            ref.read(filtrosTvProvider.notifier).state = FiltrosTv.vacios;
          },
        ),
        Expanded(
          child: asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _VacioOError(
              mensaje: err.toString(),
              onReintentar: () => ref.invalidate(tvItemsRecientesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return _VacioOError(mensaje: textos.tvEmptyUltimas);
              }
              return RefreshIndicator(
                onRefresh: () async {
                  unawaited(dispararIngestaBackend(ref.read(sharedPreferencesProvider)));
                  ref.invalidate(tvItemsRecientesProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _ItemTile(item: items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fechaDt = DateTime.tryParse(item.publishedAt);
    final fecha = fechaDt != null
        ? DateFormat.yMMMd().format(fechaDt.toLocal())
        : '';
    final subtitulo = [
      if (item.source?.name != null && item.source!.name.isNotEmpty)
        item.source!.name,
      if (fecha.isNotEmpty) fecha,
    ].join(' · ');
    return ListTile(
      leading: item.mediaUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: item.mediaUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: esquema.surfaceContainerHighest,
                  child: const Icon(Icons.tv),
                ),
              ),
            )
          : Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.tv),
            ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        // Si el item viene de un canal audiovisual, abrimos el
        // reproductor in-app directamente en vez del detalle de
        // item — que para vídeos suele abrir el enlace externo.
        final feedType = item.source?.feedType ?? '';
        const tiposVideo = {'youtube', 'video', 'peertube'};
        if (tiposVideo.contains(feedType)) {
          context.push('/videos/play/${item.id}');
        } else {
          context.push('/items/${item.id}');
        }
      },
    );
  }
}

class _VacioOError extends StatelessWidget {
  const _VacioOError({required this.mensaje, this.onReintentar});
  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (onReintentar != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh),
                label: Text(textos.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
