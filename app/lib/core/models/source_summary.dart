import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_summary.freezed.dart';
part 'source_summary.g.dart';

/// Versión resumida de un medio, la que viene embebida en cada item del feed.
/// La variante completa (con propiedad, línea editorial, idiomas, etc.) está
/// en `source.dart`.
@freezed
class SourceSummary with _$SourceSummary {
  const factory SourceSummary({
    required int id,
    required String slug,
    required String name,
    @Default('') String websiteUrl,
    @Default('') String url,
    @Default('rss') String feedType,
    @Default('') String territory,
    @Default('') String country,
    @Default('') String region,
    @Default('') String city,
    @Default('') String network,
  }) = _SourceSummary;

  factory SourceSummary.fromJson(Map<String, dynamic> json) => _$SourceSummaryFromJson(json);
}
