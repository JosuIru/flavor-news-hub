# Flavor News Hub

Una herramienta sencilla para romper el circuito entre **informarse** y **actuar**.

## Por qué existe

Hoy la gente se informa a través de plataformas diseñadas para capturar su atención, no para que entienda su realidad ni para que pueda intervenir en ella. El patrón es conocido: te enteras de un problema, sientes impotencia, scrolleas al siguiente, nada cambia.

Mientras tanto, medios alternativos y colectivos organizados hacen un trabajo enorme sobre esos mismos problemas — pero son invisibles para quien no los busca activamente.

**Flavor News Hub** hace una sola cosa bien: después de enterarte de algo, te ofrece un camino concreto hacia quien ya está organizándose sobre ello.

No es una red social. No es una plataforma de organización interna. No es un sustituto de los medios ni de los colectivos. Es una **puerta de entrada común** entre informarse y actuar.

## Qué hay en la app hoy

La app Flutter cubre seis áreas principales, todas navegables desde una sola barra inferior y sin cuentas de usuario.

### Feed de noticias

- Feed cronológico de medios alternativos con **scroll infinito**, **pull-to-refresh** (dispara también la ingesta del backend) y **interleave** de fuentes para que un medio que publica en ráfaga no domine la primera pantalla.
- Filtros por **temática**, **territorio** e **idioma** persistidos entre sesiones. El filtro de idioma arranca con la UI del usuario.
- **Guardados**, **marcar como útil** y **leídos** con caché local en SQLite — los guardados siguen accesibles aunque el ítem se borre del backend.
- **Ficha editorial** de cada medio: propiedad, financiación, línea declarada, licencia de contenido, licencia de stream en directo, territorio, idiomas.
- **"¿Quién se organiza sobre esto?"** — desde el detalle de un titular, enlace al directorio de colectivos relacionado con las temáticas del artículo.

### Audio y vídeo

- **Radios libres** con player en primer plano (notificación persistente, seguir sonando con pantalla bloqueada, botones bluetooth, Android Auto) y **favoritos por radio**.
- **Podcasts** con reproductor propio y gestión de favoritos.
- **Vídeos** en grid con miniatura + fuente + fecha + excerpt, **reproducción in-app** cuando el canal lo permite (YouTube, PeerTube, Vimeo), fallback a navegador externo. **Bookmark por vídeo** (va a Guardados) y **corazón por canal** ("Sólo mis canales").
- **TV** con dos subtabs (Medios / Últimas emisiones) y modo **"TV 24h"** — tap en un canal arranca playback continuo de sus últimas emisiones.
- **Música federada** — búsqueda en Funkwhale, Jamendo, Audius y Archive.org con cola, reproductor, gestor de instancias y géneros.

### Colectivos

- Directorio navegable con **ficha pública**: descripción, territorio, web, temáticas.
- **Alta pública** de colectivo vía formulario que requiere verificación manual en admin antes de aparecer.
- **Mapa** para localizar colectivos y radios por territorio.

### Buscador global

- Busca en paralelo en noticias, medios, radios y colectivos desde una sola caja.
- Debounced a 300ms, sin cuenta ni histórico del servidor.

### Ajustes

- **Tema** (claro / oscuro / sistema), **idioma de UI**, **escala de texto**, **URL de la instancia backend** (para auto-hospedar).
- **Notificaciones locales**: worker periódico (15min–24h) que avisa de titulares, vídeos y podcasts nuevos. Sin servidores push, todo on-device.
- **Mis medios**: fuentes personales RSS/podcast/YouTube guardadas sólo en el dispositivo, con **import/export OPML**.
- **Silenciar fuentes** del directorio sin quitarlas para todos.
- **Tus intereses**: resumen de temáticas y medios que más marcas útiles — en dispositivo, sin analítica.
- **Historial** y **guardados** con búsqueda y filtrado.
- **Comprobar actualizaciones** con botón manual que salta el cache.

### Superficies fuera de la app principal

- **5 widgets Android**: últimos titulares, reproductor de radio, reproductor de música, radios favoritas, **barra de búsqueda** (estilo Google QSB — icono + placeholder + lupa, abre el buscador global).
- **Deep links** `flavornews://items/{id}`, `flavornews://radios/play/{id}`, `flavornews://search`.
- **Share intake**: recibe URLs compartidas desde otras apps y abre el formulario de proponer medio pre-rellenado.
- **OTA in-app**: descarga e instala el APK nuevo desde un diálogo, con progreso; fallback a descarga externa si falla.
- **Modo offline**: seed local de medios + caché SQLite de items recientes para lectura básica sin red.

**Lo que no hay**: cuentas de usuario, algoritmo de recomendación, IA, analítica, publicidad, notificaciones de engagement.

## Qué hay en la web (plugin WordPress)

Las páginas `/inicio`, `/noticias`, `/tv`, `/videos`, `/radios`, `/podcasts`, `/colectivos`, `/fuentes` y `/sobre` se auto-generan al instalar el plugin, con su propio menú entre ellas.

