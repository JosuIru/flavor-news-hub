import 'package:flavor_news_hub/core/models/item.dart';
import 'package:flavor_news_hub/core/models/topic.dart';
import 'package:flavor_news_hub/features/feed/data/topic_dominante.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests de la función pura que elige la temática dominante del feed —
/// la base de la tarjeta "¿quién se organiza?" intercalada, que con esto
/// hace una sola consulta en vez de una por titular.
void main() {
  Topic topic(String slug) => Topic(id: slug.hashCode, name: slug, slug: slug);

  Item item(List<String> slugsTopics) => Item(
        id: slugsTopics.hashCode,
        slug: 'item-${slugsTopics.join("-")}',
        title: 'Titular',
        topics: slugsTopics.map(topic).toList(),
      );

  group('topicDominante', () {
    test('sin temáticas en ningún item devuelve null', () {
      expect(topicDominante([item([]), item([])]), isNull);
    });

    test('lista vacía devuelve null', () {
      expect(topicDominante(const []), isNull);
    });

    test('elige la temática más frecuente', () {
      final items = [
        item(['vivienda']),
        item(['clima']),
        item(['vivienda']),
        item(['vivienda']),
      ];
      expect(topicDominante(items)?.slug, 'vivienda');
    });

    test('ante empate gana la que aparece antes en el feed', () {
      final items = [
        item(['clima']),
        item(['vivienda']),
      ];
      // Una aparición cada una: gana 'clima' por estar más arriba.
      expect(topicDominante(items)?.slug, 'clima');
    });

    test('cuenta varias temáticas por item', () {
      final items = [
        item(['vivienda', 'clima']),
        item(['clima']),
      ];
      expect(topicDominante(items)?.slug, 'clima');
    });

    test('devuelve el Topic completo, no solo el slug', () {
      final resultado = topicDominante([item(['migracion'])]);
      expect(resultado, isNotNull);
      expect(resultado!.slug, 'migracion');
      expect(resultado.name, 'migracion');
    });
  });
}
