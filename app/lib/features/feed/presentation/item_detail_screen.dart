import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/collective.dart';
import '../../../core/models/item.dart';
import '../../../core/models/paginated_list.dart';
import '../../../core/providers/api_provider.dart';
import '../../history/data/historial_provider.dart';

/// Provider del detalle de un item concreto. Family por id.
///
/// Ids negativos identifican items del seed RSS o de fuentes personales:
/// no tienen endpoint en el backend, así que vamos directos a cache.
///
/// Para ids positivos pedimos al backend; si falla por red, caemos a
/// cache — así el detalle funciona también con el servidor caído.
final itemDetalleProvider = FutureProvider.autoDispose.family<Item, int>((ref, idItem) async {
  if (idItem <= 0) {
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    final cacheado = await dao.obtenerPorId(idItem);
    if (cacheado != null) return cacheado;
    throw const FlavorNewsApiException(
      statusCode: 404,
      errorCode: 'not_found_in_cache',
      message: 'El item no está cacheado localmente.',
    );
  }
  final api = ref.watch(flavorNewsApiProvider);
  try {
    return await api.fetchItem(idItem);
  } on FlavorNewsApiException catch (e) {
    if (!e.esProblemaRed) rethrow;
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    final cacheado = await dao.obtenerPorId(idItem);
    if (cacheado != null) return cacheado;
    rethrow;
  }
});

/// Argumentos para [colectivosRelacionadosProvider].
@immutable
class ConsultaColectivosRelacionados {
  const ConsultaColectivosRelacionados({
    required this.slugsTopicsCsv,
    required this.territorio,
  });

  final String slugsTopicsCsv;
  final String territorio;

  @override
  bool operator ==(Object other) =>
      other is ConsultaColectivosRelacionados &&
      other.slugsTopicsCsv == slugsTopicsCsv &&
      other.territorio == territorio;

  @override
  int get hashCode => Object.hash(slugsTopicsCsv, territorio);
}

/// Colectivos relacionados con un item. Estrategia de varias pasadas
/// para que la sección "¿Quién se organiza sobre esto?" no quede vacía
/// en items sin topics asignados (la mayoría de items RSS no traen
/// topics; el ingester sólo los hereda si están curados en el seed):
///
///  1. Por topic compartido: el matching más fuerte.
///  2. Si no hay match Y hay territorio del source → fallback a
///     colectivos del mismo territorio. Es señal débil pero útil para
///     que el usuario vea "estos grupos están en tu zona".
///  3. Si nada de lo anterior produce resultados → lista vacía.
final colectivosRelacionadosProvider = FutureProvider.autoDispose
    .family<PaginatedList<Collective>, ConsultaColectivosRelacionados>(
  (ref, consulta) async {
    final api = ref.watch(flavorNewsApiProvider);
    if (consulta.slugsTopicsCsv.isNotEmpty) {
      final porTopic = await api.fetchCollectives(
        topic: consulta.slugsTopicsCsv,
        perPage: 5,
      );
      if (porTopic.items.isNotEmpty) return porTopic;
    }
    if (consulta.territorio.isNotEmpty) {
      return api.fetchCollectives(
        territory: consulta.territorio,
        perPage: 5,
      );
    }
    return const PaginatedList<Collective>(
      items: [],
      total: 0,
      totalPages: 0,
      page: 1,
      perPage: 5,
    );
  },
);

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({required this.idItem, super.key});
  final String idItem;

  @override
  ConsumerState<ItemDetailScreen> createState() => _EstadoItemDetail();
}

class _EstadoItemDetail extends ConsumerState<ItemDetailScreen> {
  bool _marcadoLeido = false;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final idNumerico = int.tryParse(widget.idItem) ?? 0;
    final asyncItem = ref.watch(itemDetalleProvider(idNumerico));
    final guardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
    final utiles = ref.watch(utilesProvider).valueOrNull ?? const <int>{};
    final estaGuardado = guardados.contains(idNumerico);
    final esUtil = utiles.contains(idNumerico);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.feedTitle),
        actions: [
          asyncItem.when(
            data: (item) => Row(
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
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncItem.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorDetalle(
          error: error,
          onReintentar: () => ref.invalidate(itemDetalleProvider(idNumerico)),
        ),
        data: (item) {
          // Marca como leído al mostrar el detalle la primera vez.
          if (!_marcadoLeido) {
            _marcadoLeido = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(leidosProvider.notifier).marcarLeido(item);
            });
          }
          return _CuerpoDetalle(item: item);
        },
      ),
    );
  }
}

