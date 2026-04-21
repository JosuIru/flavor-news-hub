import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/item.dart';
import '../../personal_sources/data/fuente_personal.dart';
import '../../personal_sources/data/parser_feed_xml.dart';

/// Descarga y parsea el RSS de programas de una radio.
///
/// Reutilizamos `ParserFeedXml` de personal_sources: el formato es el mismo
/// (RSS/Atom) y así el cliente maneja los tres flujos (feeds personales,
/// programas de radio, y en teoría cualquier otro feed público) con una
/// sola implementación.
final programasRadioProvider = FutureProvider.autoDispose
    .family<List<Item>, _ArgumentosProgramas>((ref, args) async {
  if (args.rssUrl.isEmpty) return const [];
  final uri = Uri.tryParse(args.rssUrl);
  if (uri == null) return const [];

  final resp = await http.get(uri).timeout(const Duration(seconds: 15));
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    throw 'HTTP ${resp.statusCode}';
  }
  final fuenteSintetica = FuentePersonal(
    nombre: args.nombreRadio,
    feedUrl: args.rssUrl,
    tipoFeed: 'podcast',
    anadidaEn: DateTime.now().toUtc(),
  );
  final items = ParserFeedXml.parsear(resp.body, fuenteSintetica);
  return items.take(20).toList(growable: false);
});

class _ArgumentosProgramas {
  const _ArgumentosProgramas({required this.nombreRadio, required this.rssUrl});
  final String nombreRadio;
  final String rssUrl;

  @override
  bool operator ==(Object other) =>
      other is _ArgumentosProgramas &&
      other.nombreRadio == nombreRadio &&
      other.rssUrl == rssUrl;

  @override
  int get hashCode => Object.hash(nombreRadio, rssUrl);
}

/// Helper público para construir el argumento family sin exportar el tipo
/// privado.
ProviderListenable<AsyncValue<List<Item>>> programasPara({
  required String nombreRadio,
  required String rssUrl,
}) {
  return programasRadioProvider(_ArgumentosProgramas(
    nombreRadio: nombreRadio,
    rssUrl: rssUrl,
  ));
}
