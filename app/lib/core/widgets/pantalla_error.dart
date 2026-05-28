import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../services/registro_errores.dart';

/// Textos de las pantallas de error. No pueden depender de `AppLocalizations`
/// porque un fallo de arranque puede ocurrir antes de que el `MaterialApp`
/// monte sus delegates. Resolvemos a mano contra el idioma del sistema, con
/// castellano como respaldo (idioma principal del proyecto).
class _TextosError {
  const _TextosError({
    required this.titulo,
    required this.cuerpo,
    required this.compartir,
    required this.reintentar,
  });

  final String titulo;
  final String cuerpo;
  final String compartir;
  final String reintentar;

  static _TextosError delSistema() {
    final idioma = ui.PlatformDispatcher.instance.locale.languageCode;
    return _porIdioma[idioma] ?? _porIdioma['es']!;
  }

  static const Map<String, _TextosError> _porIdioma = {
    'es': _TextosError(
      titulo: 'Algo ha fallado',
      cuerpo: 'La app encontró un problema inesperado. Puedes compartir un informe '
          'para ayudar a arreglarlo; no se envía nada automáticamente.',
      compartir: 'Compartir informe',
      reintentar: 'Reintentar',
    ),
    'ca': _TextosError(
      titulo: 'Alguna cosa ha fallat',
      cuerpo: 'L\'app ha trobat un problema inesperat. Pots compartir un informe '
          'per ajudar a arreglar-ho; no s\'envia res automàticament.',
      compartir: 'Comparteix l\'informe',
      reintentar: 'Torna-ho a provar',
    ),
    'eu': _TextosError(
      titulo: 'Zerbaitek huts egin du',
      cuerpo: 'Aplikazioak ustekabeko arazo bat aurkitu du. Txosten bat parteka '
          'dezakezu konpontzen laguntzeko; ez da ezer automatikoki bidaltzen.',
      compartir: 'Partekatu txostena',
      reintentar: 'Saiatu berriro',
    ),
    'gl': _TextosError(
      titulo: 'Algo fallou',
      cuerpo: 'A app atopou un problema inesperado. Podes compartir un informe '
          'para axudar a arranxalo; non se envía nada automaticamente.',
      compartir: 'Compartir informe',
      reintentar: 'Tentar de novo',
    ),
    'en': _TextosError(
      titulo: 'Something went wrong',
      cuerpo: 'The app hit an unexpected problem. You can share a report to help '
          'fix it; nothing is sent automatically.',
      compartir: 'Share report',
      reintentar: 'Retry',
    ),
  };
}

/// Comparte el último informe registrado, añadiéndole versión y plataforma.
Future<void> compartirUltimoInforme() async {
  final informe = await RegistroErrores.instancia.leerUltimo();
  if (informe == null) return;
  String version = '?';
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {
    // Sin versión disponible compartimos igualmente el resto del informe.
  }
  final texto = informe.comoTextoCompartible(
    version: version,
    plataforma: defaultTargetPlatform.name,
  );
  await Share.share(texto);
}

/// Reemplazo sobrio del recuadro rojo por defecto de Flutter. Se instala en
/// `ErrorWidget.builder`. Cubre el área del widget que falló sin tumbar el
/// resto de la app; en release no muestra la traza, solo un aviso discreto.
class WidgetErrorSobrio extends StatelessWidget {
  const WidgetErrorSobrio({super.key, required this.detalles});

  final FlutterErrorDetails detalles;

  @override
  Widget build(BuildContext context) {
    final textos = _TextosError.delSistema();
    final esquema = Theme.of(context).colorScheme;
    return Container(
      color: esquema.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: esquema.error, size: 40),
          const SizedBox(height: 12),
          Text(
            textos.titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// App mínima que se monta cuando el arranque peta por completo (el catch de
/// `runZonedGuarded` en `main`). Evita la pantalla negra: muestra el aviso,
/// permite compartir el informe y reintentar el arranque.
class AppErrorArranque extends StatelessWidget {
  const AppErrorArranque({super.key, required this.alReintentar});

  /// Vuelve a ejecutar la secuencia de arranque.
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final textos = _TextosError.delSistema();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  textos.titulo,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(textos.cuerpo, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: compartirUltimoInforme,
                  icon: const Icon(Icons.share_outlined),
                  label: Text(textos.compartir),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: alReintentar,
                  child: Text(textos.reintentar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
