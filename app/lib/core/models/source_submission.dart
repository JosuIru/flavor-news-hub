import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_submission.freezed.dart';
part 'source_submission.g.dart';

/// Cuerpo del POST `/sources/submit`. El usuario propone un medio que un
/// verificador humano activará después (o rechazará) desde el admin.
///
/// `website` es el honeypot: siempre vacío desde la UI; si llegara relleno,
/// el backend descarta con 400. `contactEmail` es auditoría interna, nunca
/// se expone en la API pública.
@freezed
class SourceSubmission with _$SourceSubmission {
  const factory SourceSubmission({
    required String name,
    required String feedUrl,
    required String contactEmail,
    @Default('rss') String feedType,
    @Default('') String description,
    @Default('') String websiteUrl,
    @Default('') String territory,
    @Default(<String>[]) List<String> languages,
    @Default(<String>[]) List<String> topics,
    @Default('') String website, // honeypot: humano = ''
  }) = _SourceSubmission;

  factory SourceSubmission.fromJson(Map<String, dynamic> json) =>
      _$SourceSubmissionFromJson(json);
}

/// Respuesta aceptada (202) del POST `/sources/submit`.
@freezed
class SourceSubmissionResult with _$SourceSubmissionResult {
  const factory SourceSubmissionResult({
    required int id,
    required bool success,
    @Default('') String message,
  }) = _SourceSubmissionResult;

  factory SourceSubmissionResult.fromJson(Map<String, dynamic> json) =>
      _$SourceSubmissionResultFromJson(json);
}
