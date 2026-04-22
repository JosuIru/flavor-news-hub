import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/models/item.dart';

/// Tarjeta de un item en el listado del feed. Semánticamente es un botón
/// (todo el área es tappable) con título, metadatos, chips de temáticas
/// y, si la hay, imagen destacada a la derecha.
class ItemCard extends StatelessWidget {
  const ItemCard({
    required this.item,
    required this.onTap,
    required this.onSourceTap,
    required this.onTopicTap,
    required this.onGuardarAlternar,
    required this.onUtilAlternar,
    required this.estaGuardado,
    required this.esUtil,
    required this.estaLeido,
    super.key,
  });

  final Item item;
  final VoidCallback onTap;
  final ValueChanged<int> onSourceTap;
  final ValueChanged<String> onTopicTap;
  final VoidCallback onGuardarAlternar;
  final VoidCallback onUtilAlternar;
  final bool estaGuardado;
  final bool esUtil;
  final bool estaLeido;

  @override
  Widget build(BuildContext context) {
    final esquemaColores = Theme.of(context).colorScheme;
    final textos = AppLocalizations.of(context);
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final fechaFormateada = _fechaHumana(item.publishedAt, localeCodigo);

    return Semantics(
      button: true,
      label: item.title,
      child: Opacity(
        // Los items ya leídos se atenúan visualmente sin llegar a ser
        // ilegibles — el usuario sigue pudiendo hacer tap para releerlos.
        opacity: estaLeido ? 0.55 : 1.0,
        child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.source != null)
                      _CabeceraMedio(
                        nombreMedio: item.source!.name,
                        fechaHumana: fechaFormateada,
                        onSourceTap: () => onSourceTap(item.source!.id),
                      )
                    else
                      Text(
                        fechaFormateada,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: esquemaColores.onSurfaceVariant,
                            ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.topics.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final topic in item.topics)
                            ActionChip(
                              label: Text(topic.name),
                              onPressed: () => onTopicTap(topic.slug),
                              tooltip: textos.filterByTopic,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (item.mediaUrl.isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _ImagenDestacada(url: item.mediaUrl),
                ),
              ],
              // Bookmark + "útil" apilados: ambos sin abrir el detalle.
              // "Útil" alimenta la pantalla "Tus intereses" — no reordena
              // nada, sólo ayuda al usuario a ver qué le interesa.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(estaGuardado ? Icons.bookmark : Icons.bookmark_border),
                    tooltip: estaGuardado ? textos.itemUnsave : textos.itemSave,
                    onPressed: onGuardarAlternar,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                  ),
                  IconButton(
                    icon: Icon(esUtil ? Icons.lightbulb : Icons.lightbulb_outline),
                    tooltip: esUtil ? textos.itemUnmarkUseful : textos.itemMarkUseful,
                    onPressed: onUtilAlternar,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  static String _fechaHumana(String fechaIsoUtc, String localeCodigo) {
    if (fechaIsoUtc.isEmpty) return '';
    final timestamp = DateTime.tryParse(fechaIsoUtc);
    if (timestamp == null) return fechaIsoUtc;
    final ahora = DateTime.now().toUtc();
    final diferencia = ahora.difference(timestamp.toUtc());
    if (diferencia.inMinutes < 60 && diferencia.inMinutes >= 0) {
      return '${diferencia.inMinutes} min';
    }
    if (diferencia.inHours < 24 && diferencia.inHours >= 0) {
      return '${diferencia.inHours} h';
    }
    if (diferencia.inDays < 7 && diferencia.inDays >= 0) {
      return '${diferencia.inDays} d';
    }
    try {
      return DateFormat.yMMMd(localeCodigo).format(timestamp.toLocal());
    } catch (_) {
      return DateFormat.yMMMd().format(timestamp.toLocal());
    }
  }
}

class _CabeceraMedio extends StatelessWidget {
  const _CabeceraMedio({
    required this.nombreMedio,
    required this.fechaHumana,
    required this.onSourceTap,
  });

  final String nombreMedio;
  final String fechaHumana;
  final VoidCallback onSourceTap;

  @override
  Widget build(BuildContext context) {
    final colorSecundario = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: onSourceTap,
            child: Text(
              nombreMedio,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorSecundario,
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (fechaHumana.isNotEmpty) ...[
          Text(' · ', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorSecundario)),
          Text(
            fechaHumana,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorSecundario),
          ),
        ],
      ],
    );
  }
}

class _ImagenDestacada extends StatelessWidget {
  const _ImagenDestacada({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
        placeholder: (ctx, _) => Container(
          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
