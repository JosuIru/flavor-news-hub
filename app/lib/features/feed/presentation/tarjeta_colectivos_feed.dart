import 'package:flutter/material.dart';
import 'package:flavor_news_hub/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/topic.dart';
import 'item_detail_screen.dart' show colectivosRelacionadosProvider, ConsultaColectivosRelacionados;

/// Tarjeta intercalada en el feed que materializa la misión del proyecto
/// —pasar de informarse a actuar— sin esperar a que el usuario abra un
/// titular: sobre la temática dominante del feed, muestra quién ya se está
/// organizando.
///
/// Es contenido oportunista: si está cargando, falla o no hay colectivos
/// para esa temática, no pinta nada (`SizedBox.shrink`) para no meter un
/// hueco ni un spinner a mitad de la lista. Reutiliza
/// [colectivosRelacionadosProvider], así que comparte caché con el detalle
/// y no añade más que una consulta por temática.
class TarjetaColectivosFeed extends ConsumerWidget {
  const TarjetaColectivosFeed({
    required this.tema,
    required this.territorio,
    super.key,
  });

  final Topic tema;
  final String territorio;

  /// Máximo de colectivos que mostramos en la tarjeta antes del CTA.
  static const int _maxVisibles = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncColectivos = ref.watch(colectivosRelacionadosProvider(
      ConsultaColectivosRelacionados(
        slugsTopicsCsv: tema.slug,
        territorio: territorio,
      ),
    ));

    final pagina = asyncColectivos.valueOrNull;
    if (pagina == null || pagina.estaVacia) return const SizedBox.shrink();

    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final visibles = pagina.items.take(_maxVisibles).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: esquema.secondaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.diversity_3, size: 20, color: esquema.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    textos.feedOrganizingCardTitle(tema.name),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: esquema.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final colectivo in visibles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  colectivo.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: esquema.onSecondaryContainer,
                  ),
                ),
                subtitle: Text(
                  _subtitulo(colectivo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: esquema.onSecondaryContainer.withValues(alpha: 0.8)),
                ),
                trailing: Icon(Icons.chevron_right, color: esquema.onSecondaryContainer),
                onTap: () => context.push('/collectives/${colectivo.id}'),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/collectives'),
                child: Text(textos.feedOrganizingCardCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitulo(Collective colectivo) {
    final piezas = <String>[
      if (colectivo.territory.isNotEmpty) colectivo.territory,
      ...colectivo.topics.take(2).map((t) => t.name),
    ];
    return piezas.join(' · ');
  }
}
