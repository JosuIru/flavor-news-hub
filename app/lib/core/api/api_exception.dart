/// Excepción lanzada por el cliente REST del backend.
///
/// Normaliza los tres modos de fallo:
/// - HTTP error con body JSON `{error, message}` (validación, not found,
///   rate limit, …): `errorCode` coincide con el campo `error` del body.
/// - HTTP error sin body parseable: `errorCode = 'http_error'`.
/// - Error de red (timeout, DNS, TLS…): `errorCode = 'network_error'`
///   con `statusCode = 0`.
class FlavorNewsApiException implements Exception {
  const FlavorNewsApiException({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  final int statusCode;
  final String errorCode;
  final String message;

  /// Útil para diferenciar UX: si `isRateLimited`, mostrar mensaje específico
  /// al usuario en vez del genérico.
  bool get estaRateLimited => statusCode == 429 || errorCode == 'rate_limited';

  bool get esNoEncontrado => statusCode == 404 || errorCode == 'not_found';

  bool get esProblemaRed => statusCode == 0 || errorCode == 'network_error';

  @override
  String toString() => 'FlavorNewsApiException($statusCode, $errorCode): $message';
}
