import '../../../core/models/item.dart';
import '../../../core/models/topic.dart';

/// Devuelve la temática más frecuente entre los items dados, o null si
/// ninguno trae temáticas. La usa el feed para decidir sobre qué tema
/// ofrecer la tarjeta de "¿quién se organiza?" con una sola consulta, en
/// vez de una por titular.
///
/// Ante empate gana la temática que aparece antes en el feed (más reciente),
/// que es lo que el usuario tiene más a mano.
Topic? topicDominante(List<Item> items) {
  final conteoPorSlug = <String, int>{};
  final primeraAparicion = <String, int>{};
  final topicPorSlug = <String, Topic>{};

  var orden = 0;
  for (final item in items) {
    for (final topic in item.topics) {
      conteoPorSlug.update(topic.slug, (n) => n + 1, ifAbsent: () => 1);
      primeraAparicion.putIfAbsent(topic.slug, () => orden);
      topicPorSlug.putIfAbsent(topic.slug, () => topic);
      orden++;
    }
  }

  if (conteoPorSlug.isEmpty) return null;

  String? slugGanador;
  for (final slug in conteoPorSlug.keys) {
    if (slugGanador == null) {
      slugGanador = slug;
      continue;
    }
    final mejor = conteoPorSlug[slugGanador]!;
    final candidato = conteoPorSlug[slug]!;
    if (candidato > mejor ||
        (candidato == mejor &&
            primeraAparicion[slug]! < primeraAparicion[slugGanador]!)) {
      slugGanador = slug;
    }
  }

  return topicPorSlug[slugGanador];
}
