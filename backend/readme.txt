=== Flavor News Hub ===
Contributors: flavornewshub
Tags: news, aggregator, rss, headless, collectives
Requires at least: 6.4
Tested up to: 6.8
Requires PHP: 8.1
Stable tag: 0.9.16
License: AGPL-3.0-or-later
License URI: https://www.gnu.org/licenses/agpl-3.0.html

Backend headless para agregar medios alternativos vía RSS y listar colectivos organizados. Diseñado para acompañar a una app Flutter o consumirse directamente vía REST.

== Description ==

Flavor News Hub convierte una instalación WordPress estándar en backend de una herramienta de comunicación pensada para cerrar el círculo entre **informarse** (vía medios no corporativos) y **actuar** (vía colectivos organizados).

Sin algoritmo de engagement. Sin tracking. Sin dark patterns. AGPL-3.0.

**Qué hace:**

* Registra 4 custom post types (`fnh_source`, `fnh_item`, `fnh_radio`, `fnh_collective`) y la taxonomía compartida `fnh_topic` con 18 temáticas canónicas precargadas.
* Ingesta periódica de feeds RSS/Atom vía wp-cron (default 30 min). Dedupe por `guid` con fallback a URL del artículo. Purga diaria de items más antiguos que la retención configurada (default 90 días).
* REST pública en `/wp-json/flavor-news/v1/*` con endpoints para listar items, sources, collectives, radios, topics, búsqueda global, trigger de ingesta, configuración y diagnóstico.
* Shortcodes para incrustar en páginas: `[flavor_news_feed]`, `[flavor_news_videos]`, `[flavor_news_radios]`, `[flavor_news_podcasts]`, `[flavor_news_tv]`, `[flavor_news_sources]`, `[flavor_news_collectives]`, `[flavor_news_landing]`.
* Auto-generación de páginas de frontend (Noticias, TV, Vídeos, Radios, Podcasts, Colectivos, Fuentes, Sobre) con shortcodes y nav propia.
* Embed inline de vídeos YouTube, Vimeo y PeerTube en la web (mecanismo oficial de las plataformas, respeta ToS).
* Admin dashboard con **Estado de fuentes**: tabla con items 7d/30d, última ingesta, errores. Acciones en 1 click: desactivar fuentes caídas, aplicar URLs corregidas conocidas.
* Interleave de sources: máx 2 items consecutivos del mismo medio en los listados (evita que un medio que publica en ráfagas domine el feed).
* Auto-update vía plugin-update-checker enlazado al repo GitHub.

Manifiesto completo: https://github.com/JosuIru/flavor-news-hub/blob/main/MANIFESTO.md

== Installation ==

1. Sube la carpeta `flavor-news-hub` a `/wp-content/plugins/` (o instala vía el admin).
2. Actívalo desde el menú Plugins.
3. En el menú lateral aparecerán **Medios**, **Noticias**, **Radios** y **Colectivos**. La primera activación precarga 18 temáticas canónicas y el catálogo bundleado de fuentes/radios/colectivos.
4. Las actualizaciones posteriores sincronizan automáticamente el catálogo y añaden fuentes nuevas sin duplicar las que ya tengas.

El plugin trabaja con metadatos públicos y enlaces canónicos. No está pensado para copiar artículos completos, imágenes, logos o contenido tras login/paywall, ni para usar feeds con términos que lo prohíban.

Antes de dar de alta una fuente o colectivo: comprueba que la URL es pública, que no vas a copiar contenido completo, que el logo o miniatura pueden usarse y que la temática encaja con la taxonomía del proyecto.

Para desarrollo desde el monorepo, enlaza con `ln -s` desde `backend/` al directorio de plugins de tu WordPress local.

== Frequently Asked Questions ==

= ¿Por qué WordPress y no un servicio SaaS? =

Porque te permite autohospedarte sin depender de terceros y reutilizar toda la gobernanza (usuarios, permisos, copias, CDN) que ya conoces.

= ¿Cómo descubro fuentes muertas? =

