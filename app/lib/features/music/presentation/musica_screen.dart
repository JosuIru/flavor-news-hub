import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../../../core/models/source_summary.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../audio/data/reproductor_episodio_notifier.dart';
import '../../audio/presentation/reproductor_episodio_sheet.dart';
import '../data/archive_org_client.dart';
import '../data/audius_client.dart';
import '../data/funkwhale_client.dart';
import '../data/jamendo_client.dart';

/// Cuerpo reutilizable (sin Scaffold) para embeber la búsqueda de música
/// dentro de una pestaña o de una pantalla full-screen.
class MusicaBody extends ConsumerStatefulWidget {
  const MusicaBody({super.key});

  @override
  ConsumerState<MusicaBody> createState() => _EstadoMusicaBody();
}

class _EstadoMusicaBody extends ConsumerState<MusicaBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(consultaMusicaProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _alCambiar(String valor) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(consultaMusicaProvider.notifier).state = valor;
    });
  }

  /// Un tap en un chip de género rellena el campo de búsqueda y dispara
  /// la consulta inmediatamente (sin esperar al debounce — el usuario ya
  /// decidió).
  void _buscarGenero(String genero) {
    _debounce?.cancel();
    _controller.text = genero;
    ref.read(consultaMusicaProvider.notifier).state = genero;
  }

  /// Arranca la reproducción con la lista completa como cola y `indice` como
  /// punto de inicio. Pasa un `proveedorSiguientes` que, al agotarse la cola,
  /// busca más pistas primero por el artista y luego por el género.
  void _reproducirPista(List<PistaFunkwhale> pistas, int indice) {
    final mapaPorId = <int, PistaFunkwhale>{};
    for (final p in pistas) {
      mapaPorId[-p.id] = p;
    }
    final items = pistas.map(_pistaAItem).toList(growable: false);

    Future<List<Item>?> proveedor(Item ultimo) async {
      final pistaOriginal = mapaPorId[ultimo.id] ?? _buscarPistaPorId(pistas, ultimo.id);
      if (pistaOriginal == null) return null;

      final yaEnCola = {for (final item in items) item.id};

      // Intento 1: más del mismo artista.
      if (pistaOriginal.artist.trim().isNotEmpty) {
        final porArtista = await buscarMusicaEnClientes(
          consulta: pistaOriginal.artist,
          clientAudius: ref.read(audiusClientProvider),
          clientArchive: ref.read(archiveOrgClientProvider),
          clientsFunkwhale: ref.read(funkwhaleClientsProvider),
          clientJamendo: ref.read(jamendoClientProvider),
        );
        final nuevas = porArtista
            .where((p) => !yaEnCola.contains(-p.id) && p.id != pistaOriginal.id)
            .toList();
        if (nuevas.isNotEmpty) {
          for (final p in nuevas) {
            mapaPorId[-p.id] = p;
          }
          return nuevas.map(_pistaAItem).toList(growable: false);
        }
      }

      // Intento 2: mismo género como fallback.
      if (pistaOriginal.genero.trim().isNotEmpty) {
        final porGenero = await buscarMusicaEnClientes(
          consulta: pistaOriginal.genero,
          clientAudius: ref.read(audiusClientProvider),
          clientArchive: ref.read(archiveOrgClientProvider),
          clientsFunkwhale: ref.read(funkwhaleClientsProvider),
          clientJamendo: ref.read(jamendoClientProvider),
        );
        final nuevas = porGenero
            .where((p) => !yaEnCola.contains(-p.id) && p.id != pistaOriginal.id)
            .toList();
        if (nuevas.isNotEmpty) {
          for (final p in nuevas) {
            mapaPorId[-p.id] = p;
          }
          return nuevas.map(_pistaAItem).toList(growable: false);
        }
      }

      return null;
    }

    ref.read(reproductorEpisodioProvider.notifier).reproducir(
          items[indice],
          cola: items,
          indiceInicial: indice,
          proveedorSiguientes: proveedor,
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReproductorEpisodioSheet(episodio: items[indice]),
    );
  }

  PistaFunkwhale? _buscarPistaPorId(List<PistaFunkwhale> pistas, int itemId) {
    // itemId = -pista.id; buscamos la pista original por ese valor.
    for (final p in pistas) {
      if (-p.id == itemId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final instancias = ref.watch(funkwhaleInstanciasProvider);

    final jamendoClientId = ref.watch(jamendoClientIdProvider);
    // Audius funciona siempre sin configuración, así que nunca mostramos la
    // vista "no hay nada" — como mucho el usuario amplía con Funkwhale/Jamendo.

    final asyncResultados = ref.watch(resultadosMusicaProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: _alCambiar,
            decoration: InputDecoration(
              hintText: textos.musicSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.tune),
                tooltip: textos.musicInstancesLabel,
                onPressed: () => _abrirGestorInstancias(context),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: asyncResultados.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (pistas) {
              final hayConsulta = ref.watch(consultaMusicaProvider).trim().length >= 2;
              if (!hayConsulta) {
                return _InicioRapido(
                  onGeneroSeleccionado: _buscarGenero,
                  onReproducirNovedad: _reproducirPista,
                );
              }
              if (pistas.isEmpty) {
                return _MensajeCentro(icono: Icons.inbox_outlined, texto: textos.searchNoResults);
              }
              return ListView.separated(
                itemCount: pistas.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) => _TilePista(
                  pista: pistas[i],
                  onReproducir: () => _reproducirPista(pistas, i),
                ),
              );
            },
          ),
        ),
        _BarraInstancias(
          instancias: instancias,
          jamendoActivo: jamendoClientId.isNotEmpty,
        ),
      ],
    );
  }
}

