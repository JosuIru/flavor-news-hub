import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/api_provider.dart';
import '../data/filtros_feed.dart';

/// Pantalla de filtros del feed. Muestra:
///  - Temáticas (checkbox chips, multi-selección).
///  - Territorio (texto libre).
///  - Idioma (dropdown con los 5 idiomas soportados + "cualquier idioma").
///
/// Los cambios se aplican al instante; el botón "Aplicar" sólo cierra la
/// pantalla porque el feed ya está re-renderizando en paralelo gracias a
/// la reactividad de Riverpod.
class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key});

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends ConsumerState<FiltersScreen> {
  late final TextEditingController _controllerTerritorio;

  @override
  void initState() {
    super.initState();
    final estadoActual = ref.read(filtrosFeedProvider);
    _controllerTerritorio = TextEditingController(text: estadoActual.codigoTerritorio ?? '');
  }

  @override
  void dispose() {
    _controllerTerritorio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosFeedProvider);
    final notifier = ref.read(filtrosFeedProvider.notifier);
    final asyncTopics = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.filtersTitle),
        actions: [
          if (!filtros.estaVacio)
            TextButton(
              onPressed: () {
                notifier.limpiar();
                _controllerTerritorio.clear();
              },
              child: Text(textos.filtersClear),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            textos.filterByTopic,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          asyncTopics.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => Text(textos.feedError),
            data: (topics) {
              // Ocultamos temáticas sin posts: un chip que garantiza feed
              // vacío es ruido, no información útil.
              final topicsUtiles = topics.where((t) => t.count > 0).toList();
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final topic in topicsUtiles)
                    FilterChip(
                      label: Text(topic.name),
                      selected: filtros.slugsTopics.contains(topic.slug),
                      onSelected: (_) => notifier.alternarTopic(topic.slug),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            textos.filterByTerritory,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controllerTerritorio,
            decoration: InputDecoration(
              hintText: 'Bizkaia, Catalunya, Estado, Internacional…',
              border: const OutlineInputBorder(),
              suffixIcon: _controllerTerritorio.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controllerTerritorio.clear();
                        notifier.establecerTerritorio(null);
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (valor) {
              notifier.establecerTerritorio(valor);
              setState(() {});
            },
          ),
          const SizedBox(height: 28),
          Text(
            textos.filterByLanguage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final opcion in _opcionesIdioma)
                FilterChip(
                  label: Text(opcion.etiqueta),
                  selected: filtros.codigosIdiomas.contains(opcion.codigo),
                  onSelected: (_) => notifier.alternarIdioma(opcion.codigo),
                ),
            ],
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => context.pop(),
            child: Text(textos.filtersApply),
          ),
        ],
      ),
    );
  }
}

class _OpcionIdiomaFiltro {
  const _OpcionIdiomaFiltro({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}

const List<_OpcionIdiomaFiltro> _opcionesIdioma = [
  _OpcionIdiomaFiltro(codigo: 'es', etiqueta: 'Castellano'),
  _OpcionIdiomaFiltro(codigo: 'ca', etiqueta: 'Català'),
  _OpcionIdiomaFiltro(codigo: 'eu', etiqueta: 'Euskara'),
  _OpcionIdiomaFiltro(codigo: 'gl', etiqueta: 'Galego'),
  _OpcionIdiomaFiltro(codigo: 'en', etiqueta: 'English'),
];
