import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic.freezed.dart';
part 'topic.g.dart';

/// Temática del directorio. Compartida entre medios, noticias y colectivos.
/// Jerárquica: `parent = 0` indica que está al primer nivel.
@freezed
class Topic with _$Topic {
  const factory Topic({
    required int id,
    required String name,
    required String slug,
    @Default(0) int parent,
    @Default(0) int count,
  }) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}