- **Scroll infinito** (excepto `/inicio`, que es portada editorial) servido por un endpoint REST dedicado que devuelve HTML pre-renderizado.
- **Reproducción inline de vídeos** YouTube (via `youtube-nocookie.com`), Vimeo y PeerTube — mismo mecanismo oficial que usan las plataformas para embebido.
- **Filtros** por temática / territorio / idioma con URL compartible.
- **Portada editorial** `/inicio` con hero, noticias destacadas, últimos vídeos, podcasts recientes, CTA de descarga de app y sección de apoyo.
- **Modal de donaciones unificado** con Ko-fi, PayPal (editable desde admin), Bitcoin SegWit/Taproot con copiar al portapapeles, compartir y "otras formas de ayudar". Mismo contenido que el sheet de la app.
- **Shortcodes**: `[flavor_news_feed]`, `[flavor_news_videos]`, `[flavor_news_radios]`, `[flavor_news_podcasts]`, `[flavor_news_tv]`, `[flavor_news_sources]`, `[flavor_news_collectives]`, `[flavor_news_landing]`.

## Qué hay en el admin WordPress

- **Estado de fuentes**: tabla por source con items 7d/30d/total, última ingesta, errores. Clasifica automáticamente en sanas / inactivas / muertas / con errores. Botones para desactivar las caídas en 1 click y aplicar URLs corregidas conocidas.
- **Log de ingesta**: última ejecución de cada source con cuántos items creó, cuántos descartó y el error si hubo.
- **Catálogo**: botones para re-importar el seed bundleado.
- **Ajustes**: intervalo de cron, retención de logs, retención de noticias (purga diaria automática), URL de donaciones, borrar al desinstalar.
- **Ingest now** por fuente desde su pantalla de edición.
- **Bulk verify** para colectivos pendientes de verificación (altas públicas).

## API REST pública

Namespace `flavor-news/v1`:

- `GET /items`, `GET /items/{id}` — feed agregado con filtros por topic/territory/language/source_type + paginación.
- `GET /sources`, `GET /sources/{id}` — directorio de medios con ficha editorial.
- `GET /collectives`, `GET /collectives/{id}` — directorio de colectivos.
- `GET /radios` — radios activas.
- `GET /topics` — taxonomía canónica.
- `GET /search` — búsqueda global.
- `POST /collectives/submit`, `POST /sources/submit` — altas públicas (quedan en pending hasta verificar).
- `GET /apps/check-update` — comprobación de actualizaciones del APK.
- `POST /ingest-trigger` — despierta la ingesta del backend (la app lo llama al arrancar y en pull-to-refresh).
- `GET /settings` — ajustes públicos (URL de donaciones) para sincronizar entre web y app.
- `GET /feed-html` — chunks HTML pre-renderizados para scroll infinito.
- `GET /diagnostics` — estado de ingesta, sources activas, logs recientes, totales e items nuevos 24h.

## Relación con Flavor Platform

