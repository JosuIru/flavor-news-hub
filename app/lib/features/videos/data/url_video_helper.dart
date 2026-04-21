/// Utilidades para identificar y transformar URLs de vídeo en formatos
/// reproducibles in-app (embed oficial de YouTube, embed de PeerTube, MP4
/// directo) o decidir que hace falta delegar al navegador externo.
class UrlVideoHelper {
  UrlVideoHelper._();

  /// Si el URL es un vídeo de YouTube, devuelve la URL de embed oficial
  /// (`https://www.youtube.com/embed/<id>?rel=0`). Null si no lo reconoce.
  ///
  /// Usar `rel=0` evita "vídeos relacionados" de otros canales al acabar.
  /// `modestbranding=1` reduce el logo de YouTube.
  static String? embedYoutube(String url) {
    final id = _idYoutube(url);
    if (id == null) return null;
    return 'https://www.youtube.com/embed/$id?rel=0&modestbranding=1&playsinline=1';
  }

  /// Convierte `https://instancia/w/XXXX` o `/videos/watch/XXXX` a la URL
  /// de embed de PeerTube (`/videos/embed/XXXX`). Null si no encaja.
  static String? embedPeerTube(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final partes = uri.pathSegments;
    if (partes.isEmpty) return null;
    // Patrón 1: /w/XXXX (formato corto moderno)
    if (partes.length >= 2 && partes[0] == 'w') {
      return 'https://${uri.host}/videos/embed/${partes[1]}';
    }
    // Patrón 2: /videos/watch/UUID
    if (partes.length >= 3 && partes[0] == 'videos' && partes[1] == 'watch') {
      return 'https://${uri.host}/videos/embed/${partes[2]}';
    }
    return null;
  }

  /// URL apunta a un archivo de vídeo que un video_player puede reproducir
  /// directamente (mp4, webm, m4v).
  static bool esVideoDirecto(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.webm') || lower.endsWith('.m4v');
  }

  static String? _idYoutube(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be') {
      final partes = uri.pathSegments;
      if (partes.isNotEmpty && _esIdYoutube(partes.first)) return partes.first;
    }
    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && _esIdYoutube(v)) return v;
      // Shorts: /shorts/<id>
      final partes = uri.pathSegments;
      if (partes.length >= 2 && partes[0] == 'shorts' && _esIdYoutube(partes[1])) {
        return partes[1];
      }
    }
    return null;
  }

  static bool _esIdYoutube(String s) => RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s);
}
