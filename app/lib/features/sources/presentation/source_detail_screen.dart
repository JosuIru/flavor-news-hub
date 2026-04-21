import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../feed/data/filtros_feed.dart';

final sourceDetalleProvider =
    FutureProvider.autoDispose.family<Source, int>((ref, idSource) async {
  final api = ref.watch(flavorNewsApiProvider);
  return api.fetchSource(idSource);
});

class SourceDetailScreen extends ConsumerWidget {
  const SourceDetailScreen({required this.idSource, super.key});

  final String idSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final idNumerico = int.tryParse(idSource) ?? 0;
    final asyncSource = ref.watch(sourceDetalleProvider(idNumerico));

    return Scaffold(
      appBar: AppBar(title: Text(textos.sourceTitle)),
      body: asyncSource.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorSimple(
          mensaje: error.toString(),
          onReintentar: () => ref.invalidate(sourceDetalleProvider(idNumerico)),
        ),
        data: (source) => _CuerpoSource(source: source),
      ),
    );
  }
}

class _CuerpoSource extends ConsumerWidget {
  const _CuerpoSource({required this.source});
  final Source source;

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
            source.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (source.territory.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              source.territory,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
            ),
          ],
          if (source.topics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final topic in source.topics)
                  Chip(
                    label: Text(topic.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (source.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            HtmlWidget(
              source.description,
              onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: esquema.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textos.sourceEditorialHeader,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (source.websiteUrl.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceWebsite,
                    valor: source.websiteUrl,
                    esEnlace: true,
                    urlEnlace: source.websiteUrl,
                  ),
                if (source.ownership.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceOwnership,
                    valor: source.ownership,
                    esHtml: true,
                  ),
                if (source.editorialNote.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceEditorialNote,
                    valor: source.editorialNote,
                    esHtml: true,
                  ),
                if (source.territory.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceTerritory,
                    valor: source.territory,
                  ),
                if (source.languages.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceLanguages,
                    valor: source.languages.join(', '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await ref.read(filtrosFeedProvider.notifier).establecerSource(source.id);
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.filter_list),
            label: Text(textos.sourceListNews),
          ),
        ],
      ),
    );
  }
}

class _CampoEditorial extends StatelessWidget {
  const _CampoEditorial({
    required this.etiqueta,
    required this.valor,
    this.esEnlace = false,
    this.urlEnlace,
    this.esHtml = false,
  });

  final String etiqueta;
  final String valor;
  final bool esEnlace;
  final String? urlEnlace;
  final bool esHtml;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                  letterSpacing: .6,
                ),
          ),
          const SizedBox(height: 2),
          if (esEnlace && urlEnlace != null)
            InkWell(
              onTap: () => launchUrl(Uri.parse(urlEnlace!), mode: LaunchMode.externalApplication),
              child: Text(
                valor,
                style: TextStyle(color: esquema.primary, decoration: TextDecoration.underline),
              ),
            )
          else if (esHtml)
            HtmlWidget(
              valor,
              onTapUrl: (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            )
          else
            Text(valor),
        ],
      ),
    );
  }
}

class _ErrorSimple extends StatelessWidget {
  const _ErrorSimple({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
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
    );
  }
}
