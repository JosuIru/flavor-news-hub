import 'package:latlong2/latlong.dart';

/// Geocoder offline de territorios. No dependemos de un servicio externo
/// para no mandar las búsquedas de cada usuario a un servidor de terceros
/// — ni los nombres de los colectivos se filtran por la red.
///
/// Cada entrada es un centroide aproximado: razonable para representar
/// "dónde está" un medio o un colectivo sin prometer precisión de calle.
class TerritorioGeocoder {
  static const Map<String, LatLng> _coordenadas = {
    // Euskal Herria
    'euskal herria': LatLng(43.00, -2.00),
    'euskadi': LatLng(43.06, -2.58),
    'pais vasco': LatLng(43.06, -2.58),
    'país vasco': LatLng(43.06, -2.58),
    'bizkaia': LatLng(43.25, -2.93),
    'vizcaya': LatLng(43.25, -2.93),
    'gipuzkoa': LatLng(43.18, -2.30),
    'guipuzcoa': LatLng(43.18, -2.30),
    'guipúzcoa': LatLng(43.18, -2.30),
    'araba': LatLng(42.85, -2.68),
    'alava': LatLng(42.85, -2.68),
    'álava': LatLng(42.85, -2.68),
    'nafarroa': LatLng(42.78, -1.65),
    'navarra': LatLng(42.78, -1.65),
    'ipar euskal herria': LatLng(43.30, -1.47),
    'iparralde': LatLng(43.30, -1.47),
    // Catalunya
    'catalunya': LatLng(41.83, 1.47),
    'cataluña': LatLng(41.83, 1.47),
    'catalonia': LatLng(41.83, 1.47),
    'barcelona': LatLng(41.38, 2.17),
    'girona': LatLng(41.98, 2.82),
    'lleida': LatLng(41.62, 0.63),
    'tarragona': LatLng(41.12, 1.25),
    // Galicia
    'galicia': LatLng(42.80, -8.00),
    'galiza': LatLng(42.80, -8.00),
    'a coruña': LatLng(43.37, -8.40),
    'pontevedra': LatLng(42.43, -8.65),
    'lugo': LatLng(43.00, -7.55),
    'ourense': LatLng(42.33, -7.87),
    // País Valencià
    'valencia': LatLng(39.47, -0.38),
    'país valencià': LatLng(39.50, -0.75),
    'valència': LatLng(39.47, -0.38),
    'alicante': LatLng(38.35, -0.48),
    'alacant': LatLng(38.35, -0.48),
    'castelló': LatLng(39.98, -0.03),
    // Andalucía
    'andalucia': LatLng(37.50, -4.50),
    'andalucía': LatLng(37.50, -4.50),
    'sevilla': LatLng(37.39, -5.99),
    'malaga': LatLng(36.72, -4.42),
    'málaga': LatLng(36.72, -4.42),
    'granada': LatLng(37.18, -3.60),
    'cordoba': LatLng(37.88, -4.78),
    'córdoba': LatLng(37.88, -4.78),
    'almeria': LatLng(36.84, -2.46),
    'almería': LatLng(36.84, -2.46),
    'cadiz': LatLng(36.53, -6.30),
    'cádiz': LatLng(36.53, -6.30),
    'huelva': LatLng(37.26, -6.95),
    'jaen': LatLng(37.77, -3.79),
    'jaén': LatLng(37.77, -3.79),
    // Asturias
    'asturias': LatLng(43.30, -6.00),
    'asturies': LatLng(43.30, -6.00),
    'oviedo': LatLng(43.36, -5.85),
    // Madrid
    'madrid': LatLng(40.42, -3.70),
    'comunidad de madrid': LatLng(40.42, -3.70),
    // Aragón
    'aragon': LatLng(41.50, -1.00),
    'aragón': LatLng(41.50, -1.00),
    'zaragoza': LatLng(41.65, -0.89),
    'huesca': LatLng(42.14, -0.41),
    'teruel': LatLng(40.34, -1.11),
    // Castilla
    'castilla y leon': LatLng(41.70, -4.70),
    'castilla y león': LatLng(41.70, -4.70),
    'castilla-la mancha': LatLng(39.50, -3.50),
    'castilla la mancha': LatLng(39.50, -3.50),
    'salamanca': LatLng(40.97, -5.66),
    'valladolid': LatLng(41.65, -4.72),
    // Murcia
    'murcia': LatLng(37.98, -1.13),
    // Cantabria
    'cantabria': LatLng(43.40, -4.00),
    'santander': LatLng(43.46, -3.81),
    // La Rioja
    'la rioja': LatLng(42.30, -2.50),
    'rioja': LatLng(42.30, -2.50),
    // Islas
    'canarias': LatLng(28.30, -16.50),
    'balears': LatLng(39.60, 2.90),
    'baleares': LatLng(39.60, 2.90),
    'mallorca': LatLng(39.60, 2.90),
    'menorca': LatLng(39.95, 4.10),
    'eivissa': LatLng(38.97, 1.40),
    'ibiza': LatLng(38.97, 1.40),
    // Estado
    'estado español': LatLng(40.00, -3.50),
    'estado espanol': LatLng(40.00, -3.50),
    'españa': LatLng(40.00, -3.50),
    'spain': LatLng(40.00, -3.50),
    // Portugal
    'portugal': LatLng(39.50, -8.00),
    'lisboa': LatLng(38.72, -9.14),
    // América y resto del mundo
    'argentina': LatLng(-34.60, -58.38),
    'buenos aires': LatLng(-34.60, -58.38),
    'mendoza': LatLng(-32.89, -68.84),
    'santa fe': LatLng(-31.63, -60.70),
    'trelew': LatLng(-43.25, -65.31),
    'bolivia': LatLng(-16.50, -68.15),
    'la paz': LatLng(-16.50, -68.15),
    'brasil': LatLng(-15.80, -47.90),
    'colombia': LatLng(4.70, -74.10),
    'suba': LatLng(4.75, -74.07),
    'costa rica': LatLng(9.93, -84.08),
    'chile': LatLng(-33.45, -70.67),
    'san felipe': LatLng(-32.75, -70.73),
    'ecuador': LatLng(-0.18, -78.47),
    'saraguro': LatLng(-3.62, -79.23),
    'guatemala': LatLng(14.62, -90.52),
    'honduras': LatLng(14.08, -87.21),
    'nicaragua': LatLng(12.14, -86.25),
    'matagalpa': LatLng(12.92, -85.92),
    'el salvador': LatLng(13.70, -89.20),
    'méxico': LatLng(19.43, -99.13),
    'mexico': LatLng(19.43, -99.13),
    'oaxaca': LatLng(17.07, -96.72),
    'guerrero': LatLng(17.55, -99.50),
    'panamá': LatLng(8.98, -79.52),
    'panama': LatLng(8.98, -79.52),
    'uruguay': LatLng(-34.90, -56.16),
    'paraguay': LatLng(-25.29, -57.64),
    'perú': LatLng(-12.05, -77.04),
    'peru': LatLng(-12.05, -77.04),
    'piura': LatLng(-5.19, -80.63),
    'venezuela': LatLng(10.48, -66.90),
    'caracas': LatLng(10.48, -66.90),
    'república dominicana': LatLng(18.48, -69.91),
    'republica dominicana': LatLng(18.48, -69.91),
    'estados unidos': LatLng(39.83, -98.58),
    'united states': LatLng(39.83, -98.58),
    'oxnard': LatLng(34.20, -119.18),
    'india': LatLng(20.59, 78.96),
  };

  /// Busca un territorio en el lookup. Case-insensitive, tolera trim y
  /// prueba también el primer segmento antes de `,` — muchos medios ponen
  /// "Araba, Euskal Herria" y queremos priorizar la provincia.
  static LatLng? buscar(String territorioBruto) {
    final entrada = territorioBruto.trim().toLowerCase();
    if (entrada.isEmpty) return null;
    if (_coordenadas.containsKey(entrada)) return _coordenadas[entrada];
    // Probar el primer segmento (antes de la primera coma o barra).
    final primerSegmento = entrada.split(RegExp(r'[,/]')).first.trim();
    if (_coordenadas.containsKey(primerSegmento)) {
      return _coordenadas[primerSegmento];
    }
    // Última pasada: buscar cualquier clave como subcadena.
    for (final entry in _coordenadas.entries) {
      if (entrada.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
