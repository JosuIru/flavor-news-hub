# flavor-news-hub · app

App Flutter que consume la API `flavor-news/v1` del backend. Enfocada a Android primero, con la misma estética sobria del proyecto, pero ya no limitada al feed y al directorio: también integra audio, TV, vídeos, música, utilidades personales, widgets y accesos web.

## Estado funcional

- Feed cronológico de noticias con filtros por temática, territorio e idioma.
- Fichas editoriales de medios con información de propiedad, financiación e idiomas.
- Hub de audio unificado: radios, podcasts y búsqueda de música federada.
- TV y vídeos con listados dedicados, filtros y reproductores.
- Directorio de colectivos con ficha pública y alta manual.
- Búsqueda global, mapa, guardados, historial, intereses y gestión de mis medios.
- Ajustes, notificaciones, actualizaciones, widget de Android y compartición de contenido.

## Modelos y cliente API

Modelos inmutables con `freezed` + `json_serializable` (`field_rename: snake` global en `build.yaml`):

- `Topic` — temática.
- `SourceSummary` — fuente resumida (la que viene embebida en un item).
- `Source` — ficha editorial completa.
- `Item` — noticia agregada.
- `Collective` — colectivo verificado.
- `PaginatedList<T>` — wrapper para respuestas paginadas (construido a partir de `X-WP-Total` / `X-WP-TotalPages`).
- `CollectiveSubmission` / `CollectiveSubmissionResult` — body y respuesta del POST público.

Cliente `FlavorNewsApi` (`lib/core/api/flavor_news_api.dart`):

- Métodos: `fetchItems`, `fetchItem`, `fetchSources`, `fetchSource`, `fetchCollectives`, `fetchCollective`, `fetchTopics`, `submitCollective`.
- Timeout de 20 s por petición. Errores de red (`SocketException`, `TimeoutException`) y errores HTTP (con body JSON `{error, message}` del backend) se normalizan a `FlavorNewsApiException` con flags `estaRateLimited`, `esNoEncontrado`, `esProblemaRed`.
- `baseUrl` inyectada (viene de `preferenciasProvider.urlInstanciaBackend`), así al cambiarla en Ajustes toda la app apunta a la nueva instancia sin reiniciar.

Providers principales (`lib/core/providers/api_provider.dart`):

- `httpClientProvider` — cliente HTTP compartido, se cierra al disponerse el provider.
- `flavorNewsApiProvider` — reactivo a la URL de instancia configurada.
- `itemsFeedProvider`, `topicsProvider`, `sourcesProvider`, `collectivesProvider` — FutureProviders listos para pantallas.

### Regenerar código

Tras tocar cualquier modelo:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Rutas y superficies

Rutas principales del router:

- `/` feed
- `/audio` radios + podcasts + música
- `/tv` TV
- `/videos` vídeos
- `/collectives` directorio de colectivos
- `/settings` ajustes
- `/search` buscador global
- `/map` mapa de territorio
- `/music` buscador de música
- `/filters` filtros de noticias
- `/items/:id` detalle de noticia
- `/sources/:id` ficha editorial de medio
- `/sources/submit` alta de medio
- `/collectives/:id` ficha de colectivo
- `/collectives/submit` alta de colectivo
- `/notificaciones`, `/guardados`, `/historial`, `/tus-intereses`, `/mis-medios`, `/fuentes-preferencias`, `/about`

## Requisitos

- Flutter estable (probado con 3.24 / Dart 3.5)
- Android SDK 34 (gradle 8.x)

## Decisiones de stack

- **Estado:** [Riverpod](https://riverpod.dev) (`flutter_riverpod`). Menos boilerplate que bloc, tipado fuerte, providers derivados encajan con UI de lectura.
- **Navegación:** [go_router](https://pub.dev/packages/go_router) declarativa + deep-linking nativo.
- **HTTP:** `http`. La API no tiene auth ni interceptors; `dio` estaría sobredimensionado.
- **Persistencia ligera:** `shared_preferences` para tema, idioma UI, URL de la instancia backend y escala de texto.
- **i18n:** ARB files + `flutter gen-l10n` generando `AppLocalizations`. Castellano, catalán, euskera, gallego e inglés como idiomas de primera clase.
- **Tema:** Material 3 sobrio a partir de `ColorScheme.fromSeed` con el mismo azul (`#0B63CE`) del CSS de las plantillas web del backend.
- **Widgets y accesos directos:** escritores nativos de widgets para titulares, favoritos, radio y música; el código Android vive junto a la app para mantener la sincronía con la UI principal.

## Estructura

```
lib/
├── main.dart                           bootstrap + ProviderScope
├── app.dart                            MaterialApp.router, tema, i18n
├── l10n/
│   ├── app_es.arb                      plantilla de claves
│   ├── app_ca.arb
│   ├── app_eu.arb
│   ├── app_gl.arb
│   └── app_en.arb
├── core/
│   ├── providers/preferences_provider.dart
│   ├── routing/app_router.dart
│   └── theme/app_theme.dart
└── features/
    ├── shell/                          NavigationBar inferior
    ├── feed/                           lista + detalle de noticia
    ├── audio/                          podcasts + reproductor compartido
    ├── tv/                             canales de TV y emisiones
    ├── videos/                         grid de vídeos y reproductor
    ├── music/                          buscador federado de música
    ├── radios/                         directorio y reproductor de radios
    ├── sources/                        ficha editorial
    ├── collectives/                    directorio + detalle + alta
    ├── personal_sources/               mis medios y descubrimiento de feeds
    ├── sources_filter/                  fuentes bloqueadas / preferencias
    ├── history/                        guardados, historial e intereses
    ├── notifications/                  preferencias y estado de notificaciones
    ├── widgets/                        escritores de widgets Android
    ├── search/                         buscador global
    ├── map/                            mapa de territorio
    ├── settings/                       ajustes
    └── about/                          manifiesto en la app
```

## Cómo correrlo en local

```bash
cd app
flutter pub get
flutter run
```

Por defecto la app apunta a la instancia oficial (placeholder `https://flavornewshub.example/...`). Desde Ajustes > URL de la instancia se puede apuntar a una instancia autohospedada o a tu WordPress local.

## i18n

Para añadir/modificar strings, edita `lib/l10n/app_es.arb` (plantilla) y réplica la clave en el resto de archivos ARB. `flutter pub get` regenera `AppLocalizations` automáticamente gracias a `generate: true` + `l10n.yaml`.

Si un idioma tiene claves pendientes, el archivo `l10n_missing.txt` las lista tras cada regeneración.

## Principios irrenunciables, aplicados

- Sin algoritmo de recomendación. El feed será cronológico inverso.
- Sin analytics, sin Firebase, sin Crashlytics, sin publicidad.
- Modo oscuro respeta `prefers-color-scheme` del sistema sin toggle intrusivo.
- Multilingüe desde el día 1 (5 idiomas). El idioma UI es independiente del idioma del contenido.

## Licencia

AGPL-3.0-or-later.
