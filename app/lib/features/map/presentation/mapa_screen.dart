import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/collective.dart';
import '../../../core/models/radio.dart' as modelo_radio;
import '../../../core/providers/api_provider.dart';
import '../../collectives/data/colectivos_directorio_notifier.dart';
import '../data/territorio_geocoder.dart';

/// Mapa con dos tipos de marcador:
///  - radios libres (icono de antena)
///  - colectivos verificados (icono de grupo)
///
/// Tiles de OpenStreetMap. No pedimos permisos de ubicación — el mapa
/// muestra *dónde están* las cosas, no *dónde está el usuario*.
class MapaScreen extends ConsumerWidget {
  const MapaScreen({super.key});

  static const _centroIberico = LatLng(40.0, -3.5);
  static const _zoomInicial = 5.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncRadios = ref.watch(radiosProvider);
    final asyncColectivos = ref.watch(colectivosDirectorioProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.settingsMap),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: asyncRadios.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (radios) {
          final colectivos = asyncColectivos.valueOrNull?.items ?? const <Collective>[];
          return _Mapa(radios: radios, colectivos: colectivos);
        },
      ),
    );
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({required this.radios, required this.colectivos});

  final List<modelo_radio.Radio> radios;
  final List<Collective> colectivos;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final radio in radios) {
      final coords = TerritorioGeocoder.buscar(_territorioParaMapa(
        country: radio.country,
        region: radio.region,
        city: radio.city,
        fallback: radio.territory,
      ));
      if (coords == null) continue;
      markers.add(_MarcadorRadio.construir(context, radio, coords));
    }
    for (final colectivo in colectivos) {
      final coords = TerritorioGeocoder.buscar(_territorioParaMapa(
        country: colectivo.country,
        region: colectivo.region,
        city: colectivo.city,
        fallback: colectivo.territory,
      ));
      if (coords == null) continue;
      markers.add(_MarcadorColectivo.construir(context, colectivo, coords));
    }

    return FlutterMap(
      options: const MapOptions(
        initialCenter: MapaScreen._centroIberico,
        initialZoom: MapaScreen._zoomInicial,
        minZoom: 3,
        maxZoom: 16,
      ),
      children: [
        TileLayer(
          // Tile server oficial de OSM. En producción con mucha gente
          // conviene usar uno propio para respetar la política de uso.
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.flavor.news_hub',
          maxNativeZoom: 19,
        ),
        MarkerLayer(markers: _desviarSolapados(markers)),
      ],
    );
  }

  /// Dos marcadores en el mismo centroide (típico: varias radios de la
  /// misma provincia) se solapan y quedan invisibles. Aplicamos un
  /// desplazamiento en espiral determinista para separarlos sin que la
  /// posición salte entre renders.
  List<Marker> _desviarSolapados(List<Marker> marcadores) {
    final agrupadosPorPunto = <String, List<Marker>>{};
    for (final m in marcadores) {
      final clave = '${m.point.latitude.toStringAsFixed(3)}:${m.point.longitude.toStringAsFixed(3)}';
      agrupadosPorPunto.putIfAbsent(clave, () => []).add(m);
    }
    final salida = <Marker>[];
    for (final grupo in agrupadosPorPunto.values) {
      if (grupo.length == 1) {
        salida.add(grupo.first);
        continue;
      }
      const radio = 0.05; // grados ≈ 5km
      for (var i = 0; i < grupo.length; i++) {
        final angulo = (2 * math.pi * i) / grupo.length;
        final dx = radio * math.cos(angulo);
        final dy = radio * math.sin(angulo);
        final original = grupo[i];
        salida.add(Marker(
          point: LatLng(original.point.latitude + dy, original.point.longitude + dx),
          width: original.width,
          height: original.height,
          child: original.child,
        ));
      }
    }
    return salida;
  }

  static String _territorioParaMapa({
    required String country,
    required String region,
    required String city,
    required String fallback,
  }) {
    if (city.isNotEmpty) return city;
    if (region.isNotEmpty) return region;
    if (country.isNotEmpty) return country;
    return fallback;
  }
}

class _MarcadorRadio {
  static Marker construir(BuildContext context, modelo_radio.Radio radio, LatLng coords) {
    return Marker(
      point: coords,
      width: 120,
      height: 60,
      alignment: Alignment.topCenter,
      child: _ChipMarcador(
        icono: Icons.radio,
        color: Theme.of(context).colorScheme.primary,
        etiqueta: radio.name,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${radio.name} · ${radio.territory}')),
          );
          GoRouter.of(context).go('/radios');
        },
      ),
    );
  }
}

class _MarcadorColectivo {
  static Marker construir(BuildContext context, Collective colectivo, LatLng coords) {
    return Marker(
      point: coords,
      width: 120,
      height: 60,
      alignment: Alignment.topCenter,
      child: _ChipMarcador(
        icono: Icons.groups,
        color: Theme.of(context).colorScheme.tertiary,
        etiqueta: colectivo.name,
        onTap: () => GoRouter.of(context).push('/collectives/${colectivo.id}'),
      ),
    );
  }
}

class _ChipMarcador extends StatelessWidget {
  const _ChipMarcador({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(icono, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(3),
            ),
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
