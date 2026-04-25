import '../models/item.dart';

/// Descarta items cuyo título tiene mucha proporción de caracteres
/// no-latinos cuando el usuario tiene fijado un idioma latino. Defensa
/// contra items legacy ingestados de feeds que estaban mal etiquetados
/// en el seed (caso típico: Al Mayadeen Español apuntando al canal
/// árabe antes del fix v0.9.54 — sus vídeos quedaron en BD bajo un
/// source que ahora declara `es` y siguen apareciendo en la pestaña
/// Vídeos/TV).
///
/// Heurística:
///  - Sólo aplica cuando los idiomas efectivos son todos latinos
///    (es/ca/eu/gl/en/pt/fr/it). Si el usuario incluye `ar`/`ru`/`zh`
///    en su política, no descartamos nada.
///  - Cuenta caracteres CJK/árabes/cirílicos/devanagari en el título.
///  - Si superan el 30% de los caracteres alfabéticos, descartamos.
///
/// El umbral evita falsos positivos: un titular en castellano puede
/// citar "Madrid أبو ظبي 2026" o emojis, pero si la mitad del título
/// está en árabe, no es contenido en castellano.
List<Item> filtrarContenidoNoLatino(List<Item> items, List<String> idiomasEfectivos) {
  if (idiomasEfectivos.isEmpty) return items;
  const idiomasLatinos = {'es', 'ca', 'eu', 'gl', 'en', 'pt', 'fr', 'it'};
  final todosLatinos = idiomasEfectivos.every(idiomasLatinos.contains);
  if (!todosLatinos) return items;
  return items.where((it) => !_titularDominanteNoLatino(it.title)).toList(growable: false);
}

bool _titularDominanteNoLatino(String titulo) {
  if (titulo.isEmpty) return false;
  var alfabeticos = 0;
  var noLatinos = 0;
  for (final unidad in titulo.runes) {
    if (_esAlfabetico(unidad)) {
      alfabeticos++;
      if (_esNoLatino(unidad)) noLatinos++;
    }
  }
  if (alfabeticos < 8) return false; // títulos cortos: insuficiente señal
  return noLatinos / alfabeticos > 0.3;
}

bool _esAlfabetico(int rune) {
  // Letras latinas básicas + extendidas + bloques no latinos comunes.
  if (rune >= 0x41 && rune <= 0x5A) return true; // A-Z
  if (rune >= 0x61 && rune <= 0x7A) return true; // a-z
  if (rune >= 0xC0 && rune <= 0x024F) return true; // Latin-1 sup + Ext-A/B
  if (_esNoLatino(rune)) return true;
  return false;
}

bool _esNoLatino(int rune) {
  // Árabe (incl. Supplement, Extended-A): 0x0600-0x06FF, 0x0750-0x077F,
  //   0x08A0-0x08FF.
  if (rune >= 0x0600 && rune <= 0x06FF) return true;
  if (rune >= 0x0750 && rune <= 0x077F) return true;
  if (rune >= 0x08A0 && rune <= 0x08FF) return true;
  // Cirílico: 0x0400-0x04FF, 0x0500-0x052F.
  if (rune >= 0x0400 && rune <= 0x052F) return true;
  // Hebreo: 0x0590-0x05FF.
  if (rune >= 0x0590 && rune <= 0x05FF) return true;
  // Griego: 0x0370-0x03FF.
  if (rune >= 0x0370 && rune <= 0x03FF) return true;
  // Devanagari (hindi): 0x0900-0x097F.
  if (rune >= 0x0900 && rune <= 0x097F) return true;
  // CJK (chino/japonés/coreano): bloques unificados.
  if (rune >= 0x3040 && rune <= 0x309F) return true; // hiragana
  if (rune >= 0x30A0 && rune <= 0x30FF) return true; // katakana
  if (rune >= 0x4E00 && rune <= 0x9FFF) return true; // CJK Unified
  if (rune >= 0xAC00 && rune <= 0xD7AF) return true; // hangul
  return false;
}
