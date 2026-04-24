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
import '../../../core/providers/preferences_provider.dart';
import '../../../core/utils/territory_normalizer.dart';
import '../../../core/utils/territory_scoring.dart';
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
  static const _zoomTerritorioBase = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncRadios = ref.watch(radiosProvider);
    final asyncColectivos = ref.watch(colectivosDirectorioProvider);
    final territorioBase = ref.watch(
      preferenciasProvider.select((p) => p.territorioBase),
    );

    // Centrado inicial: si el usuario fijó "Mi territorio" y su clave se
    // resuelve a coordenadas conocidas, arrancamos allí con zoom más
    // cercano. Si no, caemos al centro ibérico histórico — coherente
    // con la mayor concentración actual del catálogo.
    final centroEtiqueta = _territorioBaseParaCentrar(territorioBase);
    final centroPreferido = centroEtiqueta.isEmpty
        ? null
        : TerritorioGeocoder.buscar(centroEtiqueta);
    final centroInicial = centroPreferido ?? _centroIberico;
    final zoomInicial = centroPreferido != null ? _zoomTerritorioBase : _zoomInicial;

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
          return _Mapa(
            radios: radios,
            colectivos: colectivos,
            centroInicial: centroInicial,
            zoomInicial: zoomInicial,
            territorioBase: territorioBase,
          );
        },
      ),
    );
  }

  /// Devuelve la etiqueta más específica que podemos pedirle al
  /// geocoder para una clave de territorio base: primero prueba ciudad
  /// o región, luego país; si es sólo una red transnacional (Euskal
  /// Herria, Latinoamérica…) o cadena vacía, devuelve "" y el mapa
  /// mantiene su centro por defecto.
  static String _territorioBaseParaCentrar(String clave) {
    if (clave.isEmpty) return '';
    final ubicacion = TerritoryNormalizer.desglosar(clave);
    if (ubicacion.city.isNotEmpty) return ubicacion.city;
    if (ubicacion.region.isNotEmpty) return ubicacion.region;
    if (ubicacion.country.isNotEmpty) return ubicacion.country;
    // Para redes transnacionales (Euskal Herria, Latinoamérica, etc.)
    // el geocoder tiene entrada directa con la clave normalizada.
    return clave;
  }
}

class _Mapa extends StatelessWidget {
  const _Mapa({
    required this.radios,
    required this.colectivos,
    required this.centroInicial,
    required this.zoomInicial,
    required this.territorioBase,
  });

  final List<modelo_radio.Radio> radios;
  final List<Collective> colectivos;
  final LatLng centroInicial;
  final double zoomInicial;
  final String territorioBase;

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
      final prioridad = prioridadLocal(
        country: radio.country,
        region: radio.region,
        city: radio.city,
        network: '',
        territorioBase: territorioBase,
      );
      markers.add(_MarcadorRadio.construir(context, radio, coords, prioridad));
    }
    for (final colectivo in colectivos) {
      final coords = TerritorioGeocoder.buscar(_territorioParaMapa(
        country: colectivo.country,
        region: colectivo.region,
        city: colectivo.city,
        fallback: colectivo.territory,
      ));
      if (coords == null) continue;
      final prioridad = prioridadLocal(
        country: colectivo.country,
        region: colectivo.region,
        city: colectivo.city,
        network: '',
        territorioBase: territorioBase,
      );
      markers.add(_MarcadorColectivo.construir(context, colectivo, coords, prioridad));
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: centroInicial,
        initialZoom: zoomInicial,
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
  static Marker construir(
    BuildContext context,
    modelo_radio.Radio radio,
    LatLng coords,
    int prioridadLocal,
  ) {
    final esLocal = prioridadLocal > 0;
    return Marker(
      point: coords,
      // Los marcadores locales son ligeramente más grandes para que
      // destaquen sin romper la composición general del mapa.
      width: esLocal ? 130 : 120,
      height: esLocal ? 66 : 60,
      alignment: Alignment.topCenter,
      child: _ChipMarcador(
        icono: Icons.radio,
        color: Theme.of(context).colorScheme.primary,
        etiqueta: radio.name,
        prioridadLocal: prioridadLocal,
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
  static Marker construir(
    BuildContext context,
    Collective colectivo,
    LatLng coords,
    int prioridadLocal,
  ) {
    final esLocal = prioridadLocal > 0;
    return Marker(
      point: coords,
      width: esLocal ? 130 : 120,
      height: esLocal ? 66 : 60,
      alignment: Alignment.topCenter,
      child: _ChipMarcador(
        icono: Icons.groups,
        color: Theme.of(context).colorScheme.tertiary,
        etiqueta: colectivo.name,
        prioridadLocal: prioridadLocal,
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
    this.prioridadLocal = 0,
  });

  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  /// Prioridad local (0 = sin match; 4 = match de ciudad). Cuando es
  /// > 0, el chip recibe un anillo dorado y la etiqueta va en negrita
  /// para que los marcadores del territorio del usuario destaquen a
  /// ojo sin que compitan con la distinción radio/colectivo (colores
  /// primary vs tertiary del tema).
  final int prioridadLocal;

  @override
  Widget build(BuildContext context) {
    final esLocal = prioridadLocal > 0;
    // Ring dorado: grosor mayor cuanto más específico el match.
    // Ciudad=3, región=2, país/red=1.5.
    final grosorAnillo = prioridadLocal >= 4
        ? 3.0
        : prioridadLocal >= 3
            ? 2.0
            : 1.5;
    const colorAnillo = Color(0xFFFFC107); // ámbar
    final tamIcono = esLocal ? 22.0 : 18.0;

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
              border: esLocal
                  ? Border.all(color: colorAnillo, width: grosorAnillo)
                  : null,
              boxShadow: [
                const BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
                if (esLocal)
                  BoxShadow(
                    color: colorAnillo.withOpacity(0.55),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Icon(icono, color: Colors.white, size: tamIcono),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(3),
              border: esLocal
                  ? Border.all(color: colorAnillo, width: 1)
                  : null,
            ),
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.black,
                fontWeight: esLocal ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
