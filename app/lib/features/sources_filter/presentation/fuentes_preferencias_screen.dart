import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/source.dart';
import '../../../core/providers/api_provider.dart';
import '../data/fuentes_bloqueadas_notifier.dart';

/// Pantalla "Mis medios" (selección del usuario): lista todas las fuentes
/// activas agrupadas por territorio, con un switch por fila. Switch off =
/// no ver más sus titulares en el feed local (filtro client-side).
class FuentesPreferenciasScreen extends ConsumerWidget {
  const FuentesPreferenciasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          final porTerritorio = _agruparPorTerritorio(fuentes);
          return ListView(
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
                    subtitle: _subtitulo(fuente) != null ? Text(_subtitulo(fuente)!) : null,
                    value: !bloqueadas.contains(fuente.id),
                    onChanged: (_) =>
                        ref.read(fuentesBloqueadasProvider.notifier).alternar(fuente.id),
                  ),
              ],
            ],
          );
        },
      ),
    );
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
