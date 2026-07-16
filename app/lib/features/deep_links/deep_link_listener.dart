import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/api_provider.dart';
import '../../core/routing/app_router.dart';
import '../radios/data/reproductor_radio_notifier.dart';

/// Escucha deep-links `flavornews://…` emitidos por los widgets Android y
/// ejecuta la acción correspondiente dentro de la app.
///
/// Patrones soportados:
///   flavornews://radios/play/<id>  → navega a /audio y arranca esa radio
///   flavornews://radios/stop       → detiene la radio que esté sonando
///   flavornews://audio             → abre /audio (tab Radios por defecto)
///   flavornews://music             → abre /music (pantalla de búsqueda federada)
///   flavornews://items/<id>        → abre el detalle de ese item
///   flavornews://search            → abre el buscador
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
    debugPrint('[DeepLink] recibido: $uriRaw');
    final uri = Uri.tryParse(uriRaw);
    if (uri == null || uri.scheme != 'flavornews') {
      debugPrint('[DeepLink] scheme inválido o URI mal formado');
      return;
    }

    // Ruta `radios/play/<id>` o `radios/stop`: uri.host == 'radios'.
    if (uri.host == 'radios') {
      final segmentos = uri.pathSegments;
      if (segmentos.length == 2 && segmentos[0] == 'play') {
        final idRadio = int.tryParse(segmentos[1]);
        if (idRadio != null) {
          _lanzarRadio(idRadio);
          return;
        }
      }
      if (segmentos.length == 1 && segmentos[0] == 'stop') {
        _detenerRadio();
        return;
      }
    }

    // Ruta `items/<id>`: desde el widget de titulares del home. Envuelto
    // en PostFrameCallback + try/catch porque en cold-start GoRouter
    // puede no estar attached todavía cuando llega el URI inicial.
    if (uri.host == 'items') {
      final segmentos = uri.pathSegments;
      if (segmentos.length == 1) {
        final idItem = int.tryParse(segmentos[0]);
        if (idItem != null) {
          // Usamos el provider del router directamente porque el
          // `DeepLinkListener` vive en el `builder` de MaterialApp.router,
          // por encima del Navigator — `GoRouter.of(context)` no lo
          // encuentra ahí.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              ref.read(enrutadorProvider).push('/items/$idItem');
            } catch (error) {
              // Cold-start: el router puede no estar attached todavía
              // cuando llega el URI inicial. Logueamos para tener pista
              // si esta rama empezara a fallar de forma sistemática.
              debugPrint('[DeepLink] push /items/$idItem falló: $error');
            }
          });
        }
      }
    }

    // Ruta `search`: desde el widget de búsqueda del home.
    if (uri.host == 'search') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.read(enrutadorProvider).push('/search');
        } catch (error) {
          debugPrint('[DeepLink] push /search falló: $error');
        }
      });
      return;
    }

    // Ruta `audio`: tap en el widget "Reproductor radio" o cabecera de
    // Favoritos cuando no hay deep-link más específico. Navega al
    // shell tab de Audio sin lanzar reproducción — el usuario ya tiene
    // el control en la app.
    if (uri.host == 'audio') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.read(enrutadorProvider).go('/audio');
        } catch (error) {
          debugPrint('[DeepLink] go /audio falló: $error');
        }
      });
      return;
    }

    // Ruta `music`: tap en el widget "Sonando" del reproductor de
    // música federada. Lleva a la pantalla full-screen `/music` (la
    // pestaña embebida `Audio→Música` también vale, pero la
    // standalone tiene mejor relación con el reproductor activo).
    if (uri.host == 'music') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          ref.read(enrutadorProvider).push('/music');
        } catch (error) {
          debugPrint('[DeepLink] push /music falló: $error');
        }
      });
      return;
    }

    // (`flavornews://refresh` se eliminó: el widget usa un broadcast
    // nativo propio para refrescar sin abrir la app.)
  }

  Future<void> _lanzarRadio(int idRadio) async {
    // Navegamos a /audio y, cuando el directorio de radios esté cargado,
    // buscamos la radio y arrancamos su stream.
    if (!mounted) return;
    ref.read(enrutadorProvider).go('/audio');
    // Esperamos al siguiente frame antes de pedir el provider: si la app
    // arranca fría, `radiosProvider` puede tardar en resolverse.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final radios = await ref.read(radiosProvider.future);
      // Catálogo vacío (backend caído y sin seed): sin guard, el
      // `orElse: () => radios.first` de abajo lanzaría StateError.
      if (radios.isEmpty) return;
      final radio = radios.firstWhere(
        (r) => r.id == idRadio,
        orElse: () => radios.first,
      );
      if (radio.id != idRadio) return; // no existe en esta instancia.
      if (!mounted) return;
      // `reproducir` (no `alternar`) porque el deep link siempre
      // significa "play esta emisora": el botón ▶ del widget no debería
      // parar la reproducción si el usuario lo pulsa con la radio ya
      // sonando — para parar tiene el botón ■ que dispara radios/stop.
      await ref.read(reproductorRadioProvider.notifier).reproducir(radio);
    });
  }

  Future<void> _detenerRadio() async {
    if (!mounted) return;
    await ref.read(reproductorRadioProvider.notifier).parar();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
