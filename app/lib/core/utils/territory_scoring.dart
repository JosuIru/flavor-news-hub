import 'territory_normalizer.dart';

/// Devuelve la fecha "efectiva" de un contenido para ordenarlo con
/// sesgo local-primero. El principio editorial: "de lo local a lo
/// global", sin ocultar nada — los items cercanos al territorio base
/// del usuario envejecen más lento, así suben por encima de los
/// globales de edad similar pero no tapan al breaking news mundial.
///
/// Si [territorioBase] está vacío, devuelve [publishedAt] tal cual
/// (comportamiento neutro: el feed se ordena por fecha real).
///
/// Factores de envejecimiento (cuanto más pequeño, más sube):
///   - city match:    0.3
///   - region match:  0.5
///   - country match: 0.7
///   - network match: 0.8
///   - sin match:     1.0 (sin sesgo)
DateTime fechaEfectivaLocal({
  required DateTime publishedAt,
  required String country,
  required String region,
  required String city,
  required String network,
  required String territorioBase,
  DateTime? ahora,
}) {
  if (territorioBase.isEmpty) return publishedAt;
  final referencia = TerritoryNormalizer.desglosar(territorioBase);
  final factor = _factorEdad(
    country: country,
    region: region,
    city: city,
    network: network,
    referencia: referencia,
  );
  if (factor >= 1.0) return publishedAt;
  final momentoActual = ahora ?? DateTime.now();
  if (!publishedAt.isBefore(momentoActual)) return publishedAt;
  final edadReal = momentoActual.difference(publishedAt);
  final edadAjustada = Duration(
    microseconds: (edadReal.inMicroseconds * factor).round(),
  );
  return momentoActual.subtract(edadAjustada);
}

double _factorEdad({
  required String country,
  required String region,
  required String city,
  required String network,
  required TerritoryLocation referencia,
}) {
  // El match más específico gana. Orden: ciudad > región > país > red.
  if (referencia.city.isNotEmpty && _coincide(city, referencia.city)) {
    return 0.3;
  }
  if (referencia.region.isNotEmpty && _coincide(region, referencia.region)) {
    return 0.5;
  }
  if (referencia.country.isNotEmpty && _coincide(country, referencia.country)) {
    return 0.7;
  }
  if (referencia.network.isNotEmpty && _coincide(network, referencia.network)) {
    return 0.8;
  }
  return 1.0;
}

bool _coincide(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  return a.toLowerCase().trim() == b.toLowerCase().trim();
}
