import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/collective.dart';
import '../../../core/providers/api_provider.dart';
import '../../flavor_platform/presentation/seccion_actividad_flavor.dart';

final colectivoDetalleProvider =
    FutureProvider.autoDispose.family<Collective, int>((ref, id) async {
  final api = ref.watch(flavorNewsApiProvider);
  return api.fetchCollective(id);
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
