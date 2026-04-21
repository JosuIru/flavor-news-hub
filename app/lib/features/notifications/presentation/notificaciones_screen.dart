import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferencias_notif.dart';
import '../data/servicio_notificaciones.dart';

/// Pantalla de ajustes de notificaciones: elegir con qué frecuencia la app
/// comprueba titulares nuevos en background. Sin push servers, sólo un
/// worker periódico local.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final prefs = ref.watch(preferenciasNotifProvider);

    return Scaffold(
      appBar: AppBar(title: Text(textos.notifTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              textos.notifHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final opcion in FrecuenciaNotif.values)
            RadioListTile<FrecuenciaNotif>(
              value: opcion,
              groupValue: prefs.frecuencia,
              title: Text(_etiqueta(textos, opcion)),
              onChanged: (valor) async {
                if (valor == null) return;
                await ref
                    .read(preferenciasNotifProvider.notifier)
                    .establecerFrecuencia(valor);
                await aplicarFrecuenciaNotif(valor);
              },
            ),
        ],
      ),
    );
  }

  String _etiqueta(AppLocalizations textos, FrecuenciaNotif f) {
    switch (f) {
      case FrecuenciaNotif.nunca:
        return textos.notifFreqNever;
      case FrecuenciaNotif.cadaHora:
        return textos.notifFreqHour;
      case FrecuenciaNotif.cada3h:
        return textos.notifFreq3h;
      case FrecuenciaNotif.cada6h:
        return textos.notifFreq6h;
      case FrecuenciaNotif.cada12h:
        return textos.notifFreq12h;
      case FrecuenciaNotif.cada24h:
        return textos.notifFreq24h;
    }
  }
}