class _CuerpoDetalle extends ConsumerWidget {
  const _CuerpoDetalle({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final timestampPublicacion = DateTime.tryParse(item.publishedAt);
    final fechaFormateada = timestampPublicacion != null
        ? DateFormat.yMMMMd(localeCodigo).add_Hm().format(timestampPublicacion.toLocal())
        : '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.source != null || fechaFormateada.isNotEmpty)
            _MetaLinea(
              nombreMedio: item.source?.name,
              fechaHumana: fechaFormateada,
              onSourceTap: item.source != null
                  ? () => _abrirFichaMedio(context, item.source!.id)
                  : null,
            ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 12),
          if (item.topics.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final topic in item.topics)
                  Chip(
                    label: Text(topic.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (item.mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.mediaUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Extracto: HTML saneado por el backend (wp_kses_post). Si ya
          // mostramos la imagen destacada arriba, quitamos las `<img>`
          // del excerpt para evitar ver dos veces la misma foto — RSS y
          // Atom suelen repetirla como primer elemento del description.
          HtmlWidget(
            _excerptSinImagenes(item.excerpt, eliminar: item.mediaUrl.isNotEmpty),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
            onTapUrl: (url) async {
              final uri = Uri.tryParse(url);
              if (uri == null) return false;
              return launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (item.originalUrl.isNotEmpty)
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      textos.itemOpenInSource(item.source?.name ?? ''),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _abrirUrlExterna(item.originalUrl),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: textos.itemCopyLink,
                onPressed: () async {
                  final url = item.originalUrl.isNotEmpty ? item.originalUrl : item.url;
                  if (url.isEmpty) return;
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(textos.itemLinkCopied)),
                    );
                  }
                },
                icon: const Icon(Icons.link),
              ),
              IconButton(
                tooltip: textos.itemShare,
                onPressed: () async {
                  final textoCompartir = item.url.isNotEmpty
                      ? '${item.title}\n${item.url}'
                      : item.title;
                  await Share.share(textoCompartir);
                },
                icon: const Icon(Icons.share),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: esquema.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: esquema.outlineVariant),
            ),
            child: _BloqueOrganizing(item: item),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _abrirUrlExterna(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _abrirFichaMedio(BuildContext context, int idSource) {
    GoRouter.of(context).push('/sources/$idSource');
  }
}

class _MetaLinea extends StatelessWidget {
  const _MetaLinea({this.nombreMedio, required this.fechaHumana, this.onSourceTap});
  final String? nombreMedio;
  final String fechaHumana;
  final VoidCallback? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final colorSec = Theme.of(context).colorScheme.onSurfaceVariant;
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(color: colorSec);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (nombreMedio != null && nombreMedio!.isNotEmpty)
          InkWell(
            onTap: onSourceTap,
            child: Text(nombreMedio!, style: estilo?.copyWith(fontWeight: FontWeight.w600)),
          ),
        if ((nombreMedio?.isNotEmpty ?? false) && fechaHumana.isNotEmpty)
          Text(' · ', style: estilo),
        if (fechaHumana.isNotEmpty) Text(fechaHumana, style: estilo),
      ],
    );
  }
}

class _BloqueOrganizing extends ConsumerWidget {
  const _BloqueOrganizing({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final slugsCsv = item.topics.map((t) => t.slug).join(',');
    // Territorio del source como fallback cuando el item no trae
    // topics: muchos feeds RSS no etiquetan, y sin esto la sección
    // queda casi siempre vacía. El territorio es señal débil pero
    // útil para que el usuario vea grupos de su zona aunque el
    // contenido del titular no les case por temática.
    final territorio = item.source?.territory ?? '';
    final asyncColectivos = ref.watch(colectivosRelacionadosProvider(
      ConsultaColectivosRelacionados(
        slugsTopicsCsv: slugsCsv,
        territorio: territorio,
      ),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textos.itemOrganizingTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        asyncColectivos.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => Text(textos.itemOrganizingEmpty),
          data: (pagina) {
            if (pagina.estaVacia) {
              return Text(textos.itemOrganizingEmpty);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final colectivo in pagina.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(colectivo.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _subtituloColectivo(colectivo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => GoRouter.of(context).push('/collectives/${colectivo.id}'),
                  ),
                if (pagina.tieneMasPaginas) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => GoRouter.of(context).go('/collectives'),
                      child: Text(textos.itemOrganizingSeeAll),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _subtituloColectivo(Collective c) {
    final piezas = <String>[
      if (c.territory.isNotEmpty) c.territory,
      ...c.topics.take(2).map((t) => t.name),
    ];
    return piezas.join(' · ');
  }
}

class _ErrorDetalle extends StatelessWidget {
  const _ErrorDetalle({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final apiError = error is FlavorNewsApiException ? error as FlavorNewsApiException : null;
    final mensaje = apiError?.message ?? error.toString();
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

/// Quita las `<img>` del HTML del excerpt si `eliminar` es true. También
/// retira `<figure>`/`<picture>` vacíos que pueda dejar la operación.
/// Simplista a propósito: es suficiente para el caso real — los feeds
/// repiten la foto destacada como primer elemento del description.
String _excerptSinImagenes(String html, {required bool eliminar}) {
  if (!eliminar || html.isEmpty) return html;
  var salida = html.replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '');
  salida = salida.replaceAll(
      RegExp(r'<(figure|picture)[^>]*>\s*</\1>', caseSensitive: false), '');
  return salida;
}
