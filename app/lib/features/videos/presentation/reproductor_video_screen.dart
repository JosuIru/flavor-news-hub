import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/models/item.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/pip_service.dart';
import '../../feed/presentation/item_detail_screen.dart';
import '../../history/data/historial_provider.dart';
import '../data/url_video_helper.dart';
import '../data/videos_provider.dart';

/// Origen que YouTube valida en los postMessage del IFrame Player API.
/// Debe ser scheme+host del dominio que controla la app.
///
/// Si alguna vez cambia el dominio oficial (urlInstanciaOficialDefault en
/// preferences_provider.dart), actualiza también esta constante — el assert
/// de _crearControladorYoutube lo recordará en debug.
const _kOrigenEmbedYoutube = 'https://flavor.gailu.it';

/// Reproductor in-app.
///
/// - **YouTube**: HTML propio con la IFrame Player API oficial. Un
///   JavaScriptChannel notifica cuando el vídeo termina y la pantalla
///   navega al siguiente de la lista filtrada (autoplay).
/// - **PeerTube**: embed en WebView. Sin autoplay (cross-origin iframe),
///   pero hay botón manual "Siguiente".
/// - **URL no reconocida**: delega al navegador externo.
class ReproductorVideoScreen extends ConsumerStatefulWidget {
  const ReproductorVideoScreen({required this.idItem, super.key});
  final String idItem;

  @override
  ConsumerState<ReproductorVideoScreen> createState() => _EstadoReproductorVideo();
}

class _EstadoReproductorVideo extends ConsumerState<ReproductorVideoScreen> {
  WebViewController? _controller;
  String? _codigoErrorPlayer;
  bool _enPip = false;
  StreamSubscription<bool>? _suscripcionPip;

  @override
  void initState() {
    super.initState();
    // Mientras el usuario está en el reproductor, habilitamos el auto-PiP:
    // si pulsa Home, la activity nativa se pone en modo PiP y el vídeo
    // sigue reproduciéndose en una ventana flotante.
    PipService.activar(true);
    _suscripcionPip = PipService.cambiosDeModo.listen((enPip) {
      if (!mounted) return;
      setState(() => _enPip = enPip);
      if (enPip) {
        // Al perder foco por la transición a PiP, el <video> HTML5 del
        // WebView se pausa; lo forzamos a reanudar vía la IFrame API.
        _reanudarReproduccionYoutube();
      }
    });
  }

  Future<void> _reanudarReproduccionYoutube() async {
    // Pequeño retardo para que la transición a PiP termine y el WebView
    // pueda procesar JS. Reintentamos por si el primer intento cae antes.
    for (final retrasoMs in const [120, 400, 900]) {
      await Future<void>.delayed(Duration(milliseconds: retrasoMs));
      if (!mounted || _controller == null) return;
      try {
        await _controller!.runJavaScript(
          'if (typeof player !== "undefined" && player.playVideo) '
          'player.playVideo();',
        );
      } catch (_) {
        // runJavaScript falla si el WebView aún no está listo; seguimos.
      }
    }
  }

