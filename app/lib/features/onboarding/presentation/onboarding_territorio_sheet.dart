import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/territory_normalizer.dart';

/// Sheet modal que se muestra en el primer arranque de la app para
/// que el usuario elija su territorio base. Cierra el círculo del
/// principio "de lo local a lo global": sin este paso, la mayoría de
/// usuarios nunca descubrirían el selector en Ajustes, y el scoring
/// local-primero no aportaría nada.
///
/// Uso:
///   await OnboardingTerritorioSheet.mostrar(context);
/// Siempre marca el onboarding como completo al cerrarse — elija o
/// salte el usuario. No volverá a aparecer en siguientes arranques.
class OnboardingTerritorioSheet extends ConsumerStatefulWidget {
  const OnboardingTerritorioSheet({super.key});

  static Future<void> mostrar(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (_) => const OnboardingTerritorioSheet(),
    );
  }

  @override
  ConsumerState<OnboardingTerritorioSheet> createState() => _EstadoOnboarding();
}

class _EstadoOnboarding extends ConsumerState<OnboardingTerritorioSheet> {
  String _clavePreseleccionada = '';

  Future<void> _confirmar() async {
    final notifier = ref.read(preferenciasProvider.notifier);
    if (_clavePreseleccionada.isNotEmpty) {
      await notifier.establecerTerritorioBase(_clavePreseleccionada);
    }
    await notifier.marcarOnboardingCompleto();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saltar() async {
    await ref.read(preferenciasProvider.notifier).marcarOnboardingCompleto();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final opciones = TerritoryNormalizer.listarOpcionesCuradas();

    final porGrupo = <String, List<TerritoryOption>>{};
    for (final opcion in opciones) {
      porGrupo.putIfAbsent(opcion.grupo, () => []).add(opcion);
    }

    final altoPantalla = MediaQuery.of(context).size.height;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: altoPantalla * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place_outlined, color: esquema.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          textos.onboardingTerritoryTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    textos.onboardingTerritoryBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  RadioListTile<String>(
                    value: '',
                    groupValue: _clavePreseleccionada,
                    title: Text(textos.settingsMyTerritoryNone),
                    onChanged: (valor) =>
                        setState(() => _clavePreseleccionada = valor ?? ''),
                  ),
                  for (final entrada in porGrupo.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        entrada.key,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: esquema.primary,
                            ),
                      ),
                    ),
                    for (final opcion in entrada.value)
                      RadioListTile<String>(
                        value: opcion.clave,
                        groupValue: _clavePreseleccionada,
                        title: Text(opcion.etiqueta),
                        onChanged: (valor) =>
                            setState(() => _clavePreseleccionada = valor ?? ''),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saltar,
                    child: Text(textos.onboardingTerritorySkip),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _confirmar,
                    child: Text(textos.onboardingTerritoryConfirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
