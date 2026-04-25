import '../models/item.dart';
import 'territory_normalizer.dart';

/// Multiplicador adicional para fuentes marcadas como movimiento social
/// o medio militante pequeño. El principio: "voces críticas no se tapan".
/// Aplica un envejecimiento más lento (factor 0.85) para que items de
/// medios pequeños/militantes no queden enterrados bajo agregadores
/// prolíficos. Se compone con el factor territorial multiplicativamente,
/// así un medio local-y-movimiento sube todavía más.
const double _factorMovimiento = 0.85;

/// Devuelve la fecha "efectiva" de un contenido para ordenarlo con
/// sesgo local-primero y boost para movimientos sociales. El principio
/// editorial: "de lo local a lo global", sin ocultar nada — los items
/// cercanos al territorio base del usuario envejecen más lento, así
/// suben por encima de los globales de edad similar pero no tapan al
/// breaking news mundial. Adicionalmente, fuentes marcadas como
/// movimiento social reciben un boost suave para que no queden ocultas
/// por agregadores prolíficos.
///
/// Si [territorioBase] está vacío y [esMovimiento] es false, devuelve
/// [publishedAt] tal cual (comportamiento neutro).
///
/// Factores de envejecimiento territorial (cuanto más pequeño, más sube):
///   - city match:    0.3
///   - region match:  0.5
///   - country match: 0.7
///   - network match: 0.8
///   - sin match:     1.0 (sin sesgo)
///
/// Si [esMovimiento] es true, el factor se multiplica por 0.85 adicional.
DateTime fechaEfectivaLocal({
  required DateTime publishedAt,
  required String country,
  required String region,
  required String city,
  required String network,
  required String territorioBase,
  bool esMovimiento = false,
  DateTime? ahora,
}) {
  double factor = 1.0;
  if (territorioBase.isNotEmpty) {
    final referencia = TerritoryNormalizer.desglosar(territorioBase);
    factor = _factorEdad(
      country: country,
      region: region,
      city: city,
      network: network,
      referencia: referencia,
    );
  }
  if (esMovimiento) {
    factor *= _factorMovimiento;
  }
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
/// network). Items de fuentes marcadas como movimiento reciben además
/// un boost suave (0.85) para que no queden ocultos por agregadores
/// prolíficos, incluso sin territorio base.
///
/// Tras el sort por fecha efectiva, aplica una diversificación
/// anti-monopolio que evita que un agregador prolífico (ej. un canal
/// que publica 30 items/día) tape al resto: si hay más de
/// `maxConsecutivosPorFuente` items consecutivos de la misma source,
/// se intercala uno de otra fuente con fecha cercana. El orden
/// cronológico global se respeta razonablemente — esto sólo afecta
/// al desempate dentro de ventanas de minutos/horas, no rompe la
/// linealidad temporal de horas/días.
///
/// Muta la lista in-place (igual que `List.sort`).
void ordenarItemsLocalPrimero(
  List<Item> items,
  String territorioBase, {
  int maxConsecutivosPorFuente = 2,
}) {
  final ahora = DateTime.now();
  DateTime efectiva(Item it) => fechaEfectivaLocal(
        publishedAt: DateTime.tryParse(it.publishedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        country: it.source?.country ?? '',
        region: it.source?.region ?? '',
        city: it.source?.city ?? '',
        network: it.source?.network ?? '',
        territorioBase: territorioBase,
        esMovimiento: it.source?.esMovimiento ?? false,
        ahora: ahora,
      );
  items.sort((a, b) => efectiva(b).compareTo(efectiva(a)));
  if (maxConsecutivosPorFuente > 0 &&
      items.length > maxConsecutivosPorFuente + 1) {
    _diversificarPorFuente(items, maxConsecutivosPorFuente);
  }
}

/// Reordena la lista YA ordenada por fecha de modo que ninguna fuente
/// aparezca más de [maxConsecutivos] veces seguidas. Usa una pasada
/// lineal con un buffer de "siguiente candidato" — si el siguiente en
/// la cola pendiente romper la regla, se promociona al primero
/// posterior con source distinta. Resto del orden se respeta.
void _diversificarPorFuente(List<Item> items, int maxConsecutivos) {
  if (items.length <= maxConsecutivos + 1) return;
  final pendientes = List<Item>.from(items);
  items.clear();
  while (pendientes.isNotEmpty) {
    int idxElegido = 0;
    if (items.length >= maxConsecutivos) {
      // Si los últimos N items son de la misma fuente, buscamos el
      // primer pendiente con source distinta. Si no existe, dejamos
      // el natural — el cluster es inevitable porque el resto del
      // feed también es de esa fuente.
      final referencia = items[items.length - 1].source?.id;
      bool todosIguales = referencia != null;
      if (todosIguales) {
        for (int i = items.length - maxConsecutivos; i < items.length; i++) {
          if (items[i].source?.id != referencia) {
            todosIguales = false;
            break;
          }
        }
      }
      if (todosIguales) {
        for (int i = 0; i < pendientes.length; i++) {
          if (pendientes[i].source?.id != referencia) {
            idxElegido = i;
            break;
          }
        }
      }
    }
    items.add(pendientes.removeAt(idxElegido));
  }
}