  @override
  void dispose() {
    _suscripcionPip?.cancel();
    PipService.activar(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final idNumerico = int.tryParse(widget.idItem) ?? 0;
    final asyncItem = ref.watch(itemDetalleProvider(idNumerico));

    // Un único Scaffold: al cambiar a PiP sólo alternamos AppBar y el
    // panel de detalle. Mantenemos el WebViewWidget en la misma posición
    // del árbol para que no se recree al entrar/salir de la ventana PiP
    // (si se recreara, YouTube cargaría desde cero y perdería la posición).
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _enPip
          ? null
          : AppBar(
              title: Text(textos.videosTitle),
              actions: [
                asyncItem.maybeWhen(
                  data: (item) {
                    final utiles = ref.watch(utilesProvider).valueOrNull ??
                        const <int>{};
                    final esUtil = utiles.contains(item.id);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(esUtil
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline),
                          tooltip: esUtil
                              ? textos.itemUnmarkUseful
                              : textos.itemMarkUseful,
                          onPressed: () => ref
                              .read(utilesProvider.notifier)
                              .alternar(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          tooltip: textos.videosPlayNext,
                          onPressed: () => _saltarAlSiguiente(item),
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
      body: asyncItem.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (item) => _construirCuerpo(item),
      ),
    );
  }

  Widget _construirCuerpo(Item item) {
    final urlOriginal = item.originalUrl;
    final idYoutube = _idYoutubeDesdeItem(item);
    final embedPeerTube =
        idYoutube == null ? UrlVideoHelper.embedPeerTube(urlOriginal) : null;
    debugPrint(
      '[ReproductorVideo] itemId=${item.id} url=$urlOriginal '
      'feedType=${item.source?.feedType} idYT=$idYoutube '
      'peertube=$embedPeerTube',
    );

    if (idYoutube == null && embedPeerTube == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uri = Uri.tryParse(urlOriginal);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) context.pop();
      });
      return const Center(child: CircularProgressIndicator());
    }

    _controller ??= idYoutube != null
        ? _crearControladorYoutube(idYoutube)
        : _crearControladorGenerico(embedPeerTube!);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: _codigoErrorPlayer != null
                ? _panelErrorYoutube(item)
                : WebViewWidget(controller: _controller!),
          ),
        ),
        // En PiP ocultamos el detalle (la ventana 16:9 ya la llena el
        // AspectRatio de arriba). No lo quitamos del árbol para evitar
        // tocar la posición del WebViewWidget.
        Expanded(
          child: _enPip
              ? const SizedBox.shrink()
              : _DetalleVideo(item: item, esYoutube: idYoutube != null),
        ),
      ],
    );
  }

  String? _idYoutubeDesdeItem(Item item) {
    final embed = UrlVideoHelper.embedYoutube(item.originalUrl);
    if (embed == null) return null;
    final match = RegExp(r'/embed/([A-Za-z0-9_-]{11})').firstMatch(embed);
    return match?.group(1);
  }

  WebViewController _crearControladorYoutube(String idYoutube) {
    const origenEmbed = _kOrigenEmbedYoutube;
    assert(
      urlInstanciaOficialDefault.startsWith(origenEmbed),
      '\n⚠️  El dominio de urlInstanciaOficialDefault ha cambiado pero '
      '_kOrigenEmbedYoutube sigue apuntando a "$origenEmbed".\n'
      '   Actualiza _kOrigenEmbedYoutube en reproductor_video_screen.dart '
      'para que coincida con el nuevo dominio, o los postMessage de la '
      'IFrame Player API de YouTube dejarán de funcionar.',
    );
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'VideoFinished',
        onMessageReceived: (mensaje) {
          if (mensaje.message == 'ended') {
            _alTerminarVideo();
          }
        },
      )
      ..addJavaScriptChannel(
        'PlayerError',
        onMessageReceived: (mensaje) {
          if (!mounted) return;
          setState(() => _codigoErrorPlayer = mensaje.message);
        },
      )
      // `baseUrl` debe ser HTTPS y NO puede ser youtube.com (el player
      // rechaza que youtube.com se embeba a sí mismo). `origin` debe
      // coincidir con el baseUrl para que YouTube valide el postMessage.
      ..loadHtmlString(
        _htmlPlayerYoutube(idYoutube, origenEmbed),
        baseUrl: '$origenEmbed/',
      );
  }

  WebViewController _crearControladorGenerico(String urlEmbed) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final host = Uri.tryParse(req.url)?.host ?? '';
          final hostEmbed = Uri.tryParse(urlEmbed)?.host ?? '';
          if (host.isNotEmpty && host != hostEmbed) {
            launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(urlEmbed));
  }

  void _alTerminarVideo() {
    final idNumerico = int.tryParse(widget.idItem) ?? 0;
    final item = ref.read(itemDetalleProvider(idNumerico)).valueOrNull;
    if (item != null) _saltarAlSiguiente(item);
  }

  void _saltarAlSiguiente(Item itemActual) {
    final lista = ref.read(videosProvider).valueOrNull;
    if (lista == null || lista.isEmpty) return;
    final indice = lista.indexWhere((i) => i.id == itemActual.id);
    if (indice < 0 || indice >= lista.length - 1) return;
    final siguiente = lista[indice + 1];
    if (siguiente.id <= 0) return; // personales no tienen endpoint
    if (!mounted) return;
    GoRouter.of(context).pushReplacement('/videos/play/${siguiente.id}');
  }

  /// HTML con la IFrame Player API oficial de YouTube. `onStateChange`
  /// detecta `ENDED` para autoplay, `onError` captura el código real que
  /// devuelve el player (2/5/100/101/150) para mostrar fallback.
  String _htmlPlayerYoutube(String idYoutube, String origenEmbed) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin:0; padding:0; background:#000; width:100%; height:100%; overflow:hidden; }
  #player { width:100%; height:100%; }
</style>
</head>
<body>
<div id="player"></div>
<script>
  var tag = document.createElement('script');
  tag.src = "https://www.youtube.com/iframe_api";
  document.body.appendChild(tag);
  var player;
  function onYouTubeIframeAPIReady() {
    player = new YT.Player('player', {
      width: '100%', height: '100%',
      videoId: '$idYoutube',
      playerVars: {
        rel: 0,
        modestbranding: 1,
        playsinline: 1,
        autoplay: 1,
        enablejsapi: 1,
        origin: '$origenEmbed'
      },
      events: {
        onStateChange: function(e) {
          if (e.data === YT.PlayerState.ENDED && window.VideoFinished) {
            VideoFinished.postMessage('ended');
          }
        },
        onError: function(e) {
          if (window.PlayerError) {
            PlayerError.postMessage(String(e.data));
          }
        }
      }
    });
  }
