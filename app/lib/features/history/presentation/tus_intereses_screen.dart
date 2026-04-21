import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/item.dart';
import '../../feed/data/filtros_feed.dart';
import '../data/historial_provider.dart';

/// Panel "Tus intereses": resume qué ha marcado el usuario como útil, sin
/// reordenar nada automáticamente. Sólo cuenta y ofrece aplicar filtros
/// explícitos al feed — la decisión editorial sigue siendo humana.
///
/// Principios que guiaron el diseño:
///  - Cero telemetría: todo se calcula en cliente sobre SQLite local.
///  - Cero reordenación del feed: el algoritmo del manifiesto es
///    cronológico; lo que hacemos aquí es ayudar al usuario a
///    autoconocerse y elegir filtros, no imponer un ranking.
///  - Reversible: desmarcar un item basta con volver a tocar el botón
///    de útil en la lista, detalle o aquí mismo.
class TusInteresesScreen extends ConsumerWidget {
  const TusInteresesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncItems = ref.watch(itemsUtilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(textos.tusInteresesTitle)),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _Vacio(textos: textos);
          }
          final topTopics = _conteoTopics(items);
          final topMedios = _conteoMedios(items);
          final conteoFormatos = _conteoFormatos(items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Resumen(total: items.length, textos: textos),
              const SizedBox(height: 16),
              _Seccion(
                titulo: textos.tusInteresesTopTopics,
                icono: Icons.tag,
                child: _TopicsBloque(
                  topics: topTopics,
                  onAplicar: (slugs) => _aplicarFiltroTopics(context, ref, slugs),
                  textos: textos,
                ),
                vacio: topTopics.isEmpty,
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: textos.tusInteresesTopSources,
                icono: Icons.newspaper,
                child: _MediosBloque(medios: topMedios),
                vacio: topMedios.isEmpty,
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: textos.tusInteresesFormats,
                icono: Icons.view_agenda_outlined,
                child: _FormatosBloque(conteo: conteoFormatos, textos: textos),
                vacio: conteoFormatos.isEmpty,
              ),
            ],
          );
        },
      ),
    );
  }

  void _aplicarFiltroTopics(BuildContext context, WidgetRef ref, List<String> slugs) {
    final notifier = ref.read(filtrosFeedProvider.notifier);
    for (final slug in slugs) {
      notifier.alternarTopic(slug);
    }
    context.go('/');
  }
}

/// Cuenta cuántas veces aparece cada topic entre los items marcados útiles.
/// Devuelve los 5 más repetidos en orden descendente; empates resuelven
/// alfabéticamente por slug para que sea determinista entre sesiones.
List<_ConteoTopic> _conteoTopics(List<Item> items) {
  final conteo = <String, _ConteoTopic>{};
  for (final item in items) {
    for (final topic in item.topics) {
      final actual = conteo[topic.slug];
      if (actual == null) {
        conteo[topic.slug] = _ConteoTopic(topic.slug, topic.name, 1);
      } else {
        conteo[topic.slug] = _ConteoTopic(actual.slug, actual.nombre, actual.cuenta + 1);
      }
    }
  }
  final lista = conteo.values.toList()
    ..sort((a, b) {
      final cmp = b.cuenta.compareTo(a.cuenta);
      return cmp != 0 ? cmp : a.slug.compareTo(b.slug);
    });
  return lista.take(5).toList();
}

List<_ConteoMedio> _conteoMedios(List<Item> items) {
  final conteo = <int, _ConteoMedio>{};
  for (final item in items) {
    final source = item.source;
    if (source == null) continue;
    final actual = conteo[source.id];
    if (actual == null) {
      conteo[source.id] = _ConteoMedio(source.id, source.name, 1);
    } else {
      conteo[source.id] = _ConteoMedio(actual.id, actual.nombre, actual.cuenta + 1);
    }
  }
  final lista = conteo.values.toList()
    ..sort((a, b) {
      final cmp = b.cuenta.compareTo(a.cuenta);
      return cmp != 0 ? cmp : a.nombre.compareTo(b.nombre);
    });
  return lista.take(5).toList();
}

Map<_Formato, int> _conteoFormatos(List<Item> items) {
  final conteo = <_Formato, int>{};
  for (final item in items) {
    final formato = _clasificarFormato(item);
    conteo[formato] = (conteo[formato] ?? 0) + 1;
  }
  return Map.fromEntries(conteo.entries.where((e) => e.value > 0));
}

_Formato _clasificarFormato(Item item) {
  final tipoFeed = item.source?.feedType ?? '';
  if (tipoFeed == 'youtube' || tipoFeed == 'video') return _Formato.video;
  if (tipoFeed == 'podcast' || item.audioUrl.isNotEmpty) return _Formato.audio;
  final urlOriginal = item.originalUrl.toLowerCase();
  if (urlOriginal.contains('youtube.com') ||
      urlOriginal.contains('youtu.be') ||
      urlOriginal.contains('vimeo.com') ||
      urlOriginal.contains('peertube')) {
    return _Formato.video;
  }
  return _Formato.texto;
}

enum _Formato { texto, audio, video }

class _ConteoTopic {
  const _ConteoTopic(this.slug, this.nombre, this.cuenta);
  final String slug;
  final String nombre;
  final int cuenta;
}

class _ConteoMedio {
  const _ConteoMedio(this.id, this.nombre, this.cuenta);
  final int id;
  final String nombre;
  final int cuenta;
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.total, required this.textos});
  final int total;
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: esquema.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              textos.tusInteresesCount(total),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: esquema.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.icono,
    required this.child,
    required this.vacio,
  });

  final String titulo;
  final IconData icono;
  final Widget child;
  final bool vacio;

  @override
  Widget build(BuildContext context) {
    if (vacio) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: esquema.primary),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: esquema.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TopicsBloque extends StatelessWidget {
  const _TopicsBloque({
    required this.topics,
    required this.onAplicar,
    required this.textos,
  });
  final List<_ConteoTopic> topics;
  final void Function(List<String>) onAplicar;
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final t in topics)
              Chip(
                label: Text('${t.nombre} · ${t.cuenta}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.filter_alt),
            label: Text(textos.tusInteresesApplyFilter),
            onPressed: () => onAplicar(topics.map((t) => t.slug).toList()),
          ),
        ),
      ],
    );
  }
}

class _MediosBloque extends StatelessWidget {
  const _MediosBloque({required this.medios});
  final List<_ConteoMedio> medios;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in medios)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.nombre),
            trailing: Text('${m.cuenta}'),
            onTap: m.id > 0 ? () => context.push('/sources/${m.id}') : null,
          ),
      ],
    );
  }
}

class _FormatosBloque extends StatelessWidget {
  const _FormatosBloque({required this.conteo, required this.textos});
  final Map<_Formato, int> conteo;
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    String etiqueta(_Formato f) {
      switch (f) {
        case _Formato.texto:
          return textos.personalSourcesCategoryReading;
        case _Formato.audio:
          return textos.personalSourcesCategoryAudio;
        case _Formato.video:
          return textos.personalSourcesCategoryVideo;
      }
    }

    IconData icono(_Formato f) {
      switch (f) {
        case _Formato.texto:
          return Icons.menu_book_outlined;
        case _Formato.audio:
          return Icons.podcasts;
        case _Formato.video:
          return Icons.play_circle_outline;
      }
    }

    final entradas = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final entrada in entradas)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icono(entrada.key)),
            title: Text(etiqueta(entrada.key)),
            trailing: Text('${entrada.value}'),
          ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.textos});
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lightbulb_outline, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              textos.tusInteresesEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              textos.tusInteresesEmptyHelp,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