/// Versión full-screen del cuerpo (para deep link `/music`).
class MusicaScreen extends StatelessWidget {
  const MusicaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(textos.settingsMusic)),
      body: const MusicaBody(),
    );
  }
}

Future<void> _abrirGestorInstancias(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SheetInstancias(),
  );
}

class _SheetInstancias extends ConsumerStatefulWidget {
  const _SheetInstancias();

  @override
  ConsumerState<_SheetInstancias> createState() => _EstadoSheetInstancias();
}

class _EstadoSheetInstancias extends ConsumerState<_SheetInstancias> {
  final _controllerFunkwhale = TextEditingController();
  final _controllerJamendo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerJamendo.text = ref.read(jamendoClientIdProvider);
  }

  @override
  void dispose() {
    _controllerFunkwhale.dispose();
    _controllerJamendo.dispose();
    super.dispose();
  }

  Future<void> _anadirFunkwhale() async {
    final valor = _controllerFunkwhale.text.trim();
    if (valor.isEmpty) return;
    await ref.read(funkwhaleInstanciasProvider.notifier).anadir(valor);
    if (mounted) _controllerFunkwhale.clear();
  }

  Future<void> _guardarJamendo() async {
    await ref
        .read(jamendoClientIdProvider.notifier)
        .establecer(_controllerJamendo.text);
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final instancias = ref.watch(funkwhaleInstanciasProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                textos.musicInstancesLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(textos.musicInstancesHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllerFunkwhale,
                      decoration: const InputDecoration(
                        hintText: 'https://open.audio/',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _anadirFunkwhale(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text(textos.personalSourcesAddAction),
                    onPressed: _anadirFunkwhale,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (instancias.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    textos.musicInstancePrompt,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ...instancias.map(
                  (url) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hub),
                    title: Text(Uri.tryParse(url)?.host ?? url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: textos.personalSourcesRemove,
                      onPressed: () =>
                          ref.read(funkwhaleInstanciasProvider.notifier).eliminar(url),
                    ),
                  ),
                ),
              const Divider(height: 32),
              Text(
                textos.jamendoLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(textos.jamendoHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllerJamendo,
                      decoration: const InputDecoration(
                        hintText: 'abcdef12',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _guardarJamendo(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: Text(textos.jamendoGetKey),
                    onPressed: () => launchUrl(
                      Uri.parse('https://devportal.jamendo.com/'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraInstancias extends StatelessWidget {
  const _BarraInstancias({required this.instancias, required this.jamendoActivo});
  final List<String> instancias;
  final bool jamendoActivo;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    // Audius y archive.org siempre presentes (sin configuración).
    final fuentes = [
      'audius.co',
      'archive.org',
      ...instancias.map((u) => Uri.tryParse(u)?.host ?? u),
      if (jamendoActivo) 'jamendo.com',
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.hub, size: 14, color: esquema.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fuentes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TilePista extends StatelessWidget {
  const _TilePista({required this.pista, required this.onReproducir});
  final PistaFunkwhale pista;
  final VoidCallback onReproducir;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: pista.coverUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: pista.coverUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.music_note),
              ),
            )
          : const Icon(Icons.music_note),
      title: Text(pista.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [pista.artist, pista.album, pista.instanciaOrigen]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: pista.duration > 0 ? Text(_formatearDuracion(pista.duration)) : null,
      onTap: onReproducir,
    );
  }
}

/// Traducción de `PistaFunkwhale` a `Item` (modelo común con pódcasts) para
/// que el reproductor no tenga que saber de orígenes. El id negativo
/// distingue estas pistas de las de backend (que son positivas).
Item _pistaAItem(PistaFunkwhale pista) {
  return Item(
    id: -pista.id,
    slug: '',
    title: pista.title,
    excerpt: '',
    url: '',
    originalUrl: pista.listenUrl,
    publishedAt: '',
    mediaUrl: pista.coverUrl,
    audioUrl: pista.listenUrl,
    durationSeconds: pista.duration,
    source: SourceSummary(
      id: 0,
      slug: 'music',
      name: pista.artist.isNotEmpty ? pista.artist : pista.instanciaOrigen,
      websiteUrl: '',
      url: '',
      feedType: pista.instanciaOrigen == 'audius.co'
          ? 'audius'
          : pista.instanciaOrigen == 'jamendo.com'
              ? 'jamendo'
              : 'funkwhale',
    ),
  );
}

/// Pantalla de bienvenida para la pestaña Música: chips de géneros + lista
/// de novedades mezcladas de todas las plataformas. Se muestra cuando el
/// usuario aún no ha escrito nada en el buscador.
class _InicioRapido extends ConsumerWidget {
  const _InicioRapido({
    required this.onGeneroSeleccionado,
    required this.onReproducirNovedad,
  });

  final void Function(String) onGeneroSeleccionado;
  final void Function(List<PistaFunkwhale>, int) onReproducirNovedad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncNovedades = ref.watch(novedadesMusicaProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            textos.musicGenresHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final genero in generosMusicalesSugeridos)
                ActionChip(
                  label: Text(genero),
                  onPressed: () => onGeneroSeleccionado(genero),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            textos.musicNewHeader,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        asyncNovedades.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(e.toString()),
          ),
          data: (pistas) {
            if (pistas.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(textos.musicNewEmpty),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < pistas.length; i++) ...[
                  _TilePista(
                    pista: pistas[i],
                    onReproducir: () => onReproducirNovedad(pistas, i),
                  ),
                  if (i != pistas.length - 1) const Divider(height: 1),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MensajeCentro extends StatelessWidget {
  const _MensajeCentro({required this.icono, required this.texto});
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final colorSec = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: colorSec),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

String _formatearDuracion(int segundos) {
  if (segundos <= 0) return '';
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  final s = segundos % 60;
  final dos = (int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '$h:${dos(m)}:${dos(s)}';
  return '$m:${dos(s)}';
}
