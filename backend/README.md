# flavor-news-hub · backend

Plugin de WordPress que actúa como backend headless para [Flavor News Hub](../README.md). Expone CPTs, taxonomía, ingesta de feeds, directorio de radios, API REST pública, shortcodes y admin de verificación.

Este documento es la guía técnica del plugin; la visión del proyecto está en [`../README.md`](../README.md) y los principios irrenunciables en [`../MANIFESTO.md`](../MANIFESTO.md).

## Estado por capas

- [x] **Capa 1** — CPTs y taxonomía
- [x] **Capa 2** — Ingesta de feeds (wp_cron + WP-CLI)
- [x] **Capa 3** — API REST `flavor-news/v1`
- [x] **Capa 4** — Admin WordPress
- [x] **Capa 5** — Plantillas web públicas `/n/`, `/c/`, `/f/`
- [x] **Capa 6** — Tests PHPUnit

## Plantillas web públicas

Fallback web para enlaces compartidos desde la app. **No** dependen del tema activo: imprimen HTML completo con CSS inline (una sola hoja compartida), sin `wp_head()`/`wp_footer()` para evitar enqueues de terceros. Resultado: páginas de ~10-15 KB que cargan igual en cualquier instancia.

| Ruta           | CPT              | Contenido                                                                                                      |
|----------------|------------------|----------------------------------------------------------------------------------------------------------------|
| `/n/{slug}`    | `fnh_item`       | Titular, medio, fecha, chips de temáticas, extracto, "Leer en [medio] →", bloque "¿Quién se organiza sobre esto?". |
| `/f/{slug}`    | `fnh_source`     | Nombre, descripción, ficha editorial (web, propiedad, línea editorial, territorio, idiomas), enlace al listado. |
| `/c/{slug}`    | `fnh_collective` | Nombre, territorio, temáticas, descripción, botones "Visitar web" y "Comunidad en Flavor" (si aplica).         |

Colectivos no verificados responden **404** aunque tengan slug activo: la comprobación se hace en `template_redirect` (antes de enviar cabeceras) para que el status real sea `404`, no un `200` con cuerpo de 404.

El plugin también genera páginas auto para `inicio`, `noticias`, `tv`, `videos`, `radios`, `podcasts`, `colectivos`, `fuentes` y `sobre`, con navegación propia y botón de apoyo al proyecto.

## Shortcodes

Los shortcodes permiten reutilizar el contenido del backend en páginas y posts de WordPress sin depender de bloques complejos:

- `[flavor_news_feed]`
- `[flavor_news_radios]`
- `[flavor_news_videos]`
- `[flavor_news_podcasts]`
- `[flavor_news_tv]`
- `[flavor_news_sources]`
- `[flavor_news_collectives]`
- `[flavor_news_source]`
- `[flavor_news_landing]`
- `[flavor_news_sobre]`

Los shortcodes de listado respetan filtros de tema, territorio e idioma cuando la página auto los expone. El render HTML de la primera página y del scroll infinito reutiliza la misma lógica para no duplicar marcado.

Accesibilidad:

- HTML semántico (`<header>`, `<main>`, `<nav>`, `<article>`, `<section>`, `<time>`, `<dl>`).
- Skip link al contenido.
- Contraste AA tanto en claro como en oscuro (respeta `prefers-color-scheme`).
- Sin JS.
- `lang` del sitio, `<meta viewport>` y Open Graph para compartir.

## Tests

Suite mínima con PHPUnit + `WP_UnitTestCase`:

```
tests/
├── bootstrap.php                         carga test-lib de WP + activador del plugin
├── FeedIngesterTest.php                  ingesta + dedupe idempotente
├── RestItemsEndpointTest.php             GET /items (listado, orden, filtros, 404)
├── CollectiveSubmitEndpointTest.php      POST /submit (válido, honeypot, rate limit)
└── fixtures/sample-feed.xml              3 items de prueba
```

Cobertura esencial, correlativa a lo que pide el brief: dedupe de ingesta, un endpoint REST de lectura y un POST de alta con rate-limit.

### Cómo ejecutarlos localmente

Requisitos: PHP 8.1+, Composer, MySQL y `svn` (la test-lib oficial de WP se sirve por svn).

```bash
cd backend
composer install
bin/install-wp-tests.sh fnh_tests <db_user> <db_pass> <db_host> latest
vendor/bin/phpunit
```

Para entornos Local by Flywheel, el `<db_host>` suele ser un socket:

```bash
bin/install-wp-tests.sh fnh_tests root root \
  "localhost:$HOME/.config/Local/run/<id>/mysql/mysqld.sock" latest
```

### CI

