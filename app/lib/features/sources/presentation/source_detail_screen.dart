import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../../feed/data/filtros_feed.dart';
import '../../offline_seed/data/seed_loader.dart';
import '../../videos/data/videos_provider.dart';

/// Detalle de un medio. Intenta el backend primero; si falla por red o
/// el medio no existe ahí (p. ej. canales de YouTube que sólo vienen
/// en el seed bundleado), buscamos en el seed local — así abrir una
/// fuente desde el buscador no explota cuando la instancia está caída
/// o aún no ha ingestado ese medio.
final sourceDetalleProvider =
    FutureProvider.autoDispose.family<Source, int>((ref, idSource) async {
  final api = ref.watch(flavorNewsApiProvider);
  try {
    return await api.fetchSource(idSource);
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed && !e.esNoEncontrado) rethrow;
    final seed = await ref.watch(sourcesSeedProvider.future);
    final match = seed.where((s) => s.id == idSource).toList();
    if (match.isNotEmpty) return match.first;
    rethrow;
  }
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
          // Badge compacto con la licencia cuando sea declarada y no
          // sea "all-rights-reserved" (que es el default implícito y
          // no aporta información). Verde distintivo para las CC.
          if (_etiquetaLicencia(source.contentLicense) != null) ...[
            const SizedBox(height: 8),
            _BadgeLicencia(codigo: source.contentLicense),
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
                if (source.legalNote.isNotEmpty)
                  _CampoEditorial(
                    etiqueta: textos.sourceLegalNote,
                    valor: source.legalNote,
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
          _BotonVerContenido(source: source, textos: textos, ref: ref),
        ],
      ),
    );
  }
}

/// El botón "ver contenido de este medio" cambia según el tipo de feed:
/// un canal de YouTube/PeerTube no tiene "noticias", tiene vídeos; un
/// podcast → audio; los RSS/Atom/Mastodon → feed de titulares.
class _BotonVerContenido extends StatelessWidget {
  const _BotonVerContenido({
    required this.source,
    required this.textos,
    required this.ref,
  });

  final Source source;
  final AppLocalizations textos;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final tipo = source.feedType;
    final esVideo = tipo == 'youtube' || tipo == 'video';
    final esPodcast = tipo == 'podcast';

    if (esVideo) {
      return FilledButton.icon(
        onPressed: () {
          // Ajustamos el filtro de la pestaña Videos a este canal
          // concreto antes de navegar, si no veríamos todos mezclados.
          ref.read(filtrosVideosProvider.notifier).state =
              FiltrosVideos.vacios.conSource(source.id);
          context.go('/videos');
        },
        icon: const Icon(Icons.play_circle_outline),
        label: Text(textos.sourceListVideos),
      );
    }
    if (esPodcast) {
      return FilledButton.icon(
        onPressed: () => context.go('/audio'),
        icon: const Icon(Icons.podcasts),
        label: Text(textos.sourceListAudio),
      );
    }
    return FilledButton.icon(
      onPressed: () async {
        await ref.read(filtrosFeedProvider.notifier).establecerSource(source.id);
        if (context.mounted) context.go('/');
      },
      icon: const Icon(Icons.filter_list),
      label: Text(textos.sourceListNews),
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

/// Formatea el slug de licencia a etiqueta humana, o devuelve null si
/// no hay licencia declarada o es "all-rights-reserved" (que es el
/// default implícito de derechos de autor y no aporta como badge).
String? _etiquetaLicencia(String codigo) {
  if (codigo.isEmpty || codigo == 'all-rights-reserved') return null;
  switch (codigo) {
    case 'public-domain':
    case 'cc0-1.0':
      return 'Dominio público';
    case 'mixed':
      return 'Licencia mixta';
  }
  if (!codigo.startsWith('cc-')) return null;
  // "cc-by-nc-nd-3.0-us" -> "CC BY-NC-ND 3.0 US"
  final resto = codigo.substring(3);
  final partes = resto.split('-');
  // Las partes puramente alfabéticas van en mayúscula (by, nc, nd, sa);
  // las versiones numéricas y países se mantienen como están, pero el
  // código ISO de país (us, eu...) también se mayuscula.
  final procesadas = <String>[];
  for (var i = 0; i < partes.length; i++) {
    final p = partes[i];
    final esLetrasSolo = RegExp(r'^[a-z]+$').hasMatch(p);
    procesadas.add(esLetrasSolo ? p.toUpperCase() : p);
  }
  // Intentamos insertar un espacio antes de la primera parte que tenga
  // dígitos (la versión): "BY NC ND 3.0 US" -> "BY-NC-ND 3.0 US".
  final buffer = StringBuffer('CC ');
  for (var i = 0; i < procesadas.length; i++) {
    final p = procesadas[i];
    final tieneNumero = RegExp(r'\d').hasMatch(p);
    if (i == 0) {
      buffer.write(p);
    } else if (tieneNumero || RegExp(r'\d').hasMatch(procesadas[i - 1])) {
      buffer.write(' $p');
    } else {
      buffer.write('-$p');
    }
  }
  return buffer.toString();
}

class _BadgeLicencia extends StatelessWidget {
  const _BadgeLicencia({required this.codigo});
  final String codigo;

  @override
  Widget build(BuildContext context) {
    final etiqueta = _etiquetaLicencia(codigo);
    if (etiqueta == null) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    final esCC = codigo.startsWith('cc-') || codigo == 'cc0-1.0';
    final fondo = esCC
        ? Colors.green.withOpacity(0.18)
        : esquema.secondaryContainer;
    final color = esCC ? Colors.green.shade800 : esquema.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(esCC ? Icons.copyright_outlined : Icons.shield_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            etiqueta,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
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
