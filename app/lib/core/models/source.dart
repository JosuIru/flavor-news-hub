import 'package:freezed_annotation/freezed_annotation.dart';

import 'topic.dart';

part 'source.freezed.dart';
part 'source.g.dart';

/// Ficha editorial completa de un medio: lo que devuelve `/sources` y
/// `/sources/{id}` de la API pública.
///
/// `description`, `ownership` y `editorialNote` vienen en HTML ya filtrado
/// por el backend (wp_kses_post). El renderer del cliente debe tratarlos
/// como HTML, no como texto plano.
///
/// Campos añadidos con Vol. 3 (TV, PeerTube, licencias):
///  - `mediumType`: news/video/radio/tv_station (ortogonal a `feedType`).
///  - `broadcastFormat`: lista de canales de emisión (web, tdt_legal,
///    tdt_sin_licencia, cable, etc.). Usado en filtros y badges.
///  - `contentLicense`: slug de la licencia (ej. `cc-by-nc-nd-3.0`).
///    Vacío = no declarada.
///  - `legalNote`: contexto legal/educativo breve en HTML.
///  - `hasLiveStream` + `liveStreamPermit`: habilitan la pantalla "En
///    directo". Sólo `cc-license` permite embed por política del proyecto.
@freezed
class Source with _$Source {
  const factory Source({
    required int id,
    required String slug,
    required String name,
    @Default('') String description,
    @Default('') String url,
    @Default('') String feedUrl,
    @Default('rss') String feedType,
    @Default('') String websiteUrl,
    @Default(<String>[]) List<String> languages,
    @Default('') String territory,
    @Default('') String ownership,
    @Default('') String editorialNote,
    @Default(true) bool active,
    @Default(<Topic>[]) List<Topic> topics,
    @Default('news') String mediumType,
    @Default(<String>[]) List<String> broadcastFormat,
    @Default('') String contentLicense,
    @Default('') String legalNote,
    @Default(false) bool hasLiveStream,
    @Default('none') String liveStreamPermit,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
