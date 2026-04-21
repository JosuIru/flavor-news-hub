import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import '../../../core/providers/preferences_provider.dart';
import 'fuente_personal.dart';

/// Persiste la lista de `FuentePersonal` en SharedPreferences bajo una
/// sola clave JSON. Escrituras son siempre completas (no incrementales),
/// lo cual es barato para listas pequeñas (esperamos decenas, no miles).
class FuentesPersonalesNotifier extends StateNotifier<List<FuentePersonal>> {
  FuentesPersonalesNotifier(this._sharedPrefs) : super(_leerInicial(_sharedPrefs));

  static const _clave = 'fnh.personal_sources';

  final SharedPreferences _sharedPrefs;

  static List<FuentePersonal> _leerInicial(SharedPreferences sp) {
    final cadena = sp.getString(_clave);
    if (cadena == null || cadena.isEmpty) return const [];
    try {
      final lista = jsonDecode(cadena) as List<dynamic>;
      return lista
          .whereType<Map<String, dynamic>>()
          .map(FuentePersonal.fromJson)
          .where((f) => f.feedUrl.isNotEmpty && f.nombre.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistir(List<FuentePersonal> nuevaLista) async {
    state = List.unmodifiable(nuevaLista);
    if (nuevaLista.isEmpty) {
      await _sharedPrefs.remove(_clave);
    } else {
      final cadena = jsonEncode(nuevaLista.map((f) => f.toJson()).toList());
      await _sharedPrefs.setString(_clave, cadena);
    }
  }

  /// Añade una fuente si la URL no existe ya. Devuelve true si se añadió,
  /// false si ya estaba (la UI puede usarlo para avisar al usuario).
  Future<bool> anadir(FuentePersonal nueva) async {
    if (state.any((f) => f.feedUrl == nueva.feedUrl)) {
      return false;
    }
    await _persistir([...state, nueva]);
    return true;
  }

  Future<void> eliminar(String feedUrl) async {
    await _persistir(state.where((f) => f.feedUrl != feedUrl).toList());
  }

  Future<void> reemplazarTodas(List<FuentePersonal> nuevas) async {
    // Deduplicar por feedUrl respetando el primer aparecer.
    final vistas = <String>{};
    final unicas = <FuentePersonal>[];
    for (final fuente in nuevas) {
      if (fuente.feedUrl.isEmpty) continue;
      if (vistas.add(fuente.feedUrl)) {
        unicas.add(fuente);
      }
    }
    await _persistir(unicas);
  }

  /// Exporta la lista como JSON legible (indentado). Útil para que el
  /// usuario copie al portapapeles y guarde por separado.
  String exportarJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(state.map((f) => f.toJson()).toList());
  }

  /// Importa desde una cadena JSON. Reemplaza la lista actual. Devuelve
  /// el número de fuentes importadas o -1 si el JSON era inválido.
  Future<int> importarJson(String cadenaJson) async {
    try {
      final decodificado = jsonDecode(cadenaJson);
      if (decodificado is! List) return -1;
      final fuentesImportadas = decodificado
          .whereType<Map<String, dynamic>>()
          .map(FuentePersonal.fromJson)
          .where((f) => f.feedUrl.isNotEmpty && f.nombre.isNotEmpty)
          .toList();
      await reemplazarTodas(fuentesImportadas);
      return state.length;
    } catch (_) {
      return -1;
    }
  }

  /// Exporta como OPML 2.0 — el formato estándar de intercambio de feeds
  /// entre agregadores (Feedly, Inoreader, NetNewsWire, etc.). Permite al
  /// usuario moverse entre apps sin rehacer la lista de suscripciones.
  String exportarOpml() {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: 'Flavor News Hub - Mis medios');
      });
      builder.element('body', nest: () {
        for (final fuente in state) {
          builder.element('outline', attributes: {
            'type': fuente.tipoFeed == 'atom' ? 'atom' : 'rss',
            'text': fuente.nombre,
            'title': fuente.nombre,
            'xmlUrl': fuente.feedUrl,
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Importa desde una cadena OPML. Añade las fuentes nuevas sin pisar
  /// las existentes (se respetan las ya guardadas; sólo se añaden las que
  /// no colisionen por URL). Devuelve el número de fuentes añadidas o -1
  /// si el OPML es inválido.
  Future<int> importarOpml(String cadenaOpml) async {
    try {
      final doc = XmlDocument.parse(cadenaOpml);
      final urlsExistentes = state.map((f) => f.feedUrl).toSet();
      final nuevas = <FuentePersonal>[];
      final ahora = DateTime.now().toUtc();
      for (final outline in doc.findAllElements('outline')) {
        final url = outline.getAttribute('xmlUrl')?.trim();
        if (url == null || url.isEmpty) continue;
        if (urlsExistentes.contains(url)) continue;
        final nombre = (outline.getAttribute('title') ??
                outline.getAttribute('text') ??
                url)
            .trim();
        if (nombre.isEmpty) continue;
        final tipoOpml = outline.getAttribute('type')?.toLowerCase();
        final tipoFeed = tipoOpml == 'atom' ? 'atom' : 'rss';
        nuevas.add(FuentePersonal(
          nombre: nombre,
          feedUrl: url,
          tipoFeed: tipoFeed,
          anadidaEn: ahora,
        ));
        urlsExistentes.add(url);
      }
      if (nuevas.isEmpty) return 0;
      await _persistir([...state, ...nuevas]);
      return nuevas.length;
    } catch (_) {
      return -1;
    }
  }
}

final fuentesPersonalesProvider =
    StateNotifierProvider<FuentesPersonalesNotifier, List<FuentePersonal>>((ref) {
  final sp = ref.watch(sharedPreferencesProvider);
  return FuentesPersonalesNotifier(sp);
});
