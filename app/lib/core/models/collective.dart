import 'package:freezed_annotation/freezed_annotation.dart';

import 'topic.dart';

part 'collective.freezed.dart';
part 'collective.g.dart';

/// Colectivo verificado. Lo que devuelve `/collectives` y `/collectives/{id}`.
///
/// El email de contacto nunca se expone vía API; `hasContact` indica si hay
/// uno registrado en el backend para que la UI decida cómo ofrecer contacto
/// (en v1 el camino público es su web o su instancia Flavor).
@freezed
class Collective with _$Collective {
  const factory Collective({
    required int id,
    required String slug,
    required String name,
    @Default('') String description,
    @Default('') String url,
    @Default('') String websiteUrl,
    @Default('') String flavorUrl,
    @Default('') String supportUrl,
    @Default('') String territory,
    @Default('') String country,
    @Default('') String region,
    @Default('') String city,
    @Default(false) bool hasContact,
    @Default(true) bool verified,
    @Default(true) bool esMovimiento,
    @Default(<Topic>[]) List<Topic> topics,
    @Default(<int>[]) List<int> sourceIds,
  }) = _Collective;

  factory Collective.fromJson(Map<String, dynamic> json) => _$CollectiveFromJson(json);
}
