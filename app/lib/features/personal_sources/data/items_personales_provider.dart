import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/item.dart';
import '../../../core/providers/api_provider.dart';
import 'fuente_personal.dart';
import 'fuentes_personales_notifier.dart';
import 'parser_feed_xml.dart';

/// Descarga y parsea todos los feeds personales en paralelo. Devuelve la
/// lista combinada de items. Si un feed falla, se ignora individualmente
/// (un fallo puntual no debe vaciar el listado entero).
final itemsDeFuentesPersonalesProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  final fuentes = ref.watch(fuentesPersonalesProvider);
  if (fuentes.isEmpty) return const [];

  final cliente = ref.watch(httpClientProvider);

  final futuros = fuentes.map((f) => _descargarYParsear(cliente, f));
  final listasPorFuente = await Future.wait(futuros, eagerError: false);

  final combinados = <Item>[];
  for (final lista in listasPorFuente) {
    combinados.addAll(lista);
  }
  combinados.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return combinados;
});

Future<List<Item>> _descargarYParsear(http.Client cliente, FuentePersonal fuente) async {
  try {
    final respuesta = await cliente
        .get(Uri.parse(fuente.feedUrl), headers: const {
          // Algunos servidores (p. ej. YouTube) requieren un UA no-bot.
          'User-Agent': 'FlavorNewsHub/0.1 (+https://github.com/JosuIru/flavor-news-hub)',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml;q=0.9, */*;q=0.8',
        })
        .timeout(const Duration(seconds: 15));
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      return const [];
    }
    return ParserFeedXml.parsear(respuesta.body, fuente);
  } catch (_) {
    return const [];
  }
}
