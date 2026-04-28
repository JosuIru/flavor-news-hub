import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/filtros/filtros_transversales.dart';
import '../../../core/models/item.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/providers/api_provider.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/territory_normalizer.dart';
import '../../../core/utils/territory_scoring.dart';
import '../../../core/widgets/barra_filtros_activos.dart';
import '../../audio/presentation/reproductor_episodio_sheet.dart';
import '../data/programas_radio_provider.dart';
import '../data/radios_favoritas_notifier.dart';
import '../data/reproductor_radio_notifier.dart';

/// Estado local del chip "sólo favoritas" en la pantalla de radios.
/// No es transversal: filtrar por favoritas en Radios no debe afectar
/// a Feed/Vídeos/etc.
final soloRadiosFavoritasProvider = StateProvider<bool>((_) => false);

/// Directorio de radios libres. Cada fila con play/pause. Sólo una suena
/// a la vez — al pulsar play en otra, la anterior se detiene.
///
/// Acciones secundarias: abrir la web de la emisora y, si expone RSS de
/// programas/podcast, desplegar un bottom sheet con los últimos episodios.
/// Sólo el cuerpo (lista de radios). No incluye `Scaffold`/`AppBar` para
/// poder embeberse como pestaña dentro de `AudioScreen` sin duplicar chrome.
class RadiosBody extends ConsumerWidget {
  const RadiosBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncRadios = ref.watch(radiosProvider);
    final estadoReproductor = ref.watch(reproductorRadioProvider);
    final favoritas = ref.watch(radiosFavoritasProvider);
    final territorioBase = ref.watch(
      preferenciasProvider.select((p) => p.territorioBase),
    );
    final transversal = ref.watch(filtrosTransversalesProvider);
    final notifier = ref.read(filtrosTransversalesProvider.notifier);
    final idiomasEfectivos = ref.watch(idiomasEfectivosConOverrideProvider);

