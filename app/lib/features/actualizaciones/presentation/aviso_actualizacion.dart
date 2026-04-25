import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../data/actualizaciones_provider.dart';

/// Widget invisible que dispara un diálogo cuando el backend anuncia
/// una actualización del APK. Se monta cerca del root de la app para
/// que la detección sea temprana. Mientras se resuelve el provider no
/// hace nada (el AsyncValue.loading queda en silencio).
///
/// Flujo al pulsar "Actualizar":
///  1. Descarga el APK a cacheDir (path_provider.getTemporaryDirectory).
///  2. Lanza el instalador del sistema vía FileProvider + open_filex.
///  3. Android pide confirmación al usuario (no se puede saltar fuera
///     de Google Play) y continúa la instalación.
///
/// Fallback: si la descarga o el instalador fallan, abre la URL en
/// navegador externo (flujo antiguo). Así nunca nos quedamos sin
/// camino para actualizar.
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
    ref.listen<AsyncValue<EstadoActualizacion>>(actualizacionProvider(false),
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
              Navigator.of(ctx).pop();
              if (urlDescarga.isEmpty) return;
              await _descargarEInstalar(
                context: context,
                ref: ref,
                url: urlDescarga,
                version: estado.versionRemota ?? '',
                textos: textos,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Descarga el APK y lanza el instalador. En iOS / desktop no aplica
  /// — abrimos la URL en navegador. Si la descarga falla por red, también
  /// caemos al navegador para no dejar al usuario sin camino.
  Future<void> _descargarEInstalar({
    required BuildContext context,
    required WidgetRef ref,
    required String url,
    required String version,
    required AppLocalizations textos,
  }) async {
    if (!Platform.isAndroid) {
      await _abrirEnNavegador(url);
      return;
    }

    final progresoController = ValueNotifier<double?>(0.0);
    final claveDialogo = GlobalKey<NavigatorState>();

    final dialogoProgreso = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(textos.updateDownloadingTitle),
        content: ValueListenableBuilder<double?>(
          valueListenable: progresoController,
          builder: (_, valor, __) => SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: valor),
                const SizedBox(height: 12),
                Text(
                  valor == null
                      ? textos.updateDownloadingIndeterminate
                      : '${((valor) * 100).round()} %',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    File? apk;
    try {
      apk = await _descargarAPK(
        ref: ref,
        url: url,
        version: version,
        onProgreso: (recibido, total) {
          if (total > 0) {
            progresoController.value = recibido / total;
          } else {
            progresoController.value = null;
          }
        },
      );
    } catch (e) {
      debugPrint('[AvisoActualizacion] descarga falló: $e');
    }

    if (mounted && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogoProgreso;
    progresoController.dispose();
    // Evita warning de unused key en debug builds.
    claveDialogo.currentContext;

    if (apk == null) {
      if (context.mounted) {
        _mostrarSnack(context, textos.updateDownloadFallback);
      }
      await _abrirEnNavegador(url);
      return;
    }

    final resultado = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (resultado.type != ResultType.done) {
      debugPrint(
        '[AvisoActualizacion] OpenFilex error: '
        '${resultado.type} — ${resultado.message}',
      );
      if (context.mounted) {
        _mostrarSnack(context, textos.updateInstallFallback);
      }
      await _abrirEnNavegador(url);
    }
    // Nota: si Android niega `REQUEST_INSTALL_PACKAGES` al usuario, el
    // intent lo redirige a Ajustes → "Instalar aplicaciones desconocidas".
    // Tras permitir, volverá aquí y open_filex se resolverá en un
    // siguiente intento — no nos toca gestionarlo.
  }

  Future<File> _descargarAPK({
    required WidgetRef ref,
    required String url,
    required String version,
    required void Function(int recibido, int total) onProgreso,
  }) async {
    final cliente = ref.read(httpClientProvider);
    final dirCache = await getTemporaryDirectory();
    // Versión en el nombre para que descargas antiguas no "se acumulen"
    // indistinguibles; si existe una con el mismo nombre, la sobrescribimos.
    final sufijo = version.isEmpty ? 'latest' : version.replaceAll('/', '_');
    final ruta = '${dirCache.path}/flavor-news-hub-$sufijo.apk';
    final archivo = File(ruta);
    if (await archivo.exists()) {
      await archivo.delete();
    }

    final peticion = http.Request('GET', Uri.parse(url));
    final respuesta = await cliente.send(peticion);
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw Exception('HTTP ${respuesta.statusCode}');
    }
    final total = respuesta.contentLength ?? 0;
    int recibido = 0;
    final sink = archivo.openWrite();
    await respuesta.stream.listen((chunk) {
      recibido += chunk.length;
      sink.add(chunk);
      onProgreso(recibido, total);
    }).asFuture<void>();
    await sink.flush();
    await sink.close();
    return archivo;
  }

  Future<void> _abrirEnNavegador(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _mostrarSnack(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }
}