</script>
</body>
</html>
''';
  }

  Widget _panelErrorYoutube(Item item) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            Text(
              'YouTube rechazó la reproducción embebida (código $_codigoErrorPlayer).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir en YouTube'),
              onPressed: () async {
                final uri = Uri.tryParse(item.originalUrl);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel inferior del reproductor: título, medio, fecha, duración, descripción
/// HTML saneada y acciones (ver en plataforma original, web del canal,
/// compartir). Los comentarios no se integran in-app — sería atar la app a
/// las APIs cerradas de YouTube y violaría el principio de no-tracking; en
/// lugar de eso, el botón "Ver en YouTube/PeerTube" lleva donde sí viven.
class _DetalleVideo extends StatelessWidget {
  const _DetalleVideo({required this.item, required this.esYoutube});

  final Item item;
  final bool esYoutube;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final timestampPublicacion = DateTime.tryParse(item.publishedAt);
    final fechaFormateada = timestampPublicacion != null
        ? DateFormat.yMMMMd(localeCodigo).format(timestampPublicacion.toLocal())
        : '';
    final duracionFormateada = _formatearDuracion(item.durationSeconds);
    final nombrePlataforma = esYoutube
        ? textos.videoPlatformYoutube
        : (UrlVideoHelper.embedPeerTube(item.originalUrl) != null
            ? textos.videoPlatformPeertube
            : textos.videoPlatformExternal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 10),
          _LineaMeta(
            nombreMedio: item.source?.name,
            fechaHumana: fechaFormateada,
            duracion: duracionFormateada,
            onSourceTap: item.source != null
                ? () => GoRouter.of(context).push('/sources/${item.source!.id}')
                : null,
          ),
          if (item.topics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final topic in item.topics)
                  Chip(
                    label: Text(topic.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (item.originalUrl.isNotEmpty)
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      textos.videoOpenExternal(nombrePlataforma),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _abrirUrl(item.originalUrl),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: textos.itemShare,
                onPressed: () async {
                  final textoCompartir = item.originalUrl.isNotEmpty
                      ? '${item.title}\n${item.originalUrl}'
                      : item.title;
                  await Share.share(textoCompartir);
                },
                icon: const Icon(Icons.share),
              ),
            ],
          ),
          if (item.source != null && item.source!.websiteUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.public),
                label: Text(textos.videoChannelWebsite),
                onPressed: () => _abrirUrl(item.source!.websiteUrl),
              ),
            ),
          ],
          if (_tieneDescripcionUtil(item.excerpt)) ...[
            const SizedBox(height: 18),
            Text(
              textos.videoDescription,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            HtmlWidget(
              item.excerpt,
              textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              onTapUrl: (url) async {
                final uri = Uri.tryParse(url);
                if (uri == null) return false;
                return launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
          ],
          const SizedBox(height: 18),
          Text(
            textos.videoCommentsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Excluye descripciones vacías o sólo con whitespace/entidades.
  bool _tieneDescripcionUtil(String excerpt) {
    if (excerpt.trim().isEmpty) return false;
    final sinTags = excerpt.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return sinTags.isNotEmpty;
  }
}

class _LineaMeta extends StatelessWidget {
  const _LineaMeta({
    required this.nombreMedio,
    required this.fechaHumana,
    required this.duracion,
    required this.onSourceTap,
  });

  final String? nombreMedio;
  final String fechaHumana;
  final String duracion;
  final VoidCallback? onSourceTap;

  @override
  Widget build(BuildContext context) {
    final colorSec = Theme.of(context).colorScheme.onSurfaceVariant;
    final estilo = Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorSec);
    final piezas = <Widget>[];
    if (nombreMedio != null && nombreMedio!.isNotEmpty) {
      piezas.add(InkWell(
        onTap: onSourceTap,
        child: Text(
          nombreMedio!,
          style: estilo?.copyWith(fontWeight: FontWeight.w600),
        ),
      ));
    }
    if (fechaHumana.isNotEmpty) {
      if (piezas.isNotEmpty) piezas.add(Text(' · ', style: estilo));
      piezas.add(Text(fechaHumana, style: estilo));
    }
    if (duracion.isNotEmpty) {
      if (piezas.isNotEmpty) piezas.add(Text(' · ', style: estilo));
      piezas.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: colorSec),
          const SizedBox(width: 4),
          Text(duracion, style: estilo),
        ],
      ));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: piezas,
    );
  }
}

/// Formato MM:SS o H:MM:SS. Vacío si no hay duración (0 significa
/// "no conocida" — muchos feeds no la exponen).
String _formatearDuracion(int segundos) {
  if (segundos <= 0) return '';
  final horas = segundos ~/ 3600;
  final minutos = (segundos % 3600) ~/ 60;
  final segs = segundos % 60;
  final dosDig = (int n) => n.toString().padLeft(2, '0');
  if (horas > 0) return '$horas:${dosDig(minutos)}:${dosDig(segs)}';
  return '$minutos:${dosDig(segs)}';
}
