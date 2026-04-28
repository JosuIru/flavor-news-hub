import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/ingest_trigger.dart';
import '../../../core/widgets/barra_filtros_activos.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';
import 'audio_filters_header.dart';

/// Episodios de podcast (items cuyo source tiene feed_type='podcast').
/// Online pregunta al backend con `source_type=podcast`; offline filtra
/// los items del seed RSS por el mismo marcador. Los filtros de
/// topics+idiomas se leen del provider transversal (compartidos con el
/// resto de pestañas que los toleran).
final _itemsPodcastProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  final transversal = ref.watch(filtrosTransversalesProvider);
  final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);
  try {
    final topicCsv = transversal.topicsParaQueryParam;
    final idiomaCsv =
        idiomasEfectivos.isEmpty ? null : idiomasEfectivos.join(',');
    final pagina = await api.fetchItems(
      page: 1,
      perPage: 50,
      sourceType: 'podcast',
      topic: topicCsv,
      language: idiomaCsv,
    );
    return pagina.items;
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    try {
      final seed = await ref.watch(itemsDesdeSeedProvider.future);
      final items = seed
          .where((i) => i.source?.feedType == 'podcast')
          .toList();
      final topicsActivos = transversal.slugsTopics.toSet();
      final idiomasActivos = idiomasEfectivos.toSet();
      final idiomasPorFuente = <int, Set<String>>{};
      if (idiomasActivos.isNotEmpty) {
        try {
          final fuentes = await ref.watch(sourcesProvider.future);
          for (final fuente in fuentes.items) {
            idiomasPorFuente[fuente.id] =
                fuente.languages.map((e) => e.toLowerCase()).toSet();
          }
        } catch (_) {
          // Si no podemos leer el directorio completo, seguimos con lo
          // que haya en cache sin romper la pantalla.
        }
      }
      return items.where((item) {
        if (topicsActivos.isNotEmpty && item.topics.isNotEmpty) {
          final slugsItem = item.topics.map((t) => t.slug).toSet();
          if (!slugsItem.any(topicsActivos.contains)) {
            return false;
          }
        }
        if (idiomasActivos.isNotEmpty) {
          final sourceId = item.source?.id ?? 0;
          final idiomasItem = idiomasPorFuente[sourceId] ?? const <String>{};
          if (!idiomasItem.any(idiomasActivos.contains)) {
            return false;
          }
        }
        return true;
      }).toList();
    } catch (_) {
      return const [];
    }
  }
});

/// Sub-pestaña "Podcasts" del Audio screen. Lista simple; al tocar
/// abrimos el detalle del item (que tiene reproductor de audio si
/// `audio_url` está presente).
class PodcastsBody extends ConsumerWidget {
  const PodcastsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final transversal = ref.watch(filtrosTransversalesProvider);
    final notifier = ref.read(filtrosTransversalesProvider.notifier);
    final asyncItems = ref.watch(_itemsPodcastProvider);

    return Column(
      children: [
        AudioFiltersHeader(
          title: textos.filtersTitle,
          topicLabel: textos.filterByTopic,
          languageLabel: textos.filterByLanguage,
          clearLabel: textos.filtersClear,
          activeTopicsCount: transversal.slugsTopics.length,
          activeLanguagesCount: transversal.codigosIdiomasOverride.length,
          onOpenFilters: () => mostrarFiltrosPodcasts(context),
          onClearFilters: () {
            notifier.limpiarTopics();
            notifier.limpiarIdiomas();
          },
        ),
        BarraChipsFiltrosActivos(
          slugsTopics: transversal.slugsTopics,
          codigosIdiomas: transversal.codigosIdiomasOverride,
          onQuitarTopic: notifier.alternarTopic,
          onQuitarIdioma: notifier.alternarIdioma,
          onLimpiarTodo: () {
            notifier.limpiarTopics();
            notifier.limpiarIdiomas();
          },
        ),
        Expanded(
          child: asyncItems.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error.toString(), textAlign: TextAlign.center),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        textos.podcastsEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  unawaited(dispararIngestaBackend(ref.read(sharedPreferencesProvider)));
                  ref.invalidate(_itemsPodcastProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return _TilePodcast(item: item);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void mostrarFiltrosPodcasts(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _BottomSheetFiltrosPodcasts(),
  );
}

class _BottomSheetFiltrosPodcasts extends ConsumerWidget {
  const _BottomSheetFiltrosPodcasts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final transversal = ref.watch(filtrosTransversalesProvider);
    final notifier = ref.read(filtrosTransversalesProvider.notifier);
    final hayFiltrosLocales =
        transversal.tieneTopics || transversal.tieneIdiomasOverride;
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
                  if (hayFiltrosLocales)
                    TextButton(
                      onPressed: () {
                        notifier.limpiarTopics();
                        notifier.limpiarIdiomas();
                      },
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
                          selected:
                              transversal.slugsTopics.contains(topic.slug),
                          onSelected: (_) =>
                              notifier.alternarTopic(topic.slug),
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
                      selected: transversal.codigosIdiomasOverride
                          .contains(opcion.codigo),
                      onSelected: (_) =>
                          notifier.alternarIdioma(opcion.codigo),
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

class _OpcionIdiomaPodcast {
  const _OpcionIdiomaPodcast({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}

const List<_OpcionIdiomaPodcast> _opcionesIdioma = [
  _OpcionIdiomaPodcast(codigo: 'es', etiqueta: 'Castellano'),
  _OpcionIdiomaPodcast(codigo: 'ca', etiqueta: 'Català'),
  _OpcionIdiomaPodcast(codigo: 'eu', etiqueta: 'Euskara'),
  _OpcionIdiomaPodcast(codigo: 'gl', etiqueta: 'Galego'),
  _OpcionIdiomaPodcast(codigo: 'en', etiqueta: 'English'),
];

class _TilePodcast extends ConsumerWidget {
  const _TilePodcast({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final guardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
    final utiles = ref.watch(utilesProvider).valueOrNull ?? const <int>{};
    final estaGuardado = guardados.contains(item.id);
    final esUtil = utiles.contains(item.id);
    return ListTile(
      leading: const Icon(Icons.podcasts),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: item.source != null
          ? Text(item.source!.name, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(esUtil ? Icons.lightbulb : Icons.lightbulb_outline),
            tooltip: esUtil ? textos.itemUnmarkUseful : textos.itemMarkUseful,
            onPressed: () => ref.read(utilesProvider.notifier).alternar(item),
          ),
          IconButton(
            icon: Icon(estaGuardado ? Icons.bookmark : Icons.bookmark_border),
            tooltip: estaGuardado ? textos.itemUnsave : textos.itemSave,
            onPressed: () => ref.read(guardadosProvider.notifier).alternar(item),
          ),
        ],
      ),
      onTap: () => GoRouter.of(context).push('/items/${item.id}'),
    );
  }
}
