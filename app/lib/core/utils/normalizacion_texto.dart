/// Normaliza texto para búsqueda: minúsculas + sin diacríticos
/// (acentos, tildes, ñ→n, ç→c, etc).
///
/// Usado por el fallback offline del buscador para que "cataluna"
/// encuentre "Cataluña" y "bilbo" encuentre "Bilbó". El backend con
/// `search:` delega en WP, que tiene su propia política de
/// collation. Aquí es estrictamente una mejora del modo offline.
String normalizarParaBusqueda(String texto) {
  final minuscula = texto.toLowerCase();
  return _quitarDiacriticos(minuscula);
}

/// Elimina marcas combinables Unicode (rango U+0300..U+036F) tras
/// descomponer el texto a NFD. Es la receta estándar para "stripping
/// accents" sin depender de paquetes externos.
String _quitarDiacriticos(String texto) {
  final buf = StringBuffer();
  for (final cp in texto.runes) {
    // Casos especiales que NFD no descompone porque son letras
    // independientes (no "n con tilde combinable"): ñ → n, ç → c.
    // Mismo trato a sus mayúsculas para que la función sea robusta
    // si el caller no llamó toLowerCase antes.
    if (cp == 0x00F1 /* ñ */ || cp == 0x00D1 /* Ñ */) {
      buf.writeCharCode(cp == 0x00F1 ? 0x6E : 0x4E); // n / N
      continue;
    }
    if (cp == 0x00E7 /* ç */ || cp == 0x00C7 /* Ç */) {
      buf.writeCharCode(cp == 0x00E7 ? 0x63 : 0x43); // c / C
      continue;
    }
    // Resto: mantenemos el carácter base. Como no descomponemos a NFD
    // (eso requiere `package:characters` o Intl), tratamos los
    // diacríticos pre-compuestos comunes a mano para mantener la
    // función dependency-free.
    if (cp >= 0x00C0 && cp <= 0x017F) {
      // Bloque Latin Extended-A/B con vocales acentuadas más comunes.
      final base = _baseLatina(cp);
      if (base != null) {
        buf.writeCharCode(base);
        continue;
      }
    }
    buf.writeCharCode(cp);
  }
  return buf.toString();
}

/// Mapeo manual de codepoints latin-1/extended-A a su letra base sin
/// diacríticos. Cubre lo realmente útil para búsqueda en ES/CA/EU/GL/EN/PT.
int? _baseLatina(int cp) {
  // À Á Â Ã Ä Å → A; à á â ã ä å → a
  if ((cp >= 0x00C0 && cp <= 0x00C5)) return 0x41;
  if ((cp >= 0x00E0 && cp <= 0x00E5)) return 0x61;
  // È É Ê Ë → E; è é ê ë → e
  if ((cp >= 0x00C8 && cp <= 0x00CB)) return 0x45;
  if ((cp >= 0x00E8 && cp <= 0x00EB)) return 0x65;
  // Ì Í Î Ï → I; ì í î ï → i
  if ((cp >= 0x00CC && cp <= 0x00CF)) return 0x49;
  if ((cp >= 0x00EC && cp <= 0x00EF)) return 0x69;
  // Ò Ó Ô Õ Ö → O; ò ó ô õ ö → o
  if ((cp >= 0x00D2 && cp <= 0x00D6)) return 0x4F;
  if ((cp >= 0x00F2 && cp <= 0x00F6)) return 0x6F;
  // Ù Ú Û Ü → U; ù ú û ü → u
  if ((cp >= 0x00D9 && cp <= 0x00DC)) return 0x55;
  if ((cp >= 0x00F9 && cp <= 0x00FC)) return 0x75;
  // Ý → Y; ý ÿ → y
  if (cp == 0x00DD) return 0x59;
  if (cp == 0x00FD || cp == 0x00FF) return 0x79;
  return null;
}
