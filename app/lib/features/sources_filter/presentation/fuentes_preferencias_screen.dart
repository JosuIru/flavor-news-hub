import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../data/fuentes_bloqueadas_notifier.dart';

/// Pantalla "Mis medios" (selección del usuario): lista todas las fuentes
/// activas agrupadas por territorio, con un switch por fila. Switch off =
/// no ver más sus titulares en el feed local (filtro client-side).
///
/// Con el catálogo creciendo (prensa + audio + video + Mastodon) una lista
/// plana agobia; los chips de la parte superior permiten filtrar por tipo
/// para encontrar rápido lo que el usuario busca desactivar o activar.
class FuentesPreferenciasScreen extends ConsumerStatefulWidget {
  const FuentesPreferenciasScreen({super.key});

  @override
  ConsumerState<FuentesPreferenciasScreen> createState() =>
      _EstadoFuentesPreferencias();
}

class _EstadoFuentesPreferencias extends ConsumerState<FuentesPreferenciasScreen> {
  _CategoriaFuente _categoria = _CategoriaFuente.todas;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final asyncSources = ref.watch(sourcesProvider);
    final bloqueadas = ref.watch(fuentesBloqueadasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.sourcesPrefsTitle),
        actions: [
          if (bloqueadas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: textos.sourcesPrefsResetAll,
              onPressed: () =>
                  ref.read(fuentesBloqueadasProvider.notifier).limpiar(),
            ),
        ],
      ),
      body: asyncSources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (pagina) {
          final fuentes = pagina.items;
          if (fuentes.isEmpty) {
            return Center(child: Text(textos.sourcesPrefsEmpty));
          }
          final filtradas = fuentes
              .where((f) => _coincideCategoria(f, _categoria))
              .toList();
          final porTerritorio = _agruparPorTerritorio(filtradas);
          return Column(
            children: [
              _BarraCategorias(
                actual: _categoria,
                onSeleccion: (c) => setState(() => _categoria = c),
                textos: textos,
              ),
              const Divider(height: 1),
              Expanded(
                child: filtradas.isEmpty
                    ? Center(child: Text(textos.sourcesPrefsEmpty))
                    : ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              textos.sourcesPrefsHelp,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          for (final entrada in porTerritorio.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                entrada.key,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                            for (final fuente in entrada.value)
                              SwitchListTile(
                                title: Text(fuente.name),
                                subtitle: _subtitulo(fuente) != null
                                    ? Text(_subtitulo(fuente)!)
                                    : null,
                                value: !bloqueadas.contains(fuente.id),
                                onChanged: (_) => ref
                                    .read(fuentesBloqueadasProvider.notifier)
                                    .alternar(fuente.id),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _coincideCategoria(Source fuente, _CategoriaFuente categoria) {
    if (categoria == _CategoriaFuente.todas) return true;
    final tipo = fuente.feedType;
    switch (categoria) {
      case _CategoriaFuente.prensa:
        return tipo == 'rss' || tipo == 'atom' || tipo == 'flavor_platform';
      case _CategoriaFuente.audio:
        return tipo == 'podcast';
      case _CategoriaFuente.video:
        return tipo == 'youtube' || tipo == 'video' || tipo == 'peertube';
      case _CategoriaFuente.fediverso:
        return tipo == 'mastodon';
      case _CategoriaFuente.todas:
        return true;
    }
  }

  String? _subtitulo(Source fuente) {
    final piezas = <String>[
      if (fuente.languages.isNotEmpty) fuente.languages.join(', '),
      if (fuente.feedType.isNotEmpty && fuente.feedType != 'rss') fuente.feedType,
    ];
    return piezas.isEmpty ? null : piezas.join(' · ');
  }

  Map<String, List<Source>> _agruparPorTerritorio(List<Source> fuentes) {
    final mapa = <String, List<Source>>{};
    for (final f in fuentes) {
      final clave = f.territory.trim().isEmpty ? '—' : f.territory;
      mapa.putIfAbsent(clave, () => []).add(f);
    }
    // Orden predecible para el usuario: alfabético, con "—" (sin territorio)
    // al final.
    final ordenadas = mapa.keys.toList()
      ..sort((a, b) {
        if (a == '—') return 1;
        if (b == '—') return -1;
        return a.compareTo(b);
      });
    return {for (final k in ordenadas) k: mapa[k]!};
  }
}

enum _CategoriaFuente { todas, prensa, audio, video, fediverso }

class _BarraCategorias extends StatelessWidget {
  const _BarraCategorias({
    required this.actual,
    required this.onSeleccion,
    required this.textos,
  });

  final _CategoriaFuente actual;
  final ValueChanged<_CategoriaFuente> onSeleccion;
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    final items = <_ItemCategoria>[
      _ItemCategoria(_CategoriaFuente.todas, textos.sourcesCategoryAll, Icons.apps),
      _ItemCategoria(
          _CategoriaFuente.prensa, textos.sourcesCategoryPress, Icons.newspaper),
      _ItemCategoria(
          _CategoriaFuente.audio, textos.sourcesCategoryAudio, Icons.podcasts),
      _ItemCategoria(
          _CategoriaFuente.video, textos.sourcesCategoryVideo, Icons.play_circle_outline),
      _ItemCategoria(
          _CategoriaFuente.fediverso, textos.sourcesCategoryFediverse, Icons.forum_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final item in items) ...[
            FilterChip(
              avatar: Icon(item.icono, size: 16),
              label: Text(item.etiqueta),
              selected: actual == item.categoria,
              onSelected: (_) => onSeleccion(item.categoria),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _ItemCategoria {
  const _ItemCategoria(this.categoria, this.etiqueta, this.icono);
  final _CategoriaFuente categoria;
  final String etiqueta;
  final IconData icono;
}
