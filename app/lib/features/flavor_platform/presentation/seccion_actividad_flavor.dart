import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/actividad_flavor_provider.dart';
import '../data/flavor_models.dart';

/// Bloque "Actividad en Flavor" para incrustar en pantallas de detalle
/// (típicamente la ficha de colectivo). Consume `actividadFlavorProvider`
/// con la URL del nodo y presenta 3 pestañas con eventos, catálogo y tablón.
///
/// Diseño tolerante: si una sección viene vacía, no se muestra. Si el
/// endpoint no existe (instancia que no tiene el módulo activo), el widget
/// se oculta del todo.
class SeccionActividadFlavor extends ConsumerWidget {
  const SeccionActividadFlavor({required this.flavorUrl, super.key});

  final String flavorUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    if (flavorUrl.isEmpty) return const SizedBox.shrink();
    final asyncActividad = ref.watch(actividadFlavorProvider(flavorUrl));
    final esquema = Theme.of(context).colorScheme;

    return asyncActividad.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (actividad) {
        if (actividad.estaVacio) {
          return _Encabezado(
            textos: textos,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                textos.flavorActivityEmpty,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        return _Encabezado(
          textos: textos,
          child: _Pestanas(actividad: actividad),
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.textos, required this.child});
  final AppLocalizations textos;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub, size: 18, color: esquema.primary),
              const SizedBox(width: 8),
              Text(
                textos.flavorActivityHeader,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Pestanas extends StatefulWidget {
  const _Pestanas({required this.actividad});
  final ActividadNodoFlavor actividad;

  @override
  State<_Pestanas> createState() => _EstadoPestanas();
}

class _EstadoPestanas extends State<_Pestanas> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final List<_PestanaDef> _pestanas;

  @override
  void initState() {
    super.initState();
    _pestanas = _construirPestanas();
    _tabController = TabController(length: _pestanas.length, vsync: this);
  }

  /// Sólo pestañas con contenido — evita mostrar tabs huecas.
  List<_PestanaDef> _construirPestanas() {
    final a = widget.actividad;
    return [
      if (a.eventos.isNotEmpty)
        _PestanaDef(
          obtenerTitulo: (t) => '${t.flavorActivityEvents} · ${a.eventos.length}',
          contenido: _ListaEventos(eventos: a.eventos),
        ),
      if (a.contenidos.isNotEmpty)
        _PestanaDef(
          obtenerTitulo: (t) => '${t.flavorActivityContent} · ${a.contenidos.length}',
          contenido: _ListaContenidos(contenidos: a.contenidos),
        ),
      if (a.publicaciones.isNotEmpty)
        _PestanaDef(
          obtenerTitulo: (t) => '${t.flavorActivityBoard} · ${a.publicaciones.length}',
          contenido: _ListaPublicaciones(publicaciones: a.publicaciones),
        ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    if (_pestanas.length == 1) {
      return _pestanas.first.contenido;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final p in _pestanas) Tab(text: p.obtenerTitulo(textos)),
          ],
        ),
        const SizedBox(height: 8),
        // AnimatedSize porque cada pestaña tiene alturas distintas y el
        // TabBarView por defecto exige altura fija.
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _pestanas[_tabController.index].contenido,
          ),
        ),
      ],
    );
  }
}

class _PestanaDef {
  _PestanaDef({required this.obtenerTitulo, required this.contenido});
  final String Function(AppLocalizations) obtenerTitulo;
  final Widget contenido;
}

class _ListaEventos extends StatelessWidget {
  const _ListaEventos({required this.eventos});
  final List<FlavorEvento> eventos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in eventos) _TileEvento(evento: e),
      ],
    );
  }
}

class _TileEvento extends StatelessWidget {
  const _TileEvento({required this.evento});
  final FlavorEvento evento;

  @override
  Widget build(BuildContext context) {
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final fecha = DateTime.tryParse(evento.fechaInicio);
    final fechaTexto = fecha != null
        ? DateFormat.yMMMMd(localeCodigo).add_Hm().format(fecha.toLocal())
        : evento.fechaInicio;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(evento.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [fechaTexto, if (evento.ubicacion.isNotEmpty) evento.ubicacion].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: evento.esOnline && evento.urlOnline.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () {
                final uri = Uri.tryParse(evento.urlOnline);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            )
          : null,
    );
  }
}

class _ListaContenidos extends StatelessWidget {
  const _ListaContenidos({required this.contenidos});
  final List<FlavorContenido> contenidos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in contenidos) _TileContenido(contenido: c),
      ],
    );
  }
}

class _TileContenido extends StatelessWidget {
  const _TileContenido({required this.contenido});
  final FlavorContenido contenido;

  @override
  Widget build(BuildContext context) {
    final precio = contenido.precio;
    final subt = [
      contenido.tipoContenido,
      if (precio.isNotEmpty && precio != '0.00') '$precio ${contenido.moneda}',
      if (contenido.ubicacion.isNotEmpty) contenido.ubicacion,
    ].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: _iconoPara(contenido.tipoContenido),
      title: Text(contenido.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subt, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Icon _iconoPara(String tipo) {
    switch (tipo) {
      case 'espacio':
        return const Icon(Icons.meeting_room);
      case 'producto':
        return const Icon(Icons.shopping_bag_outlined);
      case 'servicio':
        return const Icon(Icons.handshake_outlined);
      default:
        return const Icon(Icons.category_outlined);
    }
  }
}

class _ListaPublicaciones extends StatelessWidget {
  const _ListaPublicaciones({required this.publicaciones});
  final List<FlavorPublicacionTablon> publicaciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in publicaciones)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.campaign_outlined),
            title: Text(p.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              p.contenido,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
