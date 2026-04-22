import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/item.dart';
import '../../../core/models/source.dart';
import '../data/tv_provider.dart';

/// Pestaña "TV" del shell: canales de TV (medios con
/// `medium_type=tv_station`) y sus últimas emisiones publicadas.
/// Patrón de UI calcado de AudioScreen — `DefaultTabController` con dos
/// subtabs dentro de un único Scaffold.
///
/// Nota legal: no embebemos streams en directo aquí. La política del
/// proyecto sólo permite embed de contenido CC; cuando haya streams
/// verificados como CC, entrarán en una tercera subtab "En directo".
class TvScreen extends StatelessWidget {
  const TvScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
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

class _MediosTvBody extends ConsumerWidget {
  const _MediosTvBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSources = ref.watch(tvSourcesProvider);
    final textos = AppLocalizations.of(context);

    return asyncSources.when(
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
          onRefresh: () async => ref.invalidate(tvSourcesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sources.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TileTv(source: sources[i]),
          ),
        );
      },
    );
  }
}

class _TileTv extends StatelessWidget {
  const _TileTv({required this.source});
  final Source source;

  @override
  Widget build(BuildContext context) {
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
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/sources/${source.id}'),
    );
  }
}

class _UltimasEmisionesBody extends ConsumerWidget {
  const _UltimasEmisionesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(tvItemsRecientesProvider);
    final textos = AppLocalizations.of(context);

    return asyncItems.when(
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
          onRefresh: () async => ref.invalidate(tvItemsRecientesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _ItemTile(item: items[i]),
          ),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fecha = DateFormat.yMMMd().format(item.publishedAt.toLocal());
    final subtitulo = [
      if (item.source?.name != null && item.source!.name.isNotEmpty)
        item.source!.name,
      fecha,
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
      onTap: () => context.push('/items/${item.id}'),
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
