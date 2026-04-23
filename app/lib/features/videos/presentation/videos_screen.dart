import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/ingest_trigger.dart';
import '../../history/data/historial_provider.dart';
import '../data/canales_favoritos_notifier.dart';
import '../data/videos_provider.dart';

/// Estado local del chip "sólo mis canales" en la pantalla de vídeos.
final soloCanalesFavoritosProvider = StateProvider<bool>((_) => false);

/// Sección especial de vídeos. Presentación distinta al feed normal: grid
/// de 2 columnas con miniatura grande, título truncado y nombre del medio.
/// Tap = abrir el vídeo en el navegador / app externa (YouTube, Vimeo…),
/// no en un detalle interno: el valor de un vídeo es verlo, no leerlo.
class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});

  void _mostrarFiltros(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BottomSheetFiltrosVideos(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncVideos = ref.watch(videosProvider);

    final filtros = ref.watch(filtrosVideosProvider);
    // Cuando llegamos con filtro de canal (desde la ficha del medio
    // o al encender un canal en TV), mostramos un back visible y el
    // nombre del canal en el título. Si no, mantenemos la pantalla
    // global sin leading — está dentro del shell con bottom nav.
    final hayFiltroCanal = filtros.idSource != null;
    String? nombreCanal;
    if (hayFiltroCanal) {
      final cargados = ref.watch(videosProvider).valueOrNull;
      final primerVideoDelCanal = cargados?.firstWhere(
        (v) => v.source?.id == filtros.idSource,
        orElse: () => cargados.first,
      );
      nombreCanal = primerVideoDelCanal?.source?.name;
    }
    return Scaffold(
      appBar: AppBar(
        leading: hayFiltroCanal
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: textos.commonBack,
                onPressed: () {
                  // Salimos del modo "vídeos del canal": limpiamos el
                  // filtro y volvemos al detalle del canal si lo hay en
                  // el stack, si no a la pestaña TV.
                  final idSource = filtros.idSource;
                  ref.read(filtrosVideosProvider.notifier).state =
                      FiltrosVideos.vacios;
                  if (context.canPop()) {
                    context.pop();
                  } else if (idSource != null) {
                    context.go('/sources/$idSource');
                  } else {
                    context.go('/tv');
                  }
                },
              )
            : null,
        title: Text(
          hayFiltroCanal && nombreCanal != null && nombreCanal.isNotEmpty
              ? nombreCanal
              : textos.videosTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: !filtros.estaVacio,
              child: const Icon(Icons.tune),
            ),
            tooltip: textos.filtersTitle,
            onPressed: () => _mostrarFiltros(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          unawaited(dispararIngestaBackend(ref.read(sharedPreferencesProvider)));
          ref.invalidate(videosProvider);
        },
        child: asyncVideos.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
          ),
          data: (videos) {
            final favoritos = ref.watch(canalesFavoritosProvider);
            final soloFavoritos = ref.watch(soloCanalesFavoritosProvider);
            final hayFavoritos = favoritos.isNotEmpty;
            final videosMostrados = soloFavoritos
                ? videos.where((v) => favoritos.contains(v.source?.id ?? -1)).toList()
                : videos;
            if (videosMostrados.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          textos.videosEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                if (hayFavoritos)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: Icon(
                            soloFavoritos ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                          ),
                          label: Text(textos.videosOnlyFavorites),
                          selected: soloFavoritos,
                          onSelected: (v) =>
                              ref.read(soloCanalesFavoritosProvider.notifier).state = v,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: videosMostrados.length,
                    itemBuilder: (context, indice) =>
                        _TarjetaVideo(item: videosMostrados[indice]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomSheetFiltrosVideos extends ConsumerWidget {
  const _BottomSheetFiltrosVideos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final filtros = ref.watch(filtrosVideosProvider);
    final asyncTopics = ref.watch(topicsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      textos.filtersTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!filtros.estaVacio)
                    TextButton(
                      onPressed: () => ref.read(filtrosVideosProvider.notifier).state = FiltrosVideos.vacios,
                      child: Text(textos.filtersClear),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                textos.filterByTopic,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              asyncTopics.when(
                // Si falla o está cargando mostramos placeholder visible
                // en vez de dejar la sección vacía — antes desaparecía
                // todo el filtro cuando el backend no respondía.
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(
                  textos.filterTopicsOffline,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                data: (topics) {
                  final topicsUtiles = topics.where((t) => t.count > 0).toList();
                  if (topicsUtiles.isEmpty) {
                    return Text(textos.filterTopicsOffline,
                        style: Theme.of(context).textTheme.bodySmall);
                  }
                  return Wrap(
                    spacing: 6, runSpacing: 6,
                    children: [
                      for (final topic in topicsUtiles)
                        FilterChip(
                          label: Text(topic.name),
                          selected: filtros.slugsTopics.contains(topic.slug),
                          onSelected: (_) {
                            final current = ref.read(filtrosVideosProvider);
                            ref.read(filtrosVideosProvider.notifier).state = current.alternarTopic(topic.slug);
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                textos.filterByLanguage,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  for (final codigo in const ['es', 'ca', 'eu', 'gl', 'en'])
                    FilterChip(
                      label: Text(codigo.toUpperCase()),
                      selected: filtros.codigosIdiomas.contains(codigo),
                      onSelected: (_) {
                        final current = ref.read(filtrosVideosProvider);
                        ref.read(filtrosVideosProvider.notifier).state =
                            current.alternarIdioma(codigo);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(textos.filtersApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaVideo extends ConsumerWidget {
  const _TarjetaVideo({required this.item});
  final Item item;

  void _abrir(BuildContext context) {
    // Siempre abrimos el reproductor in-app. `itemDetalleProvider` se
    // encarga de resolver la ficha: para ids positivos pregunta al
    // backend (y cae al cache si no responde); para ids negativos (seed
    // RSS y fuentes personales) va directo al cache local, donde se
    // guardan desde `cachearMuchos` tras cada descarga del seed.
    // El propio reproductor delega a navegador externo si la URL no es
    // YouTube ni PeerTube — no hace falta decidirlo aquí.
    GoRouter.of(context).push('/videos/play/${item.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final idCanal = item.source?.id ?? 0;
    final canalesFav = ref.watch(canalesFavoritosProvider);
    final esCanalFavorito = idCanal > 0 && canalesFav.contains(idCanal);
    // Guardados vive en SQLite (DAO): al guardar, se cachea el payload
    // completo para que aparezca en "Guardados" aunque el item desaparezca
    // del feed del backend. Mismo provider que usa el feed de noticias.
    final idsGuardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
    final estaGuardado = idsGuardados.contains(item.id);
    return InkWell(
      onTap: () => _abrir(context),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.mediaUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: item.mediaUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: esquema.surfaceContainerHighest,
                      ),
                      placeholder: (_, __) => Container(
                        color: esquema.surfaceContainerHighest,
                      ),
                    )
                  else
                    Container(color: esquema.surfaceContainerHighest),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.45),
                        ],
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                  // Icono tipo bookmark: guarda el VÍDEO individual
                  // (no el canal). Antes había aquí un corazón que
                  // alteraba el canal-favorito — confundía, porque al
                  // marcarlo parecía que "se marcaban todos los vídeos
                  // del mismo canal". El favorito de canal vive ahora
                  // junto al nombre del medio abajo.
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            ref.read(guardadosProvider.notifier).alternar(item),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            estaGuardado ? Icons.bookmark : Icons.bookmark_border,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.durationSeconds > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatearDuracionBreve(item.durationSeconds),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 2),
          if (item.source != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.source!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                  ),
                ),
                if (idCanal > 0)
                  InkWell(
                    onTap: () =>
                        ref.read(canalesFavoritosProvider.notifier).alternar(idCanal),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        esCanalFavorito ? Icons.favorite : Icons.favorite_border,
                        size: 14,
                        color: esCanalFavorito
                            ? esquema.primary
                            : esquema.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatearDuracionBreve(int segundos) {
  if (segundos <= 0) return '';
  final horas = segundos ~/ 3600;
  final minutos = (segundos % 3600) ~/ 60;
  final segs = segundos % 60;
  final dosDig = (int n) => n.toString().padLeft(2, '0');
  if (horas > 0) return '$horas:${dosDig(minutos)}:${dosDig(segs)}';
  return '$minutos:${dosDig(segs)}';
}
