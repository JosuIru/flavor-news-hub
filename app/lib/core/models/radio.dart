import 'package:freezed_annotation/freezed_annotation.dart';

import 'topic.dart';

part 'radio.freezed.dart';
part 'radio.g.dart';

/// Radio libre con stream en directo. Lo que devuelve `/radios` de la API.
/// `streamUrl` apunta a un Icecast/HLS/m3u8 que el cliente reproduce
/// directamente; el backend no proxyea audio en ningún caso.
@freezed
class Radio with _$Radio {
  const factory Radio({
    required int id,
    required String slug,
    required String name,
    @Default('') String description,
    @Default('') String url,
    @Default('') String streamUrl,
    @Default('') String websiteUrl,
    @Default('') String rssUrl,
    @Default('') String territory,
    @Default(<String>[]) List<String> languages,
    @Default('') String ownership,
    @Default(true) bool active,
    @Default(<Topic>[]) List<Topic> topics,
  }) = _Radio;

  factory Radio.fromJson(Map<String, dynamic> json) => _$RadioFromJson(json);
}
