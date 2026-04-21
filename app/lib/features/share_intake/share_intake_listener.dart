import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Escucha intents SEND text/plain que llegan desde otras apps
/// ("Compartir → Flavor News Hub") y, si detecta una URL http(s), navega
/// al formulario de proponer medio con el campo pre-rellenado.
///
/// Se registra una sola vez, cuando la app arranca. Gestiona tanto el
/// cold-start (`getInitialMedia`) como los recibidos con la app ya abierta
/// (`getMediaStream`).
class ShareIntakeListener extends ConsumerStatefulWidget {
  const ShareIntakeListener({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<ShareIntakeListener> createState() => _EstadoShareIntake();
}

class _EstadoShareIntake extends ConsumerState<ShareIntakeListener> {
  StreamSubscription<List<SharedMediaFile>>? _subscripcionStream;
  bool _intakeProcesadoInicial = false;

  @override
  void initState() {
    super.initState();
    _registrarListeners();
  }

  void _registrarListeners() {
    // Cold-start: llega con la app recién abierta.
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (_intakeProcesadoInicial) return;
      _intakeProcesadoInicial = true;
      _procesarMedios(media);
      // Imprescindible: si no llamamos a reset, el mismo intent vuelve a
      // dispararse la próxima vez que se pida `getInitialMedia` (p. ej.
      // tras un hot-reload).
      ReceiveSharingIntent.instance.reset();
    });
    // Foreground: con la app ya abierta.
    _subscripcionStream = ReceiveSharingIntent.instance.getMediaStream().listen(_procesarMedios);
  }

  void _procesarMedios(List<SharedMediaFile> medios) {
    if (!mounted || medios.isEmpty) return;
    for (final media in medios) {
      final texto = media.path;
      final url = _primeraUrlDeTexto(texto);
      if (url != null) {
        // Esperamos al siguiente frame para asegurarnos de que el router
        // está montado — en cold-start el callback puede llegar antes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          GoRouter.of(context).push('/sources/submit?url=${Uri.encodeQueryComponent(url)}');
        });
        return;
      }
    }
  }

  /// Extrae la primera URL http(s) de una cadena. Los shares desde Twitter
  /// y algunos navegadores pegan texto+URL juntos; aquí sacamos sólo el
  /// enlace.
  String? _primeraUrlDeTexto(String texto) {
    final match = RegExp(r'https?://\S+').firstMatch(texto);
    return match?.group(0);
  }

  @override
  void dispose() {
    _subscripcionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