    return asyncRadios.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(radiosProvider),
                icon: const Icon(Icons.refresh),
                label: Text(textos.commonRetry),
              ),
            ],
          ),
        ),
      ),
      data: (radios) {
        if (radios.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                textos.radiosEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            );
        }
        final soloFavoritas = ref.watch(soloRadiosFavoritasProvider);
        // El territorio activo viene del provider transversal (compartido
        // con Feed, Colectivos…). Si el usuario lo fijó en otra
        // pestaña, Radios lo respeta automáticamente. El chip "Mi
        // territorio" se mantiene como atajo: cuando está marcado el
        // global apunta a `territorioBase`.
        final territorioActivo = transversal.codigoTerritorio;
        final filtroTerritorioActivo =
            territorioActivo != null && territorioActivo.isNotEmpty;
        final usandoMiTerritorio =
            filtroTerritorioActivo && territorioActivo == territorioBase;
        // Filtramos en cliente porque el listado completo cabe (~80
        // radios). Hacerlo en backend nos forzaría una segunda query
        // por cada toggle del chip.
        Iterable<modelo_radio.Radio> visiblesIter = radios;
        if (soloFavoritas) {
          visiblesIter = visiblesIter.where((r) => favoritas.contains(r.id));
        }
        if (filtroTerritorioActivo) {
          // `pertenece` expande redes meta (Euskal Herria → sus
          // provincias, Latinoamérica → sus países…) antes de comparar.
          // Sin esa expansión, ninguna radio lleva literalmente
          // "Euskal Herria" en sus campos y el filtro devolvía 0
          // resultados.
          visiblesIter = visiblesIter.where(
            (r) => TerritoryNormalizer.pertenece(
              claveTerritorial: territorioActivo,
              country: r.country,
              region: r.region,
              city: r.city,
              territory: r.territory,
            ),
          );
        }
        if (idiomasEfectivos.isNotEmpty) {
          // Match laxo: pasa si la radio declara al menos un idioma
          // que coincida. Las radios sin idioma declarado (legacy,
          // metadato incompleto) pasan el filtro — antes habrían
          // quedado fuera por silencio del seed.
          final idiomasSet = idiomasEfectivos.toSet();
          visiblesIter = visiblesIter.where((r) {
            if (r.languages.isEmpty) return true;
            return r.languages
                .map((e) => e.toLowerCase())
                .any(idiomasSet.contains);
          });
        }
        final radiosVisibles = visiblesIter.toList();
        // Orden: favoritas arriba (preferencia explícita del usuario) →
        // dentro de cada bloque, prioridad local si hay territorio base
        // fijado → alfabético como desempate estable.
        int prio(modelo_radio.Radio r) => prioridadLocal(
              country: r.country,
              region: r.region,
              city: r.city,
              network: '',
              territorioBase: territorioBase,
            );
        final ordenadas = radiosVisibles
          ..sort((a, b) {
            final aFav = favoritas.contains(a.id) ? 0 : 1;
            final bFav = favoritas.contains(b.id) ? 0 : 1;
            if (aFav != bFav) return aFav - bFav;
            final diffPrio = prio(b) - prio(a);
            if (diffPrio != 0) return diffPrio;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final tieneTerritorioBase = territorioBase.isNotEmpty;
        return Column(
          children: [
            // Barra de chips transversales: muestra los ejes que Radios
            // aplica (territorio + idiomas). No incluye topics — las
            // radios no se taxonomizan por temática hoy. Si el usuario
            // los fijó desde otra pestaña, los conserva intactos pero
            // no los pinta aquí para no dar la impresión de que
            // afectan a esta lista.
            BarraChipsFiltrosActivos(
              codigoTerritorio: territorioActivo,
              codigosIdiomas: transversal.codigosIdiomasOverride,
              onQuitarTerritorio: () => notifier.establecerTerritorio(null),
              onQuitarIdioma: notifier.alternarIdioma,
              onLimpiarTodo: () {
                notifier.establecerTerritorio(null);
                notifier.limpiarIdiomas();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: _RadiosFavoritesHeader(
                hasFavorites: favoritas.isNotEmpty,
                onlyFavorites: soloFavoritas,
                onToggle: (valor) =>
                    ref.read(soloRadiosFavoritasProvider.notifier).state = valor,
                onClear: soloFavoritas
                    ? () => ref.read(soloRadiosFavoritasProvider.notifier).state = false
                    : null,
              ),
            ),
            if (tieneTerritorioBase)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    FilterChip(
                      avatar: Icon(
                        usandoMiTerritorio ? Icons.place : Icons.place_outlined,
                        size: 16,
                      ),
                      label: Text(territorioBase),
                      selected: usandoMiTerritorio,
                      onSelected: (marcado) => marcado
                          ? notifier.establecerTerritorio(territorioBase)
                          : notifier.establecerTerritorio(null),
                    ),
                  ],
                ),
              ),
            Expanded(
                child: radiosVisibles.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        _EstadoVacioRadios(
                          icono: soloFavoritas ? Icons.favorite_border : Icons.radio_outlined,
                          texto: soloFavoritas ? textos.radiosOnlyFavoritesEmpty : textos.radiosEmpty,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: ordenadas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, indice) {
                        final radio = ordenadas[indice];
                        return _FilaRadio(
                          radio: radio,
                          estadoReproductor: estadoReproductor,
                          esFavorita: favoritas.contains(radio.id),
                          onToggle: () => ref.read(reproductorRadioProvider.notifier).alternar(radio),
                          onFavorita: () =>
                              ref.read(radiosFavoritasProvider.notifier).alternar(radio.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RadiosFavoritesHeader extends StatelessWidget {
  const _RadiosFavoritesHeader({
    required this.hasFavorites,
    required this.onlyFavorites,
    required this.onToggle,
    required this.onClear,
  });

  final bool hasFavorites;
  final bool onlyFavorites;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final descripcionEstadoFavoritas = onlyFavorites
        ? textos.radiosOnlyFavoritesActive
        : hasFavorites
            ? textos.radiosOnlyFavoritesHint
            : textos.radiosOnlyFavoritesEmpty;
    return Material(
      color: esquema.surfaceContainerHighest,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.favorite, size: 18, color: esquema.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    descripcionEstadoFavoritas,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                  ),
                ),
                FilterChip(
                  avatar: Icon(
                    onlyFavorites ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                  ),
                  label: Text(textos.radiosOnlyFavorites),
                  selected: onlyFavorites,
                  onSelected: onToggle,
                ),
              ],
            ),
            if (onlyFavorites && onClear != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClear,
                  child: Text(textos.filtersClear),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstadoVacioRadios extends StatelessWidget {
  const _EstadoVacioRadios({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Icon(
            icono,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Versión full-screen: usada para el deep link `/radios` (legacy) o
/// cualquier lugar donde queramos abrir la lista sin el tab de música.
class RadiosScreen extends ConsumerWidget {
  const RadiosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final soloFavoritas = ref.watch(soloRadiosFavoritasProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(textos.radiosTitle),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: soloFavoritas,
              child: Icon(
                soloFavoritas ? Icons.favorite : Icons.favorite_border,
              ),
            ),
            tooltip: textos.radiosOnlyFavorites,
            onPressed: () {
              ref.read(soloRadiosFavoritasProvider.notifier).state = !soloFavoritas;
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: const RadiosBody(),
    );
  }
}

class _FilaRadio extends StatelessWidget {
  const _FilaRadio({
    required this.radio,
    required this.estadoReproductor,
    required this.esFavorita,
    required this.onToggle,
    required this.onFavorita,
  });

  final modelo_radio.Radio radio;
  final EstadoReproductor estadoReproductor;
  final bool esFavorita;
  final VoidCallback onToggle;
  final VoidCallback onFavorita;

  Future<void> _abrirWeb() async {
    final uri = Uri.tryParse(radio.websiteUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _verProgramas(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BottomSheetProgramas(radio: radio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final reproduciendo = estadoReproductor.reproduciendoRadio(radio.id);
    final cargando = estadoReproductor.cargandoRadio(radio.id);
    final errorEnEstaRadio = estadoReproductor.estado == EstadoPlayback.error &&
        estadoReproductor.radioActual?.id == radio.id;

    final tieneWeb = radio.websiteUrl.isNotEmpty;
    final tieneRss = radio.rssUrl.isNotEmpty;
    final tieneApoyo = radio.supportUrl.isNotEmpty;

    return ListTile(
      leading: IconButton(
        iconSize: 32,
        icon: cargando
            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Icon(reproduciendo ? Icons.stop_circle : Icons.play_circle_fill,
                color: reproduciendo ? esquema.primary : esquema.onSurface),
        onPressed: onToggle,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              radio.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: reproduciendo ? FontWeight.w700 : FontWeight.w500,
                color: reproduciendo ? esquema.primary : null,
              ),
            ),
          ),
          IconButton(
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              esFavorita ? Icons.favorite : Icons.favorite_border,
              color: esFavorita ? esquema.primary : esquema.onSurfaceVariant,
            ),
            onPressed: onFavorita,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (radio.territory.isNotEmpty || radio.languages.isNotEmpty)
            Text(
              [
                if (radio.territory.isNotEmpty) radio.territory,
                if (radio.languages.isNotEmpty) radio.languages.join(' · '),
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
            ),
          if (errorEnEstaRadio)
            Text(
              textos.radiosStreamError,
              style: TextStyle(color: esquema.error, fontSize: 12),
            ),
          if (tieneWeb || tieneRss || tieneApoyo)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                children: [
                  if (tieneWeb)
                    _ChipAccion(
                      icono: Icons.public,
                      etiqueta: textos.radioWebsite,
                      onTap: _abrirWeb,
                    ),
                  if (tieneRss)
                    _ChipAccion(
                      icono: Icons.podcasts,
                      etiqueta: textos.radioPrograms,
                      onTap: () => _verProgramas(context),
                    ),
                  if (tieneApoyo)
                    _ChipAccion(
                      icono: Icons.favorite,
                      etiqueta: textos.supportEntity,
                      onTap: () async {
                        final uri = Uri.tryParse(radio.supportUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
      onTap: onToggle,
      isThreeLine: tieneWeb || tieneRss || tieneApoyo,
    );
  }
}

class _ChipAccion extends StatelessWidget {
  const _ChipAccion({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icono, size: 16),
      label: Text(etiqueta),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _BottomSheetProgramas extends ConsumerWidget {
  const _BottomSheetProgramas({required this.radio});
  final modelo_radio.Radio radio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncProgramas = ref.watch(programasPara(
      nombreRadio: radio.name,
      rssUrl: radio.rssUrl,
    ));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.podcasts),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      radio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: asyncProgramas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      textos.radioProgramsFetchError,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          textos.radioProgramsEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, indice) => _TileProgramaRss(item: items[indice]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TileProgramaRss extends StatelessWidget {
  const _TileProgramaRss({required this.item});
  final Item item;

  @override
  Widget build(BuildContext context) {
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final fecha = DateTime.tryParse(item.publishedAt);
    final fechaTexto = fecha != null
        ? DateFormat.yMMMd(localeCodigo).format(fecha.toLocal())
        : '';
    final tieneAudio = item.audioUrl.isNotEmpty;
    return ListTile(
      leading: Icon(tieneAudio ? Icons.play_circle_fill : Icons.open_in_new),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: fechaTexto.isNotEmpty ? Text(fechaTexto) : null,
      onTap: () async {
        if (tieneAudio) {
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => ReproductorEpisodioSheet(episodio: item),
          );
          return;
        }
        final uri = Uri.tryParse(item.originalUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }
}
