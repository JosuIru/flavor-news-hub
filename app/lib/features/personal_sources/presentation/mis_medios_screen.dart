import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_provider.dart';
import '../data/descubridor_feeds.dart';
import '../data/fuente_personal.dart';
import '../data/fuentes_personales_notifier.dart';

/// Gestión local de fuentes que el usuario añade por su cuenta.
/// Las URLs nunca salen del dispositivo: la app parsea cada RSS directamente
/// y los items se mezclan con los del feed común.
class MisMediosScreen extends ConsumerWidget {
  const MisMediosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final fuentes = ref.watch(fuentesPersonalesProvider);
    final notifier = ref.read(fuentesPersonalesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.personalSourcesTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (accion) => _ejecutarAccionMenu(context, notifier, accion, textos),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'export', child: Text(textos.personalSourcesExport)),
              PopupMenuItem(value: 'import', child: Text(textos.personalSourcesImport)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'export_opml', child: Text(textos.opmlExport)),
              PopupMenuItem(value: 'import_opml', child: Text(textos.opmlImport)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirDialogoAnadir(context, notifier, textos),
        icon: const Icon(Icons.add),
        label: Text(textos.personalSourcesAdd),
      ),
      body: fuentes.isEmpty
          ? _EstadoVacio(textos: textos)
          : _construirListaAgrupada(context, fuentes, notifier, textos),
    );
  }

  /// Agrupa las fuentes en tres secciones — Lectura, Audio, Vídeo — con
  /// cabecera propia. Dentro de cada sección el orden es el de adición.
  Widget _construirListaAgrupada(
    BuildContext context,
    List<FuentePersonal> fuentes,
    FuentesPersonalesNotifier notifier,
    AppLocalizations textos,
  ) {
    final lectura = <FuentePersonal>[];
    final audio = <FuentePersonal>[];
    final video = <FuentePersonal>[];
    for (final f in fuentes) {
      switch (_categoriaDeTipo(f.tipoFeed)) {
        case _Categoria.audio:
          audio.add(f);
        case _Categoria.video:
          video.add(f);
        case _Categoria.lectura:
          lectura.add(f);
      }
    }

    final esquema = Theme.of(context).colorScheme;
    final bloques = <Widget>[];
    void anadirSeccion(String titulo, List<FuentePersonal> lista, IconData iconoSeccion) {
      if (lista.isEmpty) return;
      bloques.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Icon(iconoSeccion, size: 18, color: esquema.primary),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: esquema.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ));
      for (final fuente in lista) {
        bloques.add(ListTile(
          leading: Icon(_iconoDeTipo(fuente.tipoFeed)),
          title: Text(fuente.nombre),
          subtitle: Text(fuente.feedUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: textos.personalSourcesRemove,
            onPressed: () => _confirmarBorrado(context, notifier, fuente, textos),
          ),
        ));
      }
    }

    anadirSeccion(textos.personalSourcesCategoryReading, lectura, Icons.menu_book_outlined);
    anadirSeccion(textos.personalSourcesCategoryAudio, audio, Icons.podcasts);
    anadirSeccion(textos.personalSourcesCategoryVideo, video, Icons.play_circle_outline);

    bloques.add(Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        textos.personalSourcesNote,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: esquema.onSurfaceVariant,
            ),
      ),
    ));

    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // espacio para el FAB
      children: bloques,
    );
  }

  _Categoria _categoriaDeTipo(String tipo) {
    switch (tipo) {
      case 'podcast':
        return _Categoria.audio;
      case 'youtube':
      case 'video':
        return _Categoria.video;
      default:
        return _Categoria.lectura;
    }
  }

  IconData _iconoDeTipo(String tipo) {
    switch (tipo) {
      case 'youtube':
        return Icons.play_circle_outline;
      case 'video':
        return Icons.videocam_outlined;
      case 'podcast':
        return Icons.mic_outlined;
      case 'atom':
        return Icons.rss_feed;
      case 'mastodon':
        return Icons.forum_outlined;
      default:
        return Icons.rss_feed;
    }
  }

  Future<void> _abrirDialogoAnadir(
    BuildContext context,
    FuentesPersonalesNotifier notifier,
    AppLocalizations textos,
  ) async {
    final resultado = await showDialog<FuentePersonal>(
      context: context,
      builder: (_) => _DialogoAnadirFuente(textos: textos),
    );
    if (resultado == null) return;
    final anadida = await notifier.anadir(resultado);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(anadida
          ? textos.personalSourcesAddedSnackbar
          : textos.personalSourcesAlreadyExists),
    ));
  }

  Future<void> _confirmarBorrado(
    BuildContext context,
    FuentesPersonalesNotifier notifier,
    FuentePersonal fuente,
    AppLocalizations textos,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(textos.personalSourcesRemoveTitle),
        content: Text(fuente.nombre),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(textos.commonCancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textos.personalSourcesRemove),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await notifier.eliminar(fuente.feedUrl);
    }
  }

  Future<void> _ejecutarAccionMenu(
    BuildContext context,
    FuentesPersonalesNotifier notifier,
    String accion,
    AppLocalizations textos,
  ) async {
    if (accion == 'export') {
      final cadena = notifier.exportarJson();
      await Clipboard.setData(ClipboardData(text: cadena));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(textos.personalSourcesExportedSnackbar),
      ));
    } else if (accion == 'import') {
      await _importarDesdePortapapeles(context, notifier, textos);
    } else if (accion == 'export_opml') {
      final cadena = notifier.exportarOpml();
      await Clipboard.setData(ClipboardData(text: cadena));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(textos.opmlExportCopied),
      ));
    } else if (accion == 'import_opml') {
      await _importarOpmlDesdeDialogo(context, notifier, textos);
    }
  }

  Future<void> _importarDesdePortapapeles(
    BuildContext context,
    FuentesPersonalesNotifier notifier,
    AppLocalizations textos,
  ) async {
    final clip = await Clipboard.getData('text/plain');
    final texto = (clip?.text ?? '').trim();
    if (texto.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.personalSourcesImportEmpty)),
      );
      return;
    }
    final cuenta = await notifier.importarJson(texto);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(cuenta < 0
          ? textos.personalSourcesImportInvalid
          : textos.personalSourcesImportedSnackbar(cuenta)),
    ));
  }

  Future<void> _importarOpmlDesdeDialogo(
    BuildContext context,
    FuentesPersonalesNotifier notifier,
    AppLocalizations textos,
  ) async {
    final controller = TextEditingController();
    // Pre-rellena con el portapapeles si parece OPML (empieza con `<?xml`
    // o `<opml`) — ahorra un paso al usuario en el caso típico.
    final clip = await Clipboard.getData('text/plain');
    final clipTexto = (clip?.text ?? '').trim();
    if (clipTexto.startsWith('<?xml') || clipTexto.startsWith('<opml')) {
      controller.text = clipTexto;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(textos.opmlImport),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: textos.opmlImportHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(textos.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textos.personalSourcesAddAction),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final texto = controller.text.trim();
    if (texto.isEmpty) return;
    final cuenta = await notifier.importarOpml(texto);
    if (!context.mounted) return;
    if (cuenta < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.personalSourcesImportInvalid)),
      );
    } else if (cuenta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.opmlImportEmpty)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.opmlImportSuccess(cuenta))),
      );
    }
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.textos});
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rss_feed, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              textos.personalSourcesEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              textos.personalSourcesEmptyHelp,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoAnadirFuente extends ConsumerStatefulWidget {
  const _DialogoAnadirFuente({required this.textos});
  final AppLocalizations textos;

  @override
  ConsumerState<_DialogoAnadirFuente> createState() => _EstadoDialogoAnadirFuente();
}