El workflow de GitHub Actions (tarea #14, pendiente) instala `svn` + MySQL y corre `phpunit` a cada push/PR.

## Ingesta

La ingesta corre automáticamente por `wp_cron` cada 30 minutos bajo el hook `fnh_ingest_all`. Recordatorio: `wp_cron` en WP **no** es un cron del sistema; dispara oportunistamente en la primera request tras vencer el intervalo.

Para disparos inmediatos hay CLI:

```bash
wp flavor-news ingest               # todas las fuentes activas
wp flavor-news ingest --source=42   # una fuente concreta
```

Una fuente se considera activa si `_fnh_active = 1` o si no tiene el meta escrito (coherente con el default `true`).

Dedupe: primero por `_fnh_guid`, fallback por `_fnh_original_url`. Idempotente: reingestar el mismo feed no crea duplicados.

Cada ejecución escribe una fila en `{prefix}fnh_ingest_log` con contadores (`items_new`, `items_skipped`), fechas y, si hubo error, el mensaje.

## API REST pública

Namespace: `flavor-news/v1`. Sin autenticación en lectura. Respuestas JSON en snake_case. Emails de contacto y de remitente **nunca** se exponen.

### Endpoints de lectura

| Método | Ruta                       | Descripción                                                                  |
|--------|----------------------------|------------------------------------------------------------------------------|
| GET    | `/items`                   | Noticias paginadas, orden `published_at DESC`.                               |
| GET    | `/items/{id}`              | Detalle de una noticia con la fuente embebida.                               |
| GET    | `/sources`                 | Medios activos con ficha editorial completa.                                 |
| GET    | `/sources/{id}`            | Ficha editorial de un medio.                                                 |
| GET    | `/collectives`             | Colectivos publicados y verificados.                                         |
| GET    | `/collectives/{id}`        | Ficha pública de un colectivo verificado.                                    |
| GET    | `/radios`                  | Radios libres curadas por la instancia, filtrables por temática, territorio e idioma. |
| GET    | `/radios/{id}`             | Ficha pública de una radio.                                                  |
| GET    | `/topics`                  | Árbol plano de temáticas (cada una con `parent` y `count`).                  |
| GET    | `/settings`                | Ajustes públicos que los clientes sincronizan sin login.                     |
| GET    | `/apps/check-update`       | Comprobación pública de versiones nuevas de la app Android.                  |
| GET    | `/feed-html`               | HTML pre-renderizado para scroll infinito de feeds, podcasts y vídeos.       |
| GET    | `/ingest-trigger`          | Estado público del último disparo de ingesta.                                |

#### Filtros de `/items`

- `page` (default 1), `per_page` (default 20, máx 50)
- `topic` — slug o lista coma-separada de slugs
- `source` — ID numérico
- `territory` — texto (LIKE sobre el territorio del source)
- `language` — código ISO (contenido en `languages` del source)
- `since` — fecha ISO 8601 mínima

Cabeceras de paginado estándar WP: `X-WP-Total`, `X-WP-TotalPages`.

### Alta pública de colectivos

| Método | Ruta                       | Descripción                                                                  |
|--------|----------------------------|------------------------------------------------------------------------------|
| POST   | `/collectives/submit`      | Alta pública en `pending`. Requiere verificación manual desde el admin.      |

### Alta pública de medios

| Método | Ruta                       | Descripción                                                                  |
|--------|----------------------------|------------------------------------------------------------------------------|
| POST   | `/sources/submit`          | Alta pública de medios en `pending`, con honeypot y rate limit.              |

### Utilidades públicas

| Método | Ruta                       | Descripción                                                                  |
|--------|----------------------------|------------------------------------------------------------------------------|
| POST   | `/ingest-trigger`          | Dispara una ingesta inmediata si el cooldown lo permite.                     |
| GET    | `/ingest-trigger`          | Consulta cuándo fue la última ingesta disparada manualmente.                 |

Cuerpo JSON:

```json
{
  "name": "Sindicato de Inquilinas Bilbao",
  "description": "…",
  "contact_email": "contacto@ejemplo.org",
  "website_url": "https://…",
  "territory": "Bizkaia",
  "flavor_url": "https://…",
  "topics": ["vivienda", "cuidados"],
  "website": ""
}
```

Protecciones:

- **Honeypot** `website`: debe venir vacío. Relleno → `400 invalid_submission`.
- **Rate limit** por IP: 3 altas por hora en zona `collective_submit`. Superado → `429 rate_limited`.
- **Validación** de campos obligatorios (`name`, `description`, `contact_email` válido).
- El alta entra en `post_status=pending` con `_fnh_verified=false`. Nunca aparece en `GET /collectives` hasta que un verificador humano la publique y marque como verified.

### CORS

GET: abierto (Access-Control-Allow-Origin: `*`). Apto para web, app y clientes arbitrarios.

POST: se aplica el CORS por defecto de WordPress (refleja `Origin`) **pero** la defensa real está en rate limit + honeypot + verificación manual, no en el CORS. Un atacante server-side puede bypassar CORS trivialmente; por eso el contrato de seguridad se asienta en validación humana, no en un perímetro de navegador.

## Admin

Menú superior **Flavor News Hub** con submenús: *Resumen*, *Medios*, *Noticias*, *Colectivos*, *Temáticas*, *Log de ingesta* y *Ajustes*.

### Pantallas propias

- **Resumen** (`?page=flavor-news-hub`): contadores de medios, noticias, colectivos publicados y pendientes; últimas 10 ingestas.
- **Log de ingesta** (`?page=fnh-ingest-log`): tabla paginada con filtros por estado (`success` / `error` / `running`), 50 filas por página.
- **Ajustes** (`?page=fnh-settings`):
  - Intervalo de ingesta (minutos, mínimo 5). Al cambiar, se reagenda el cron automáticamente.
  - Retención de logs (días, mínimo 1). El job diario `fnh_cleanup_logs` borra filas más antiguas.
  - Flag "Borrar todos los datos al desinstalar" — hasta no estar marcado, `uninstall.php` no borra nada.

### Metaboxes

- **Medios**: feed URL, tipo de feed (rss/atom/youtube/mastodon/podcast), web, idiomas (coma-separados), territorio, propiedad/financiación (HTML permitido), línea editorial, activo. Botón **"Ingest now"** que dispara la ingesta de esa fuente sin esperar al cron.
- **Noticias**: read-only. Enlace al medio origen, URL original, fecha ISO, GUID, imagen del feed.
- **Colectivos**: web, email de contacto (interno), territorio, URL Flavor, verified. Si viene de un alta pública, se muestra el email del remitente como registro de auditoría.

### Bulk action "Verify and publish"

En la lista de colectivos: selecciona varios `pending`, aplica la acción y pasan a `publish` con `_fnh_verified=1` en un paso.

### Defaults automáticos de source

Al crear un `fnh_source` sin pasar por el metabox (ej. via WP-CLI), un `save_post` hook escribe `_fnh_active=true` y `_fnh_feed_type=rss` si no existen — de modo que la fuente entra al círculo de ingesta sin pasos manuales extra.

### Desinstalación

`uninstall.php` sólo borra CPTs, términos, tabla `fnh_ingest_log`, opción `fnh_settings` y transients del rate limiter **si el usuario ha activado previamente** el flag "Borrar todos los datos al desinstalar" en Ajustes. Por defecto: no borra nada.

## Requisitos

- WordPress 6.4+
- PHP 8.1+
- Composer (sólo para desarrollo; el plugin es autosuficiente en producción gracias a un autoloader PSR-4 propio)

## Instalación

### Desarrollo (symlink desde el monorepo)

Desde la raíz del monorepo, enlaza `backend/` a tu WordPress local:

```bash
ln -s "$(pwd)/backend" /ruta/a/wp-content/plugins/flavor-news-hub
```

Después activa el plugin desde el admin. La activación precarga las 18 temáticas canónicas (vivienda, sanidad, laboral, feminismos, ecologismo, antirracismo, educación, memoria histórica, rural, cultura, alimentación, soberanía alimentaria, derechos civiles, internacional, tecnología soberana, economía social, migraciones, cuidados).

En actualizaciones posteriores, el plugin sincroniza automáticamente el catálogo bundleado: añade fuentes, radios y colectivos nuevos por slug, y repone temáticas canónicas si falta alguna.

Para forzar una importación manual del catálogo bundleado, usa WP-CLI:

```bash
wp flavor-news import sources
wp flavor-news import radios
wp flavor-news import collectives
```

### Producción

Copia el contenido de `backend/` a `wp-content/plugins/flavor-news-hub/` y actívalo desde el admin. No hace falta `composer install` — el plugin trae su propio autoloader.

## Arquitectura

```
backend/
├── flavor-news-hub.php          Plugin header, constantes y autoloader PSR-4
├── composer.json                Dependencias de desarrollo (PHPUnit, WPCS)
├── uninstall.php                Placeholder (la limpieza destructiva vive en capa 4)
├── readme.txt                   Formato WP.org
├── languages/                   .pot y traducciones
├── src/
│   ├── Plugin.php               Orquestador (singleton)
│   ├── CPT/
│   │   ├── Source.php           Medio agregado (fnh_source)
│   │   ├── Item.php             Noticia (fnh_item)
│   │   ├── Collective.php       Colectivo (fnh_collective)
│   │   └── Radio.php            Radio libre (fnh_radio)
│   ├── Taxonomy/
│   │   └── Topic.php            Temática compartida (fnh_topic)
│   ├── REST/                    API pública, shortcodes y utilidades web
│   ├── Meta/
│   │   └── MetaRegistrar.php    Registro de meta fields con sanitización
│   └── Activation/
│       ├── Activator.php        Registro + precarga de temáticas + flush
│       └── Deactivator.php      Flush de permalinks
└── tests/                       PHPUnit (capa 6)
```

### Convenciones

- **Namespace raíz:** `FlavorNewsHub\`, PSR-4 bajo `src/`.
- **Prefijo de identificadores:** `fnh_` en CPT slugs, taxonomía, constantes y opciones; `_fnh_` en meta keys (underscore para señalar "interno del plugin").
- **Idioma de código y comentarios:** castellano. Los nombres de clases y métodos son descriptivos.
- **Seguridad REST:** los campos sensibles (`_fnh_contact_email`, `_fnh_submitted_by_email`) **no** se exponen en la REST estándar de WordPress ni se expondrán en la API propia `flavor-news/v1`.

## Meta fields

### `fnh_source`

| Meta                  | Tipo    | REST | Notas                                                                  |
|-----------------------|---------|------|------------------------------------------------------------------------|
| `_fnh_feed_url`       | string  | sí   | URL del feed                                                           |
| `_fnh_feed_type`      | string  | sí   | `rss`, `atom`, `youtube`, `mastodon`, `podcast` (por defecto `rss`)    |
| `_fnh_website_url`    | string  | sí   | Web pública del medio                                                  |
| `_fnh_languages`      | array   | sí   | Lista de códigos ISO 639-1                                             |
| `_fnh_territory`      | string  | sí   | Texto libre (Bizkaia, Catalunya, Estado…)                              |
| `_fnh_ownership`      | string  | sí   | Quién posee/financia (HTML permitido)                                  |
| `_fnh_editorial_note` | string  | sí   | Línea editorial declarada (HTML permitido)                             |
| `_fnh_active`         | boolean | sí   | Si se ingesta o no                                                     |
| `_fnh_medium_type`    | string  | sí   | Tipo editorial principal (`news`, `podcast`, `video`, `tv`, etc.)      |
| `_fnh_broadcast_format` | array | sí   | Formatos de emisión admitidos                                           |
| `_fnh_content_license` | string | sí   | Licencia o régimen de reutilización del contenido                       |
| `_fnh_legal_note`     | string  | sí   | Nota legal / aviso editorial                                            |
| `_fnh_live_stream_permit` | string | sí | Permiso para stream en directo (`none`, `cc`, etc.)                    |

### `fnh_item`

| Meta                | Tipo    | REST | Notas                                           |
|---------------------|---------|------|-------------------------------------------------|
| `_fnh_source_id`    | integer | sí   | ID del `fnh_source` origen                      |
| `_fnh_original_url` | string  | sí   | URL del artículo en el medio                    |
| `_fnh_published_at` | string  | sí   | ISO 8601 UTC                                    |
| `_fnh_guid`         | string  | sí   | Para deduplicar ingestas                        |
| `_fnh_media_url`    | string  | sí   | Imagen destacada si el feed la provee           |

### `fnh_radio`

| Meta                | Tipo    | REST | Notas                                           |
|---------------------|---------|------|-------------------------------------------------|
| `_fnh_stream_url`   | string  | sí   | Stream Icecast/HLS reproducido por la app       |
| `_fnh_rss_url`     | string  | sí   | RSS opcional de programas / podcast             |
| `_fnh_website_url` | string  | sí   | Web pública de la emisora                       |
| `_fnh_languages`   | array   | sí   | Lista de códigos ISO 639-1                      |
| `_fnh_territory`   | string  | sí   | Texto libre                                     |
| `_fnh_ownership`   | string  | sí   | Quién posee/financia                             |
| `_fnh_active`      | boolean | sí   | Si la radio aparece en el directorio            |

### `fnh_collective`

| Meta                       | Tipo    | REST  | Notas                                                    |
|----------------------------|---------|-------|----------------------------------------------------------|
| `_fnh_website_url`         | string  | sí    | Web del colectivo                                        |
| `_fnh_contact_email`       | string  | **no**| Uso interno; nunca se expone                             |
| `_fnh_territory`           | string  | sí    | Texto libre                                              |
| `_fnh_flavor_url`          | string  | sí    | Opcional; enlace a su instancia Flavor si la tienen     |
| `_fnh_verified`            | boolean | sí    | Sólo los verificados aparecen en la API pública          |
| `_fnh_submitted_by_email`  | string  | **no**| Auditoría de altas públicas; nunca se expone             |

## Licencia

AGPL-3.0-or-later. Si despliegas una instancia modificada accesible por red, tus modificaciones deben publicarse bajo la misma licencia.
