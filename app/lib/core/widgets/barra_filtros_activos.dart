import 'package:flutter/material.dart';
import 'package:flavor_news_hub/l10n/app_localizations.dart';

/// Barra horizontal con un chip por cada filtro activo. Cada chip
/// tiene su propia X para quitar ese filtro individualmente, y al
/// final un botón "Limpiar" si hay más de un chip que vacía todo.
///
/// Pensada para reutilizarse en cualquier pantalla con filtros (feed,
/// vídeos, TV, podcasts, radios) — cada una le pasa los datos de su
/// propio notifier y los callbacks correspondientes. Antes cada
/// pantalla replicaba el patrón con código distinto, o directamente
/// no lo tenía y el usuario no veía qué filtros tenía aplicados.
class BarraChipsFiltrosActivos extends StatelessWidget {
  const BarraChipsFiltrosActivos({
    super.key,
    this.slugsTopics = const [],
    this.codigosIdiomas = const [],
    this.codigoTerritorio,
    this.nombreFuente,
    this.onQuitarTopic,
    this.onQuitarIdioma,
    this.onQuitarTerritorio,
    this.onQuitarFuente,
    this.onLimpiarTodo,
  });

  /// Slugs de topics activos. Si está vacía, no se renderiza ningún chip.
  final List<String> slugsTopics;

  /// Códigos ISO de idioma activos (es, ca, eu, gl, en, …).
  final List<String> codigosIdiomas;

  /// Código de territorio activo (p. ej. "Euskal Herria").
  final String? codigoTerritorio;

  /// Nombre de la fuente cuando se filtra por una concreta.
  final String? nombreFuente;

  final void Function(String slug)? onQuitarTopic;
  final void Function(String codigo)? onQuitarIdioma;
  final VoidCallback? onQuitarTerritorio;
  final VoidCallback? onQuitarFuente;
  final VoidCallback? onLimpiarTodo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final textos = AppLocalizations.of(context);

    final List<Widget> chips = [];

    if (nombreFuente != null && nombreFuente!.isNotEmpty && onQuitarFuente != null) {
      chips.add(InputChip(
        avatar: Icon(Icons.podcasts, size: 18, color: esquema.primary),
        label: Text(nombreFuente!),
        onDeleted: onQuitarFuente,
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    for (final slug in slugsTopics) {
      // Capitalizamos el slug para presentación; el `name` real del
      // topic vendría de cargar el provider de topics, pero el slug
      // capitalizado da una representación suficientemente clara y
      // evita una segunda dependencia asíncrona.
      final etiqueta = slug.isEmpty
          ? slug
          : '${slug[0].toUpperCase()}${slug.substring(1).replaceAll('-', ' ')}';
      chips.add(InputChip(
        label: Text(etiqueta),
        onDeleted: onQuitarTopic == null ? null : () => onQuitarTopic!(slug),
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    if (codigoTerritorio != null && codigoTerritorio!.isNotEmpty) {
      chips.add(InputChip(
        avatar: Icon(Icons.place_outlined, size: 18, color: esquema.primary),
        label: Text(codigoTerritorio!),
        onDeleted: onQuitarTerritorio,
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    for (final codigoIdioma in codigosIdiomas) {
      chips.add(InputChip(
        avatar: Icon(Icons.language, size: 18, color: esquema.primary),
        label: Text(codigoIdioma.toUpperCase()),
        onDeleted: onQuitarIdioma == null ? null : () => onQuitarIdioma!(codigoIdioma),
        deleteIconColor: esquema.onSurfaceVariant,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Material(
      color: esquema.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < chips.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        chips[i],
                      ],
                    ],
                  ),
                ),
              ),
              if (chips.length > 1 && onLimpiarTodo != null)
                TextButton(
                  onPressed: onLimpiarTodo,
                  child: Text(textos.filtersClear),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
