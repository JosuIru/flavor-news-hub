import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../history/data/historial_provider.dart';
import '../../offline_seed/data/items_desde_seed_provider.dart';

/// Episodios de podcast (items cuyo source tiene feed_type='podcast').
/// Online pregunta al backend con `source_type=podcast`; offline filtra
/// los items del seed RSS por el mismo marcador.
final _itemsPodcastProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    final pagina = await api.fetchItems(
      page: 1,
      perPage: 50,
      sourceType: 'podcast',
    );
    return pagina.items;
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    try {
      final seed = await ref.watch(itemsDesdeSeedProvider.future);
      return seed
          .where((i) => i.source?.feedType == 'podcast')
          .toList();
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
    final asyncItems = ref.watch(_itemsPodcastProvider);

    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString(), textAlign: TextAlign.center),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                textos.podcastsEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_itemsPodcastProvider),
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
    );
  }
}

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
