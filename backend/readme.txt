=== Flavor News Hub ===
Contributors: flavornewshub
Tags: news, aggregator, rss, headless, collectives
Requires at least: 6.4
Tested up to: 6.8
Requires PHP: 8.1
Stable tag: 0.1.0
License: AGPL-3.0-or-later
License URI: https://www.gnu.org/licenses/agpl-3.0.html

Backend headless para agregar medios alternativos vía RSS y listar colectivos organizados. Diseñado para acompañar a una app Flutter o consumirse directamente vía REST.

== Description ==

Flavor News Hub convierte una instalación WordPress estándar en backend de una herramienta de comunicación pensada para cerrar el círculo entre **informarse** (vía medios no corporativos) y **actuar** (vía colectivos organizados).

Sin algoritmo de engagement. Sin tracking. Sin dark patterns. AGPL-3.0.

Manifiesto completo: https://github.com/JosuIru/flavor-news-hub/blob/main/MANIFESTO.md

== Installation ==

1. Sube la carpeta `flavor-news-hub` a `/wp-content/plugins/` (o instala vía el admin).
2. Actívalo desde el menú Plugins.
3. En el menú lateral aparecerán **Medios**, **Noticias** y **Colectivos**. La primera activación precarga las 15 temáticas canónicas.

Para desarrollo desde el monorepo, enlaza con `ln -s` desde `backend/` al directorio de plugins de tu WordPress local.

== Changelog ==

= 0.1.0 =
* Versión inicial. Registro de CPTs `fnh_source`, `fnh_item`, `fnh_collective`; taxonomía compartida `fnh_topic` (jerárquica) con 15 temáticas precargadas; meta fields con sanitización y exposición controlada en REST.
