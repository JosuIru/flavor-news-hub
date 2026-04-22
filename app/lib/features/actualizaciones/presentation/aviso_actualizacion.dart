import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/preferences_provider.dart';
import '../data/actualizaciones_provider.dart';

/// Widget invisible que dispara un diálogo cuando el backend anuncia
/// una actualización del APK. Se monta cerca del root de la app para
/// que la detección sea temprana. Mientras se resuelve el provider no
/// hace nada (el AsyncValue.loading queda en silencio).
///
/// Diálogo:
///  - Título: "Nueva versión X disponible"
///  - Cuerpo: changelog
///  - Acciones: "Descargar" (abre URL en navegador) y "Ahora no" (salvo
///    actualizaciones marcadas como `[mandatory]` en la release).
class AvisoActualizacion extends ConsumerStatefulWidget {
  const AvisoActualizacion({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AvisoActualizacion> createState() => _EstadoAvisoActualizacion();
}

class _EstadoAvisoActualizacion extends ConsumerState<AvisoActualizacion> {
  bool _mostrado = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<EstadoActualizacion>>(actualizacionProvider,
        (prev, next) {
      next.whenData((estado) {
        if (!estado.hayActualizacion || _mostrado || !mounted) return;
        _mostrado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mostrarDialogo(context, ref, estado);
        });
      });
    });
    return widget.child;
  }

  Future<void> _mostrarDialogo(
    BuildContext context,
    WidgetRef ref,
    EstadoActualizacion estado,
  ) async {
    final textos = AppLocalizations.of(context);
    final urlDescarga = estado.urlDescarga ?? '';
    final changelog = (estado.changelog ?? '').trim();
    await showDialog<void>(
      context: context,
      barrierDismissible: !estado.esObligatoria,
      builder: (ctx) => AlertDialog(
        title: Text(textos.updateTitle(estado.versionRemota ?? '')),
        content: SingleChildScrollView(
          child: Text(
            changelog.isEmpty ? textos.updateBodyGeneric : changelog,
          ),
        ),
        actions: [
          if (!estado.esObligatoria)
            TextButton(
              onPressed: () {
                final version = estado.versionRemota;
                if (version != null && version.isNotEmpty) {
                  final prefs = ref.read(sharedPreferencesProvider);
                  descartarActualizacion(prefs, version);
                }
                Navigator.of(ctx).pop();
              },
              child: Text(textos.updateDismiss),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: Text(textos.updateDownload),
            onPressed: () async {
              if (urlDescarga.isNotEmpty) {
                final uri = Uri.tryParse(urlDescarga);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
