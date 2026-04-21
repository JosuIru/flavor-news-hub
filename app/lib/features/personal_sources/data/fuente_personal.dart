import 'package:flutter/foundation.dart';

/// Fuente RSS/Atom/YouTube/Podcast añadida por el usuario final, que vive
/// sólo en su dispositivo (SharedPreferences). No se sube a ningún servidor.
///
/// La `feedUrl` se usa como identificador único — es imposible tener dos
/// suscripciones significativas al mismo feed.
@immutable
class FuentePersonal {
  const FuentePersonal({
    required this.nombre,
    required this.feedUrl,
    required this.tipoFeed,
    required this.anadidaEn,
  });

  final String nombre;
  final String feedUrl;

  /// Tipo declarado por el usuario (rss, atom, youtube, podcast). Es puramente
  /// informativo para la UI; el parser detecta automáticamente si el XML
  /// es RSS o Atom.
  final String tipoFeed;

  final DateTime anadidaEn;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'feedUrl': feedUrl,
        'tipoFeed': tipoFeed,
        'anadidaEn': anadidaEn.toIso8601String(),
      };

  factory FuentePersonal.fromJson(Map<String, dynamic> json) => FuentePersonal(
        nombre: (json['nombre'] as String?) ?? '',
        feedUrl: (json['feedUrl'] as String?) ?? '',
        tipoFeed: (json['tipoFeed'] as String?) ?? 'rss',
        anadidaEn:
            DateTime.tryParse((json['anadidaEn'] as String?) ?? '') ?? DateTime.now().toUtc(),
      );

  @override
  bool operator ==(Object other) => other is FuentePersonal && other.feedUrl == feedUrl;

  @override
  int get hashCode => feedUrl.hashCode;
}