class _EstadoDialogoAnadirFuente extends ConsumerState<_DialogoAnadirFuente> {
  final _controllerNombre = TextEditingController();
  final _controllerUrl = TextEditingController();
  String _tipoFeed = 'rss';
  String? _errorUrl;
  bool _buscandoFeed = false;

  static const List<_OpcionTipo> _tipos = [
    _OpcionTipo(codigo: 'rss', etiqueta: 'RSS'),
    _OpcionTipo(codigo: 'atom', etiqueta: 'Atom'),
    _OpcionTipo(codigo: 'youtube', etiqueta: 'YouTube'),
    _OpcionTipo(codigo: 'podcast', etiqueta: 'Podcast'),
    _OpcionTipo(codigo: 'mastodon', etiqueta: 'Mastodon'),
  ];

  @override
  void dispose() {
    _controllerNombre.dispose();
    _controllerUrl.dispose();
    super.dispose();
  }

  String? _validarUrl(String valor) {
    final limpio = valor.trim();
    if (limpio.isEmpty) return widget.textos.personalSourcesRequiredUrl;
    final uri = Uri.tryParse(limpio);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return widget.textos.personalSourcesInvalidUrl;
    }
    return null;
  }

  Future<void> _buscarFeedDesdeUrl() async {
    final entrada = _controllerUrl.text.trim();
    if (entrada.isEmpty) {
      setState(() => _errorUrl = widget.textos.personalSourcesRequiredUrl);
      return;
    }

    setState(() {
      _buscandoFeed = true;
      _errorUrl = null;
    });

    try {
      final cliente = ref.read(httpClientProvider);
      final encontrados = await DescubridorFeeds.descubrir(cliente, entrada);

      if (!mounted) return;

      if (encontrados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.textos.personalSourcesDiscoverNothing),
        ));
        return;
      }

      final elegido = encontrados.length == 1
          ? encontrados.first
          : await _mostrarPickerFeeds(encontrados);
      if (elegido == null) return;

      setState(() {
        _controllerUrl.text = elegido.url;
        if (_controllerNombre.text.trim().isEmpty) {
          _controllerNombre.text = elegido.tituloSugerido;
        }
        _tipoFeed = elegido.tipoDetectado;
        _errorUrl = _validarUrl(elegido.url);
      });
    } finally {
      if (mounted) setState(() => _buscandoFeed = false);
    }
  }

  Future<FeedDescubierto?> _mostrarPickerFeeds(List<FeedDescubierto> candidatos) async {
    return showDialog<FeedDescubierto>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(widget.textos.personalSourcesDiscoverPickerTitle),
        children: [
          for (final feed in candidatos)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, feed),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feed.tituloSugerido, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    feed.url,
                    style: Theme.of(ctx).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    feed.tipoDetectado.toUpperCase(),
                    style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = widget.textos;
    return AlertDialog(
      title: Text(textos.personalSourcesAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controllerNombre,
              decoration: InputDecoration(
                labelText: '${textos.personalSourcesFieldName} *',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerUrl,
              decoration: InputDecoration(
                labelText: '${textos.personalSourcesFieldUrl} *',
                helperText: textos.personalSourcesFieldUrlHelp,
                helperMaxLines: 3,
                errorText: _errorUrl,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onChanged: (valor) => setState(() => _errorUrl = _validarUrl(valor)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _buscandoFeed ? null : _buscarFeedDesdeUrl,
                icon: _buscandoFeed
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(textos.personalSourcesDiscoverFeed),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              textos.personalSourcesFieldType,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final opcion in _tipos)
                  ChoiceChip(
                    label: Text(opcion.etiqueta),
                    selected: _tipoFeed == opcion.codigo,
                    onSelected: (_) => setState(() => _tipoFeed = opcion.codigo),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(textos.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final nombre = _controllerNombre.text.trim();
            final url = _controllerUrl.text.trim();
            final error = _validarUrl(url);
            if (nombre.isEmpty || error != null) {
              setState(() => _errorUrl = error);
              return;
            }
            Navigator.pop(context, FuentePersonal(
              nombre: nombre,
              feedUrl: url,
              tipoFeed: _tipoFeed,
              anadidaEn: DateTime.now().toUtc(),
            ));
          },
          child: Text(textos.personalSourcesAddAction),
        ),
      ],
    );
  }
}

class _OpcionTipo {
  const _OpcionTipo({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}

enum _Categoria { lectura, audio, video }
