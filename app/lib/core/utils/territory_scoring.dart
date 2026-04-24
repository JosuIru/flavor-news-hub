import '../models/item.dart';
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

/// Prioridad local de una entidad estática (radio, colectivo, fuente)
/// para ordenar directorios según "de lo local a lo global". A diferencia
/// de [fechaEfectivaLocal], aquí no hay tiempo que penderar — se usa
/// una escala discreta y el resultado se compara directamente en un
/// `sort`. Un número mayor sube antes en la lista.
///
/// Escala:
///   4 — match de ciudad
///   3 — match de región
///   2 — match de país
///   1 — match de red transnacional
///   0 — sin match o sin territorio base
int prioridadLocal({
  required String country,
  required String region,
  required String city,
  required String network,
  required String territorioBase,
}) {
  if (territorioBase.isEmpty) return 0;
  final referencia = TerritoryNormalizer.desglosar(territorioBase);
  if (referencia.city.isNotEmpty && _coincide(city, referencia.city)) return 4;
  if (referencia.region.isNotEmpty && _coincide(region, referencia.region)) return 3;
  if (referencia.country.isNotEmpty && _coincide(country, referencia.country)) return 2;
  if (referencia.network.isNotEmpty && _coincide(network, referencia.network)) return 1;
  return 0;
}

/// Ordena una lista de [Item] aplicando el sesgo local-primero sobre
/// `publishedAt`: si [territorioBase] está fijado, cada item envejece
/// más lento según el match con su `source` (city > region > country >
/// network). Sin territorio base, equivale al orden estándar por
/// `publishedAt` descendente.
///
/// Muta la lista in-place (igual que `List.sort`).
void ordenarItemsLocalPrimero(List<Item> items, String territorioBase) {
  if (territorioBase.isEmpty) {
    items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return;
  }
  final ahora = DateTime.now();
  DateTime efectiva(Item it) => fechaEfectivaLocal(
        publishedAt: DateTime.tryParse(it.publishedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        country: it.source?.country ?? '',
        region: it.source?.region ?? '',
        city: it.source?.city ?? '',
        network: it.source?.network ?? '',
        territorioBase: territorioBase,
        ahora: ahora,
      );
  items.sort((a, b) => efectiva(b).compareTo(efectiva(a)));
}
