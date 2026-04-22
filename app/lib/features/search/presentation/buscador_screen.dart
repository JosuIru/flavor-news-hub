import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/item.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/models/source.dart';
import '../data/buscador_provider.dart';

/// Buscador global. Una sola caja de texto y cuatro secciones en paralelo:
/// noticias, medios, radios y colectivos. Debounced a 300ms para no
/// disparar una petición por tecla.
class BuscadorScreen extends ConsumerStatefulWidget {
  const BuscadorScreen({super.key});

  @override
  ConsumerState<BuscadorScreen> createState() => _EstadoBuscador();
}

class _EstadoBuscador extends ConsumerState<BuscadorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(consultaBusquedaProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _alCambiarTexto(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(consultaBusquedaProvider.notifier).state = valor;
    });
  }

  void _limpiar() {
    _controller.clear();
    ref.read(consultaBusquedaProvider.notifier).state = '';
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final consulta = ref.watch(consultaBusquedaProvider);
    final asyncResultados = ref.watch(resultadosBusquedaProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _alCambiarTexto,
          decoration: InputDecoration(
            hintText: textos.searchHint,
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          if (consulta.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: textos.commonClose,
              onPressed: _limpiar,
            ),
        ],
      ),
      body: _Cuerpo(
        consulta: consulta,
        asyncResultados: asyncResultados,
      ),
    );
  }
}

class _Cuerpo extends ConsumerWidget {
  const _Cuerpo({required this.consulta, required this.asyncResultados});

  final String consulta;
  final AsyncValue<ResultadosBusqueda> asyncResultados;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    if (consulta.trim().length < 2) {
      return _Mensaje(icono: Icons.search, texto: textos.searchPromptHint);
    }
    return asyncResultados.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Mensaje(
        icono: Icons.error_outline,
        texto: error.toString(),
      ),
      data: (resultados) {
        if (resultados.estaVacio) {
          return _Mensaje(icono: Icons.inbox_outlined, texto: textos.searchNoResults);
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (resultados.items.isNotEmpty)
              _Seccion<Item>(
                titulo: textos.searchSectionItems,
                elementos: resultados.items,
                constructorTile: (item) => _TileItem(item: item),
              ),
            if (resultados.sources.isNotEmpty)
              _Seccion<Source>(
                titulo: textos.searchSectionSources,
                elementos: resultados.sources,
                constructorTile: (src) => _TileSource(src: src),
              ),
            if (resultados.radios.isNotEmpty)
              _Seccion<modelo_radio.Radio>(
                titulo: textos.searchSectionRadios,
                elementos: resultados.radios,
                constructorTile: (r) => _TileRadio(radio: r),
              ),
            if (resultados.colectivos.isNotEmpty)
              _Seccion<Collective>(
                titulo: textos.searchSectionCollectives,
                elementos: resultados.colectivos,
                constructorTile: (c) => _TileColectivo(colectivo: c),
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _Seccion<T> extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.elementos,
    required this.constructorTile,
  });

  final String titulo;
  final List<T> elementos;
  final Widget Function(T) constructorTile;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '$titulo · ${elementos.length}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: esquema.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
          for (final elemento in elementos) constructorTile(elemento),
          Divider(height: 24, color: esquema.outlineVariant),
        ],
      ),
    );
  }
}

class _TileItem extends StatelessWidget {
  const _TileItem({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final fuente = item.source?.name ?? '';
    return ListTile(
      leading: const Icon(Icons.article_outlined),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: fuente.isNotEmpty ? Text(fuente) : null,
      onTap: () => GoRouter.of(context).push('/items/${item.id}'),
    );
  }
}

class _TileSource extends StatelessWidget {
  const _TileSource({required this.src});
  final Source src;

  @override
  Widget build(BuildContext context) {
    final subt = [
      if (src.territory.isNotEmpty) src.territory,
      if (src.languages.isNotEmpty) src.languages.join(', '),
    ].join(' · ');
    return ListTile(
      leading: Icon(_iconoDeFeedType(src.feedType)),
      title: Text(src.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subt.isNotEmpty ? Text(subt) : null,
      onTap: () => GoRouter.of(context).push('/sources/${src.id}'),
    );
  }

  static IconData _iconoDeFeedType(String tipo) {
    switch (tipo) {
      case 'youtube':
        return Icons.play_circle_outline;
      case 'video':
        return Icons.videocam_outlined;
      case 'podcast':
        return Icons.mic_outlined;
      case 'mastodon':
        return Icons.forum_outlined;
      default:
        return Icons.rss_feed;
    }
  }
}

class _TileRadio extends StatelessWidget {
  const _TileRadio({required this.radio});
  final modelo_radio.Radio radio;

  @override
  Widget build(BuildContext context) {
    final subt = [
      if (radio.territory.isNotEmpty) radio.territory,
      if (radio.languages.isNotEmpty) radio.languages.join(', '),
    ].join(' · ');
    return ListTile(
      leading: const Icon(Icons.radio),
      title: Text(radio.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subt.isNotEmpty ? Text(subt) : null,
      trailing: radio.websiteUrl.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: radio.websiteUrl,
              onPressed: () async {
                final uri = Uri.tryParse(radio.websiteUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            )
          : null,
      onTap: () => GoRouter.of(context).go('/radios'),
    );
  }
}

class _TileColectivo extends StatelessWidget {
  const _TileColectivo({required this.colectivo});
  final Collective colectivo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.groups_outlined),
      title: Text(colectivo.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: colectivo.territory.isNotEmpty ? Text(colectivo.territory) : null,
      onTap: () => GoRouter.of(context).push('/collectives/${colectivo.id}'),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final colorSec = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: colorSec),
            const SizedBox(height: 12),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorSec),
            ),
          ],
        ),
      ),
    );
  }
}
