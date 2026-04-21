import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flavor_news_hub/core/api/api_exception.dart';
import 'package:flavor_news_hub/core/api/flavor_news_api.dart';

void main() {
  group('FlavorNewsApi.fetchItems', () {
    test('parsea snake_case a camelCase y embebe la source', () async {
      final body = jsonEncode([
        {
          'id': 42,
          'slug': 'noticia-uno',
          'title': 'Noticia uno',
          'excerpt': '<p>Extracto.</p>',
          'url': 'https://instance.example/n/noticia-uno/',
          'original_url': 'https://medio.example/articulo-1',
          'published_at': '2026-04-20T08:00:00+00:00',
          'media_url': 'https://medio.example/img.jpg',
          'source': {
            'id': 10,
            'slug': 'el-medio',
            'name': 'El Medio',
            'website_url': 'https://medio.example',
            'url': 'https://instance.example/f/el-medio/',
          },
          'topics': [
            {'id': 1, 'name': 'Vivienda', 'slug': 'vivienda', 'parent': 0, 'count': 3},
          ],
        }
      ]);

      final clienteMock = MockClient((solicitud) async {
        expect(solicitud.url.path, endsWith('/items'));
        expect(solicitud.url.queryParameters['per_page'], '20');
        return http.Response(body, 200,
            headers: {
              'content-type': 'application/json',
              'x-wp-total': '1',
              'x-wp-totalpages': '1',
            });
      });

      final api = FlavorNewsApi(
        baseUrl: Uri.parse('https://instance.example/wp-json/flavor-news/v1/'),
        httpClient: clienteMock,
      );

      final pagina = await api.fetchItems();

      expect(pagina.items, hasLength(1));
      final item = pagina.items.single;
      expect(item.id, 42);
      expect(item.title, 'Noticia uno');
      expect(item.originalUrl, 'https://medio.example/articulo-1');
      expect(item.publishedAt, '2026-04-20T08:00:00+00:00');
      expect(item.mediaUrl, 'https://medio.example/img.jpg');
      expect(item.source?.name, 'El Medio');
      expect(item.source?.websiteUrl, 'https://medio.example');
      expect(item.topics.single.slug, 'vivienda');
      expect(pagina.total, 1);
      expect(pagina.totalPages, 1);
    });

    test('traduce error 429 a FlavorNewsApiException.estaRateLimited', () async {
      final clienteMock = MockClient((_) async => http.Response(
            jsonEncode({'error': 'rate_limited', 'message': 'slow down'}),
            429,
            headers: {'content-type': 'application/json'},
          ));

      final api = FlavorNewsApi(
        baseUrl: Uri.parse('https://instance.example/wp-json/flavor-news/v1/'),
        httpClient: clienteMock,
      );

      try {
        await api.fetchItems();
        fail('Debía lanzar excepción.');
      } on FlavorNewsApiException catch (error) {
        expect(error.estaRateLimited, isTrue);
        expect(error.statusCode, 429);
        expect(error.message, 'slow down');
      }
    });
  });
}
