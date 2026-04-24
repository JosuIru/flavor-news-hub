class TerritoryLocation {
  const TerritoryLocation({
    required this.country,
    required this.region,
    required this.city,
    required this.network,
  });

  final String country;
  final String region;
  final String city;
  final String network;
}

/// Entrada del selector "Mi territorio" en ajustes.
///
/// `clave` es lo que se guarda en SharedPreferences y lo que se pasa a
/// [TerritoryNormalizer.desglosar]; `etiqueta` es el nombre visible; y
/// `grupo` sirve sólo para cabeceras de sección en el bottom sheet.
class TerritoryOption {
  const TerritoryOption({
    required this.clave,
    required this.etiqueta,
    required this.grupo,
  });

  final String clave;
  final String etiqueta;
  final String grupo;
}

class TerritoryNormalizer {
  /// Lista curada para el selector "Mi territorio" en Ajustes.
  ///
  /// No es el mapa completo del normalizer (ese sólo lo usamos para
  /// transformar etiquetas libres del catálogo). Esta lista es lo que
  /// ofrecemos al usuario para fijar su ubicación base — por eso
  /// incluye redes transnacionales, naciones/regiones del Estado
  /// español, Ipar Euskal Herria y una selección de países y grandes
  /// ciudades de Latinoamérica. Se ordena por grupo y dentro de cada
  /// grupo de más específico a más general.
  static List<TerritoryOption> listarOpcionesCuradas() {
    return const [
      // Redes / marcos transnacionales.
      TerritoryOption(clave: 'euskal herria', etiqueta: 'Euskal Herria', grupo: 'Redes'),
      TerritoryOption(clave: 'latinoamerica', etiqueta: 'Latinoamérica', grupo: 'Redes'),
      TerritoryOption(clave: 'mesoamerica', etiqueta: 'Mesoamérica', grupo: 'Redes'),
      TerritoryOption(clave: 'wallmapu', etiqueta: 'Wallmapu', grupo: 'Redes'),
      TerritoryOption(clave: 'internacional', etiqueta: 'Internacional', grupo: 'Redes'),

      // Estado español — regiones habituales.
      TerritoryOption(clave: 'bizkaia', etiqueta: 'Bizkaia', grupo: 'Estado español'),
      TerritoryOption(clave: 'gipuzkoa', etiqueta: 'Gipuzkoa', grupo: 'Estado español'),
      TerritoryOption(clave: 'araba', etiqueta: 'Araba', grupo: 'Estado español'),
      TerritoryOption(clave: 'nafarroa', etiqueta: 'Nafarroa', grupo: 'Estado español'),
      TerritoryOption(clave: 'euskadi', etiqueta: 'Euskadi', grupo: 'Estado español'),
      TerritoryOption(clave: 'catalunya', etiqueta: 'Catalunya', grupo: 'Estado español'),
      TerritoryOption(clave: 'país valencià', etiqueta: 'País Valencià', grupo: 'Estado español'),
      TerritoryOption(clave: 'galicia', etiqueta: 'Galicia', grupo: 'Estado español'),
      TerritoryOption(clave: 'andalucía', etiqueta: 'Andalucía', grupo: 'Estado español'),
      TerritoryOption(clave: 'madrid', etiqueta: 'Madrid', grupo: 'Estado español'),
      TerritoryOption(clave: 'asturias', etiqueta: 'Asturias', grupo: 'Estado español'),
      TerritoryOption(clave: 'aragón', etiqueta: 'Aragón', grupo: 'Estado español'),
      TerritoryOption(clave: 'cantabria', etiqueta: 'Cantabria', grupo: 'Estado español'),
      TerritoryOption(clave: 'castilla y león', etiqueta: 'Castilla y León', grupo: 'Estado español'),
      TerritoryOption(clave: 'castilla-la mancha', etiqueta: 'Castilla-La Mancha', grupo: 'Estado español'),
      TerritoryOption(clave: 'la rioja', etiqueta: 'La Rioja', grupo: 'Estado español'),
      TerritoryOption(clave: 'murcia', etiqueta: 'Murcia', grupo: 'Estado español'),
      TerritoryOption(clave: 'canarias', etiqueta: 'Canarias', grupo: 'Estado español'),
      TerritoryOption(clave: 'balears', etiqueta: 'Illes Balears', grupo: 'Estado español'),
      TerritoryOption(clave: 'españa', etiqueta: 'España (todo el Estado)', grupo: 'Estado español'),

      // Iparralde.
      TerritoryOption(clave: 'ipar euskal herria', etiqueta: 'Ipar Euskal Herria', grupo: 'Francia'),

      // Portugal.
      TerritoryOption(clave: 'portugal', etiqueta: 'Portugal', grupo: 'Portugal'),
      TerritoryOption(clave: 'lisboa', etiqueta: 'Lisboa', grupo: 'Portugal'),

      // América.
      TerritoryOption(clave: 'argentina', etiqueta: 'Argentina', grupo: 'América'),
      TerritoryOption(clave: 'bolivia', etiqueta: 'Bolivia', grupo: 'América'),
      TerritoryOption(clave: 'brasil', etiqueta: 'Brasil', grupo: 'América'),
      TerritoryOption(clave: 'chile', etiqueta: 'Chile', grupo: 'América'),
      TerritoryOption(clave: 'colombia', etiqueta: 'Colombia', grupo: 'América'),
      TerritoryOption(clave: 'costa rica', etiqueta: 'Costa Rica', grupo: 'América'),
      TerritoryOption(clave: 'ecuador', etiqueta: 'Ecuador', grupo: 'América'),
      TerritoryOption(clave: 'el salvador', etiqueta: 'El Salvador', grupo: 'América'),
      TerritoryOption(clave: 'estados unidos', etiqueta: 'Estados Unidos', grupo: 'América'),
      TerritoryOption(clave: 'guatemala', etiqueta: 'Guatemala', grupo: 'América'),
      TerritoryOption(clave: 'honduras', etiqueta: 'Honduras', grupo: 'América'),
      TerritoryOption(clave: 'méxico', etiqueta: 'México', grupo: 'América'),
      TerritoryOption(clave: 'nicaragua', etiqueta: 'Nicaragua', grupo: 'América'),
      TerritoryOption(clave: 'panamá', etiqueta: 'Panamá', grupo: 'América'),
      TerritoryOption(clave: 'paraguay', etiqueta: 'Paraguay', grupo: 'América'),
      TerritoryOption(clave: 'perú', etiqueta: 'Perú', grupo: 'América'),
      TerritoryOption(clave: 'república dominicana', etiqueta: 'República Dominicana', grupo: 'América'),
      TerritoryOption(clave: 'uruguay', etiqueta: 'Uruguay', grupo: 'América'),
      TerritoryOption(clave: 'venezuela', etiqueta: 'Venezuela', grupo: 'América'),

      // Asia.
      TerritoryOption(clave: 'india', etiqueta: 'India', grupo: 'Asia'),
    ];
  }

