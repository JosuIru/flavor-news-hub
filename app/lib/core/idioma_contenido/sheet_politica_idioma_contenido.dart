import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'politica_idioma_contenido.dart';

/// Bottom sheet para configurar la política central de idioma de
/// contenido. Tres opciones de modo + grid de chips de idiomas
/// soportados (activo sólo en modo manual).
///
/// Compartido entre Ajustes y la pestaña Audio. Antes vivía privado
/// dentro de `settings_screen.dart` y eso impedía abrirlo desde
/// otras pantallas (radios no podía configurar idioma porque su
/// botón de filtros llevaba al sheet de podcasts).
class SheetPoliticaIdiomaContenido extends ConsumerWidget {
  const SheetPoliticaIdiomaContenido({super.key});

  static const _idiomasOrden = ['es', 'ca', 'eu', 'gl', 'en', 'pt', 'fr'];

  /// Helper para abrir el sheet con la configuración estándar.
  static Future<void> mostrar(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const SheetPoliticaIdiomaContenido(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final estado = ref.watch(politicaIdiomaContenidoProvider);
    final notifier = ref.read(politicaIdiomaContenidoProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                textos.settingsContentLanguage,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                textos.settingsContentLanguageSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            RadioListTile<ModoIdiomaContenido>(
              value: ModoIdiomaContenido.seguirInterfaz,
              groupValue: estado.modo,
              title: Text(textos.settingsContentLanguageFollowUi),
              onChanged: (m) {
                if (m != null) notifier.establecerModo(m);
              },
            ),
            RadioListTile<ModoIdiomaContenido>(
              value: ModoIdiomaContenido.manual,
              groupValue: estado.modo,
              title: Text(textos.settingsContentLanguageManual),
              onChanged: (m) {
                if (m != null) notifier.establecerModo(m);
              },
            ),
            RadioListTile<ModoIdiomaContenido>(
              value: ModoIdiomaContenido.desactivado,
              groupValue: estado.modo,
              title: Text(textos.settingsContentLanguageOff),
              onChanged: (m) {
                if (m != null) notifier.establecerModo(m);
              },
            ),
            if (estado.modo == ModoIdiomaContenido.manual) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  textos.settingsContentLanguageManualHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final codigo in _idiomasOrden)
                      FilterChip(
                        label: Text(_nombreLegible(codigo)),
                        selected: estado.idiomasManuales.contains(codigo),
                        onSelected: (_) => notifier.alternarIdiomaManual(codigo),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  static String _nombreLegible(String codigo) {
    switch (codigo) {
      case 'es':
        return 'Castellano';
      case 'ca':
        return 'Català';
      case 'eu':
        return 'Euskara';
      case 'gl':
        return 'Galego';
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      case 'fr':
        return 'Français';
      default:
        return codigo;
    }
  }
}
