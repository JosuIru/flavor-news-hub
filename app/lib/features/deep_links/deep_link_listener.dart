import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/api_provider.dart';
import '../radios/data/reproductor_radio_notifier.dart';

/// Escucha deep-links `flavornews://…` emitidos por los widgets Android y
/// ejecuta la acción correspondiente dentro de la app.
///
/// Patrón soportado en v1:
///   flavornews://radios/play/<id>  → navega a /audio y arranca esa radio
///
/// Se registra una sola vez al arrancar la app. El canal nativo vive en
/// `MainActivity.kt` y expone dos caminos: `getInitial` para cold-start y
/// `onLink` como callback para foreground.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _EstadoDeepLink();
}

class _EstadoDeepLink extends ConsumerState<DeepLinkListener> {
  static const _canal = MethodChannel('fnh/deeplink');
  bool _yaProcesadoInicial = false;

  @override
  void initState() {
    super.initState();
    _canal.setMethodCallHandler((call) async {
      if (call.method == 'onLink' && call.arguments is String) {
        _procesar(call.arguments as String);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarInicial());
  }

  Future<void> _cargarInicial() async {
    if (_yaProcesadoInicial) return;
    _yaProcesadoInicial = true;
    try {
      final inicial = await _canal.invokeMethod<String?>('getInitial');
      if (inicial != null) {
        _procesar(inicial);
      }
    } on PlatformException {
      // Sin canal (p. ej. en hot-restart) — ignoramos silenciosamente.
    }
  }

  void _procesar(String uriRaw) {
    final uri = Uri.tryParse(uriRaw);
    if (uri == null || uri.scheme != 'flavornews') return;

    // Ruta `radios/play/<id>`: uri.host == 'radios'; uri.path == '/play/<id>'
    if (uri.host == 'radios') {
      final segmentos = uri.pathSegments;
      if (segmentos.length == 2 && segmentos[0] == 'play') {
        final idRadio = int.tryParse(segmentos[1]);
        if (idRadio != null) {
          _lanzarRadio(idRadio);
          return;
        }
      }
    }
  }

  Future<void> _lanzarRadio(int idRadio) async {
    // Navegamos a /audio y, cuando el directorio de radios esté cargado,
    // buscamos la radio y arrancamos su stream.
    if (!mounted) return;
    GoRouter.of(context).go('/audio');
    // Esperamos al siguiente frame antes de pedir el provider: si la app
    // arranca fría, `radiosProvider` puede tardar en resolverse.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final radios = await ref.read(radiosProvider.future);
      final radio = radios.firstWhere(
        (r) => r.id == idRadio,
        orElse: () => radios.first,
      );
      if (radio.id != idRadio) return; // no existe en esta instancia.
      if (!mounted) return;
      await ref.read(reproductorRadioProvider.notifier).alternar(radio);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
