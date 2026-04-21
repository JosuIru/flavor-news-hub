import 'package:freezed_annotation/freezed_annotation.dart';

import 'source_summary.dart';
import 'topic.dart';

part 'item.freezed.dart';
part 'item.g.dart';

/// Noticia agregada desde el feed de un medio. Lo que devuelve `/items`
/// y `/items/{id}`.
///
/// `excerpt` es HTML ya filtrado por el backend (wp_kses_post + the_content).
/// `originalUrl` es el enlace al artículo en la web del medio: pulsar
/// "Leer en [medio]" lleva ahí, respetando tráfico e ingresos del medio.
@freezed
class Item with _$Item {
  const factory Item({
    required int id,
    required String slug,
    required String title,
    @Default('') String excerpt,
    @Default('') String url,
    @Default('') String originalUrl,
    @Default('') String publishedAt,
    @Default('') String mediaUrl,
    @Default('') String audioUrl,
    @Default(0) int durationSeconds,
    SourceSummary? source,
    @Default(<Topic>[]) List<Topic> topics,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}