Menú **Flavor News Hub → Estado de fuentes** muestra items 7d/30d por source, última ingesta y error si lo hubo. Categorías automáticas: con errores, muertas (>30d sin items), inactivas (7d-30d), sanas. Botón para desactivar todas las caídas en un click.

= ¿Qué pasa con los items viejos? =

Purga automática diaria según `item_retention_days` (default 90). Poner 0 desactiva la purga. Los items marcados como guardados por usuarios de la app siguen accesibles desde su caché local aunque se borren del backend.

= ¿Se integra con Flavor Platform? =

Sí, si Flavor Platform está activo, Flavor News Hub aparece como addon en su dashboard unificado. Si no, funciona por su cuenta.

== Changelog ==

= 0.9.x (2026-04) =

Ronda grande de estabilidad, admin y app:

* **Scroll infinito** en noticias, vídeos y podcasts. Endpoint REST dedicado que devuelve HTML pre-renderizado.
* **Interleave de sources**: máximo 2 items consecutivos del mismo medio, aplicado en web y API.
* **Embed inline de vídeos** YouTube (via `youtube-nocookie.com`), Vimeo y PeerTube.
* **Admin "Estado de fuentes"**: tabla por source con items 7d/30d/total, última ingesta y errores. Botones de acción para desactivar caídas y aplicar URLs corregidas.
* **Endpoint `/diagnostics`** público con estado de ingesta, sources activas y logs recientes.
* **Endpoint `/ingest-trigger`** que despierta el cron en sitios con poco tráfico web (la app lo llama al arrancar y en pull-to-refresh).
* **Endpoint `/settings`** público para sincronizar URL de donaciones con clientes.
* **Endpoint `/feed-html`** para scroll infinito en el frontend.
* **Shortcode `[flavor_news_collectives]`** con directorio de colectivos agrupado por territorio.
* **Purga automática diaria de items** antiguos (default 90 días, configurable, 0 desactiva).
* **Invalidación forzada del transient de SimplePie** antes de cada `fetch_feed` — soluciona ingesta estancada 12h en sitios con object cache.
* **Parser mejorado**: deriva título desde excerpt cuando el feed no incluye `<title>` (caso común en Mastodon y microblogs federados).
* **Limpieza de excerpts**: strippa `<img>` inline, scripts, iframes y boilerplate "The post X appeared first on Y" típico de feeds RSS de WordPress.
* **URL de donaciones** editable desde Ajustes.
* **Retención de logs de ingesta** configurable (default 30 días).
* Cache del endpoint de update check reducido a 1h (antes 6h); invalidación automática al cambiar versión del plugin.

= 0.8.x (2026-04) =

* Página Inicio con landing editorial (hero, mosaico, secciones).
* Navegación auto entre páginas y botón/modal flotante de donaciones.
* Mejoras layout web en `/noticias`, `/videos`, `/colectivos` (cards, line-clamp, responsive).
* Filtros de feed (topic, territory, language) en páginas auto.
* Hero de `/noticias` con destacados + chips de temáticas activas.

= 0.7.x =

* Páginas auto-generadas: Noticias, TV, Vídeos, Radios, Podcasts, Colectivos, Fuentes, Sobre.
* Pestaña TV en la app con sub-tabs Medios / Últimas emisiones.
* CPT `fnh_radio` y shortcode `[flavor_news_radios]` con player nativo.
* Integración Flavor Platform + VBP para crear páginas con presets visuales.

= 0.6.x =

* Integración opcional con Flavor Platform como addon.
* Import/export OPML.
* Shortcode `[flavor_news_sources]` con directorio de medios.

= 0.5.x =

* Auto-update vía plugin-update-checker (GitHub Releases).
* REST API en `flavor-news/v1` con transformers propios (snake_case, filtrado de campos sensibles).
* Endpoint `/apps/check-update` para OTA del APK Flutter.

= 0.1.0 =

* Versión inicial. Registro de CPTs `fnh_source`, `fnh_item`, `fnh_collective`; taxonomía `fnh_topic` con 18 temáticas precargadas; meta fields con sanitización y exposición controlada en REST.