  /// Etiqueta humana (en castellano, con tildes) de una clave guardada
  /// en prefs. Devuelve cadena vacía si no existe — útil para recuperar
  /// el label sin tener que recorrer la lista desde cada pantalla.
  static String etiquetaDeClave(String clave) {
    if (clave.isEmpty) return '';
    for (final opcion in listarOpcionesCuradas()) {
      if (opcion.clave == clave) return opcion.etiqueta;
    }
    return clave;
  }

  static TerritoryLocation desglosar(String territory) {
    final key = _normalizarCadena(territory);
    if (key.isEmpty) {
      return const TerritoryLocation(country: '', region: '', city: '', network: '');
    }

    final match = _mapa()[key];
    if (match != null) {
      return match;
    }

    final parts = key.split(RegExp(r'[,/]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      final first = desglosar(parts.first);
      if (first.country.isNotEmpty || first.region.isNotEmpty || first.city.isNotEmpty || first.network.isNotEmpty) {
        return first;
      }
      final second = desglosar(parts[1]);
      if (second.country.isNotEmpty || second.region.isNotEmpty || second.city.isNotEmpty || second.network.isNotEmpty) {
        return second;
      }
    }

    return const TerritoryLocation(country: '', region: '', city: '', network: '');
  }

  static Map<String, TerritoryLocation> _mapa() {
    return {
      'internacional': const TerritoryLocation(country: '', region: '', city: '', network: 'Internacional'),
      'latinoamerica': const TerritoryLocation(country: '', region: '', city: '', network: 'Latinoamérica'),
      'latinoamérica': const TerritoryLocation(country: '', region: '', city: '', network: 'Latinoamérica'),
      'mesoamerica': const TerritoryLocation(country: '', region: '', city: '', network: 'Mesoamérica'),
      'mesoamérica': const TerritoryLocation(country: '', region: '', city: '', network: 'Mesoamérica'),
      'wallmapu': const TerritoryLocation(country: '', region: '', city: '', network: 'Wallmapu'),
      'euskal herria': const TerritoryLocation(country: '', region: '', city: '', network: 'Euskal Herria'),
      'estado espanol': const TerritoryLocation(country: 'España', region: '', city: '', network: ''),
      'estado español': const TerritoryLocation(country: 'España', region: '', city: '', network: ''),
      'españa': const TerritoryLocation(country: 'España', region: '', city: '', network: ''),
      'spain': const TerritoryLocation(country: 'España', region: '', city: '', network: ''),
      'catalunya': const TerritoryLocation(country: 'España', region: 'Catalunya', city: '', network: ''),
      'cataluña': const TerritoryLocation(country: 'España', region: 'Cataluña', city: '', network: ''),
      'euskadi': const TerritoryLocation(country: 'España', region: 'Euskadi', city: '', network: ''),
      'pais vasco': const TerritoryLocation(country: 'España', region: 'País Vasco', city: '', network: ''),
      'país vasco': const TerritoryLocation(country: 'España', region: 'País Vasco', city: '', network: ''),
      'bizkaia': const TerritoryLocation(country: 'España', region: 'Bizkaia', city: '', network: ''),
      'vizcaya': const TerritoryLocation(country: 'España', region: 'Bizkaia', city: '', network: ''),
      'gipuzkoa': const TerritoryLocation(country: 'España', region: 'Gipuzkoa', city: '', network: ''),
      'guipuzcoa': const TerritoryLocation(country: 'España', region: 'Gipuzkoa', city: '', network: ''),
      'guipúzcoa': const TerritoryLocation(country: 'España', region: 'Gipuzkoa', city: '', network: ''),
      'araba': const TerritoryLocation(country: 'España', region: 'Araba', city: '', network: ''),
      'alava': const TerritoryLocation(country: 'España', region: 'Araba', city: '', network: ''),
      'álava': const TerritoryLocation(country: 'España', region: 'Araba', city: '', network: ''),
      'nafarroa': const TerritoryLocation(country: 'España', region: 'Nafarroa', city: '', network: ''),
      'navarra': const TerritoryLocation(country: 'España', region: 'Navarra', city: '', network: ''),
      'ipar euskal herria': const TerritoryLocation(country: 'Francia', region: 'Ipar Euskal Herria', city: '', network: ''),
      'iparralde': const TerritoryLocation(country: 'Francia', region: 'Ipar Euskal Herria', city: '', network: ''),
      'madrid': const TerritoryLocation(country: 'España', region: 'Madrid', city: '', network: ''),
      'comunidad de madrid': const TerritoryLocation(country: 'España', region: 'Comunidad de Madrid', city: '', network: ''),
      'andalucia': const TerritoryLocation(country: 'España', region: 'Andalucía', city: '', network: ''),
      'andalucía': const TerritoryLocation(country: 'España', region: 'Andalucía', city: '', network: ''),
      'galicia': const TerritoryLocation(country: 'España', region: 'Galicia', city: '', network: ''),
      'galiza': const TerritoryLocation(country: 'España', region: 'Galicia', city: '', network: ''),
      'país valencià': const TerritoryLocation(country: 'España', region: 'País Valencià', city: '', network: ''),
      'pais valencià': const TerritoryLocation(country: 'España', region: 'País Valencià', city: '', network: ''),
      'país valencia': const TerritoryLocation(country: 'España', region: 'País Valencià', city: '', network: ''),
      'valencia': const TerritoryLocation(country: 'España', region: 'Valencia', city: '', network: ''),
      'valència': const TerritoryLocation(country: 'España', region: 'València', city: '', network: ''),
      'murcia': const TerritoryLocation(country: 'España', region: 'Murcia', city: '', network: ''),
      'cantabria': const TerritoryLocation(country: 'España', region: 'Cantabria', city: '', network: ''),
      'asturias': const TerritoryLocation(country: 'España', region: 'Asturias', city: '', network: ''),
      'asturies': const TerritoryLocation(country: 'España', region: 'Asturies', city: '', network: ''),
      'aragon': const TerritoryLocation(country: 'España', region: 'Aragón', city: '', network: ''),
      'aragón': const TerritoryLocation(country: 'España', region: 'Aragón', city: '', network: ''),
      'castilla y leon': const TerritoryLocation(country: 'España', region: 'Castilla y León', city: '', network: ''),
      'castilla y león': const TerritoryLocation(country: 'España', region: 'Castilla y León', city: '', network: ''),
      'castilla-la mancha': const TerritoryLocation(country: 'España', region: 'Castilla-La Mancha', city: '', network: ''),
      'castilla la mancha': const TerritoryLocation(country: 'España', region: 'Castilla-La Mancha', city: '', network: ''),
      'la rioja': const TerritoryLocation(country: 'España', region: 'La Rioja', city: '', network: ''),
      'rioja': const TerritoryLocation(country: 'España', region: 'La Rioja', city: '', network: ''),
      'canarias': const TerritoryLocation(country: 'España', region: 'Canarias', city: '', network: ''),
      'balears': const TerritoryLocation(country: 'España', region: 'Illes Balears', city: '', network: ''),
      'baleares': const TerritoryLocation(country: 'España', region: 'Islas Baleares', city: '', network: ''),
      'portugal': const TerritoryLocation(country: 'Portugal', region: '', city: '', network: ''),
      'lisboa': const TerritoryLocation(country: 'Portugal', region: 'Lisboa', city: '', network: ''),
      'argentina': const TerritoryLocation(country: 'Argentina', region: '', city: '', network: ''),
      'buenos aires': const TerritoryLocation(country: 'Argentina', region: '', city: 'Buenos Aires', network: ''),
      'mendoza': const TerritoryLocation(country: 'Argentina', region: '', city: 'Mendoza', network: ''),
      'santa fe': const TerritoryLocation(country: 'Argentina', region: '', city: 'Santa Fe', network: ''),
      'trelew': const TerritoryLocation(country: 'Argentina', region: '', city: 'Trelew', network: ''),
      'bolivia': const TerritoryLocation(country: 'Bolivia', region: '', city: '', network: ''),
      'la paz': const TerritoryLocation(country: 'Bolivia', region: '', city: 'La Paz', network: ''),
      'brasil': const TerritoryLocation(country: 'Brasil', region: '', city: '', network: ''),
      'colombia': const TerritoryLocation(country: 'Colombia', region: '', city: '', network: ''),
      'suba': const TerritoryLocation(country: 'Colombia', region: '', city: 'Suba', network: ''),
      'costa rica': const TerritoryLocation(country: 'Costa Rica', region: '', city: '', network: ''),
      'chile': const TerritoryLocation(country: 'Chile', region: '', city: '', network: ''),
      'san felipe': const TerritoryLocation(country: 'Chile', region: '', city: 'San Felipe', network: ''),
      'ecuador': const TerritoryLocation(country: 'Ecuador', region: '', city: '', network: ''),
      'saraguro': const TerritoryLocation(country: 'Ecuador', region: '', city: 'Saraguro', network: ''),
      'guatemala': const TerritoryLocation(country: 'Guatemala', region: '', city: '', network: ''),
      'honduras': const TerritoryLocation(country: 'Honduras', region: '', city: '', network: ''),
      'nicaragua': const TerritoryLocation(country: 'Nicaragua', region: '', city: '', network: ''),
      'matagalpa': const TerritoryLocation(country: 'Nicaragua', region: '', city: 'Matagalpa', network: ''),
      'el salvador': const TerritoryLocation(country: 'El Salvador', region: '', city: '', network: ''),
      'méxico': const TerritoryLocation(country: 'México', region: '', city: '', network: ''),
      'mexico': const TerritoryLocation(country: 'México', region: '', city: '', network: ''),
      'oaxaca': const TerritoryLocation(country: 'México', region: '', city: 'Oaxaca', network: ''),
      'guerrero': const TerritoryLocation(country: 'México', region: 'Guerrero', city: '', network: ''),
      'panamá': const TerritoryLocation(country: 'Panamá', region: '', city: '', network: ''),
      'panama': const TerritoryLocation(country: 'Panamá', region: '', city: '', network: ''),
      'uruguay': const TerritoryLocation(country: 'Uruguay', region: '', city: '', network: ''),
      'paraguay': const TerritoryLocation(country: 'Paraguay', region: '', city: '', network: ''),
      'perú': const TerritoryLocation(country: 'Perú', region: '', city: '', network: ''),
      'peru': const TerritoryLocation(country: 'Perú', region: '', city: '', network: ''),
      'piura': const TerritoryLocation(country: 'Perú', region: '', city: 'Piura', network: ''),
      'venezuela': const TerritoryLocation(country: 'Venezuela', region: '', city: '', network: ''),
      'caracas': const TerritoryLocation(country: 'Venezuela', region: '', city: 'Caracas', network: ''),
      'república dominicana': const TerritoryLocation(country: 'República Dominicana', region: '', city: '', network: ''),
      'republica dominicana': const TerritoryLocation(country: 'República Dominicana', region: '', city: '', network: ''),
      'estados unidos': const TerritoryLocation(country: 'Estados Unidos', region: '', city: '', network: ''),
      'united states': const TerritoryLocation(country: 'Estados Unidos', region: '', city: '', network: ''),
      'oxnard': const TerritoryLocation(country: 'Estados Unidos', region: '', city: 'Oxnard', network: ''),
      'india': const TerritoryLocation(country: 'India', region: '', city: '', network: ''),
    };
  }

  static String _normalizarCadena(String value) {
    var out = value.trim().toLowerCase();
    out = out.replaceAll(RegExp(r'[-_]'), ' ');
    out = out
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n');
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