Este proyecto es **complementario** pero **independiente** de [Flavor Platform](https://github.com/JosuIru/wp-flavor-platform):

- **Flavor Platform** sirve a colectivos ya organizados que necesitan herramientas para su funcionamiento interno (asambleas, economía, web, comunicación).
- **Flavor News Hub** sirve al **paso anterior**: que la gente se entere de qué pasa vía medios no corporativos y descubra qué colectivos existen sobre lo que le preocupa.

Cuando un colectivo listado aquí tiene instancia Flavor, enlazamos a ella. Si Flavor Platform está activo en el mismo WordPress, Flavor News Hub aparece como addon en su dashboard unificado.

## Ciclo de actualización

| Cambio | WordPress backend | App online | App offline |
|--------|-------------------|------------|-------------|
| Fuentes, radios y colectivos bundleados | Se sincronizan al actualizar el plugin por slug | Se ven en cuanto el backend se actualiza | Requiere nueva build de la app |
| Temáticas canónicas | Se repueblan si falta alguna al actualizar el plugin | Se reflejan en la API pública | Requiere nueva build de la app |
| Altas manuales via WP-CLI o admin | Inmediatas | Se reflejan al instante | No cambian hasta nueva build |
| Topics de sources existentes | Se rellenan al actualizar si estaban vacíos (no se pisan los editados manualmente) | Filtros por temática funcionan mejor | Requiere nueva build |
| URL de donaciones | Admin → Ajustes | App sincroniza al arrancar | Fallback hardcoded |

Regla práctica: `backend/seed/*.json` es la referencia editorial; `app/assets/seed/*.json` es el fallback offline. Si cambias uno, revisa el otro.

## Arquitectura

### `backend/` — Plugin WordPress headless

Plugin `flavor-news-hub` que convierte una instalación WP normal en backend del sistema.

- CPTs `fnh_source`, `fnh_item`, `fnh_collective`, `fnh_radio` + taxonomía compartida `fnh_topic` con 19 temáticas precargadas.
- Ingesta automática cada 30 minutos vía `wp_cron` (SimplePie con cache reducido a 10min y transient invalidado por feed). Dedupe por `guid` con fallback a URL del artículo. Interleave de sources aplicado en la API y en los shortcodes.
- Sincronización automática del catálogo bundleado al actualizar el plugin: fuentes, radios, colectivos, topics nuevos se añaden por slug.
- Purga diaria automática de items según `item_retention_days` (default 90, 0 desactiva).
- API REST pública (namespace `flavor-news/v1`).
- Admin completo con dashboard, estado de fuentes, log de ingesta, catálogo, ajustes y acciones por fuente.
- Plantillas web públicas mínimas `/n/{slug}`, `/c/{slug}`, `/f/{slug}` + páginas auto-generadas + shortcodes reutilizables.
- WP-CLI: `wp flavor-news ingest [--source=<id>]`, `wp flavor-news import sources|radios|collectives`.
- Auto-update vía [plugin-update-checker](https://github.com/YahnisElsts/plugin-update-checker) enlazado a GitHub Releases.

Requisitos: WordPress 6.4+, PHP 8.1+, PSR-4, composer. Licencia AGPL-3.0.

### `app/` — Aplicación Flutter

App Flutter multiplataforma, Android prioritario (distribución fuera de Play Store vía APK directo).

- **Estado**: Riverpod.
- **Navegación**: go_router con deep links `flavornews://`.
- **Persistencia**: SharedPreferences + SQLite (items leídos/guardados/útiles, cache offline).
- **Audio**: `just_audio` + `just_audio_background` para servicio foreground.
- **Notificaciones locales**: `flutter_local_notifications` + `workmanager` para polling periódico.
- **Widgets Android**: `home_widget` + providers Kotlin nativos.
- **OTA**: download + FileProvider + `open_filex` para instalar APK in-app.
- **i18n**: ARB en es, ca, eu, gl, en como idiomas de primera clase.

Cero Firebase, cero analítica, cero telemetría, cero IA. Licencia AGPL-3.0.

## Estructura del repositorio

```
flavor-news-hub/
├── README.md              visión, arquitectura, cómo contribuir
├── MANIFESTO.md           los principios irrenunciables
├── LICENSE                AGPL-3.0
├── backend/               plugin WordPress
│   ├── src/               código PHP (PSR-4)
│   ├── seed/              catálogo bundleado (sources, radios, collectives)
│   ├── templates/         plantillas web mínimas de fallback
│   └── languages/         traducciones .po/.mo
├── app/                   aplicación Flutter
│   ├── lib/               Dart
│   ├── android/           Kotlin widgets + AndroidManifest
│   └── assets/seed/       seed offline copiado del backend
└── .github/workflows/     CI para tests del backend y build de la app
```

## CI

Dos workflows en `.github/workflows/`:

- **`backend-tests.yml`** — levanta MySQL 8, instala PHP (matriz 8.1 / 8.2), corre lint y `phpunit`. Se dispara al tocar `backend/**`.
- **`app-build.yml`** — instala Java 17 + Flutter stable con caché, regenera freezed/json_serializable, corre `flutter analyze`, `flutter test` y compila APK debug como artifact. Se dispara al tocar `app/**`.

Los archivos `.freezed.dart` / `.g.dart` **no** se commitean: se regeneran en CI y en local con `dart run build_runner build --delete-conflicting-outputs`.

## Cómo autohospedar

Uno de los principios es la **apropiabilidad**: cualquier colectivo debe poder levantar su propia instancia sin pedir permiso.

- **Backend**: instalar el plugin en una WP estándar (symlink desde este monorepo, zip manual desde GitHub Releases, o Composer cuando esté publicado).
- **App**: la pantalla de ajustes permite cambiar la URL de la instancia backend. Por defecto apunta a la instancia oficial.
- **Offline**: la app mantiene seeds locales para fallback sin red. Si cambias el catálogo del backend, revisa también el seed offline de la app.
- **Mantenimiento del catálogo**: pantalla admin "Estado de fuentes" te dirá qué feeds están caídos o sin actividad reciente, con botón para desactivar las muertas en 1 click.

## Cómo contribuir

Antes de mandar código o abrir un issue, **lee el [MANIFESTO](MANIFESTO.md)**. Si tu propuesta entra en conflicto con alguno de los principios irrenunciables, probablemente no encaje en este proyecto (pero puede encajar en un fork).

- Bugs reales y mejoras que respeten el manifiesto: issues y PRs bienvenidos.
- Features nuevas: abre primero una discusión. La vara es alta: sólo entran si son claramente necesarias, no si "podrían estar bien".
- Traducciones: muy bienvenidas. Castellano, catalán, euskera, gallego e inglés son idiomas de primera clase desde el día 1.

Idioma de desarrollo interno: castellano (comentarios de código, mensajes de commit, issues). La interfaz y la documentación pública son multilingües.

## Licencia

[AGPL-3.0](LICENSE). Si despliegas una instancia modificada accesible por red, debes publicar tus modificaciones bajo la misma licencia.
