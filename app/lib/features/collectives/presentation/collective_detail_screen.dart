import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../flavor_platform/presentation/seccion_actividad_flavor.dart';

final colectivoDetalleProvider =
    FutureProvider.autoDispose.family<Collective, int>((ref, id) async {
  final api = ref.watch(flavorNewsApiProvider);
  return api.fetchCollective(id);
});

/// Resuelve los `Source` vinculados a un colectivo a partir de la lista
/// de `sourceIds`. Paralelizamos los fetches y toleramos fallos
/// individuales: si un ID no existe en el backend (p. ej. catálogo
/// desincronizado) se omite sin romper la pantalla.
final mediosDeColectivoProvider =
    FutureProvider.autoDispose.family<List<Source>, List<int>>((ref, ids) async {
  if (ids.isEmpty) return const [];
  final api = ref.watch(flavorNewsApiProvider);
  Future<Source?> resolver(int id) async {
    try {
      return await api.fetchSource(id);
    } catch (_) {
      return null;
    }
  }
  final resueltos = await Future.wait(ids.map(resolver));
  return resueltos.whereType<Source>().toList(growable: false);
});

class CollectiveDetailScreen extends ConsumerWidget {
  const CollectiveDetailScreen({required this.idColectivo, super.key});

  final String idColectivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final idNumerico = int.tryParse(idColectivo) ?? 0;
    final asyncColectivo = ref.watch(colectivoDetalleProvider(idNumerico));

    return Scaffold(
      appBar: AppBar(title: Text(textos.directoryTitle)),
      body: asyncColectivo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(colectivoDetalleProvider(idNumerico)),
                  icon: const Icon(Icons.refresh),
                  label: Text(textos.commonRetry),
                ),
              ],
            ),
          ),
        ),
        data: (colectivo) => _CuerpoColectivo(colectivo: colectivo),
      ),
    );
  }
}

class _CuerpoColectivo extends ConsumerWidget {
  const _CuerpoColectivo({required this.colectivo});

  final Collective colectivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            colectivo.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (colectivo.territory.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              colectivo.territory,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
            ),
          ],
          if (colectivo.topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final topic in colectivo.topics)
                  Chip(
                    label: Text(topic.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (colectivo.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            HtmlWidget(
              colectivo.description,
              onTapUrl: (url) =>
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
          ],
          if (colectivo.sourceIds.isNotEmpty) ...[
            const SizedBox(height: 24),
            _MediosDelColectivo(ids: colectivo.sourceIds),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (colectivo.websiteUrl.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => launchUrl(
                    Uri.parse(colectivo.websiteUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(textos.collectiveVisitWebsite),
                ),
              if (colectivo.supportUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(colectivo.supportUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.favorite),
                  label: Text(textos.supportEntity),
                ),
              if (colectivo.flavorUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(colectivo.flavorUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.hub_outlined),
                  label: Text(textos.collectiveFlavorCommunity),
                ),
              OutlinedButton.icon(
                onPressed: () => Share.share(
                  colectivo.url.isNotEmpty ? '${colectivo.name}\n${colectivo.url}' : colectivo.name,
                ),
                icon: const Icon(Icons.share),
                label: Text(textos.collectiveShare),
              ),
            ],
          ),
          if (colectivo.flavorUrl.isNotEmpty)
            SeccionActividadFlavor(flavorUrl: colectivo.flavorUrl),
        ],
      ),
    );
  }
}

/// Lista de medios (`Source`) editados por el colectivo, resueltos a
/// partir de `sourceIds`. Se colapsa cuando no hay nada resuelto (el
/// colectivo puede tener IDs en el meta que ya no existen).
class _MediosDelColectivo extends ConsumerWidget {
  const _MediosDelColectivo({required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncMedios = ref.watch(mediosDeColectivoProvider(ids));
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textos.collectiveMediaTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        asyncMedios.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Text(textos.collectiveMediaEmpty),
          data: (medios) {
            if (medios.isEmpty) {
              return Text(
                textos.collectiveMediaEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final medio in medios)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.rss_feed_outlined, color: esquema.primary),
                    title: Text(
                      medio.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: medio.territory.isNotEmpty
                        ? Text(medio.territory, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => GoRouter.of(context).push('/sources/${medio.id}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
