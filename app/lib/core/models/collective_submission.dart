import 'package:freezed_annotation/freezed_annotation.dart';

part 'collective_submission.freezed.dart';
part 'collective_submission.g.dart';

/// Cuerpo del POST `/collectives/submit`. El campo `website` se envía
/// siempre vacío: es el honeypot que el backend revisa para descartar bots.
@freezed
class CollectiveSubmission with _$CollectiveSubmission {
  const factory CollectiveSubmission({
    required String name,
    required String description,
    required String contactEmail,
    @Default('') String websiteUrl,
    @Default('') String territory,
    @Default('') String flavorUrl,
    @Default(<String>[]) List<String> topics,
    @Default('') String website, // honeypot: humano = ''
  }) = _CollectiveSubmission;

  factory CollectiveSubmission.fromJson(Map<String, dynamic> json) =>
      _$CollectiveSubmissionFromJson(json);
}

/// Respuesta del POST `/collectives/submit` cuando el backend la acepta
/// (202). En error (400 / 429 / 500) el cliente lanza una excepción en vez
/// de devolver este objeto.
@freezed
class CollectiveSubmissionResult with _$CollectiveSubmissionResult {
  const factory CollectiveSubmissionResult({
    required int id,
    required bool success,
    @Default('') String message,
  }) = _CollectiveSubmissionResult;

  factory CollectiveSubmissionResult.fromJson(Map<String, dynamic> json) =>
      _$CollectiveSubmissionResultFromJson(json);
}
