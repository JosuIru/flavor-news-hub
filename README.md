# Flavor News Hub

Una herramienta sencilla para romper el circuito entre **informarse** y **actuar**.

## Por qué existe

Hoy la gente se informa a través de plataformas diseñadas para capturar su atención, no para que entienda su realidad ni para que pueda intervenir en ella. El patrón es conocido: te enteras de un problema, sientes impotencia, scrolleas al siguiente, nada cambia.

Mientras tanto, medios alternativos y colectivos organizados hacen un trabajo enorme sobre esos mismos problemas — pero son invisibles para quien no los busca activamente.

**Flavor News Hub** hace una sola cosa bien: después de enterarte de algo, te ofrece un camino concreto hacia quien ya está organizándose sobre ello.

No es una red social. No es una plataforma de organización interna. No es un sustituto de los medios ni de los colectivos. Es una **puerta de entrada común** entre informarse y actuar.

## Qué hace, visto desde el usuario

Cinco cosas. Solo cinco.

1. **Leer noticias de medios alternativos.** Feed cronológico agregado de decenas de medios no corporativos, filtrable por temática, territorio e idioma. La app nunca reproduce el artículo completo: cada titular enlaza al medio original.
2. **Ver la ficha editorial de cada medio.** Quién lo posee, cómo se financia, qué línea editorial declara. Educación estructural aunque no leas ninguna noticia entera.
3. **Descubrir qué colectivos trabajan sobre una temática.** Junto a cada noticia, un botón claro: *"¿Quién se organiza sobre esto?"*. Lleva a un directorio filtrable de colectivos activos.
4. **Darse de alta como colectivo.** Formulario público sencillo; verificación manual por un equipo o núcleo de verificadores antes de aparecer.
5. **Compartir una noticia o colectivo.** Con el mecanismo nativo del sistema. El enlace compartido abre una versión web pública, no requiere app instalada.

Y nada más. Ni cuentas de usuario, ni notificaciones push, ni algoritmo de recomendación, ni IA, ni analítica, ni publicidad.

## Relación con Flavor Platform

Este proyecto es **complementario** pero **independiente** de [Flavor Platform](https://github.com/JosuIru/wp-flavor-platform):

- **Flavor Platform** sirve a colectivos ya organizados que necesitan herramientas para su funcionamiento interno (asambleas, economía, web, comunicación).
- **Flavor News Hub** sirve al **paso anterior**: que la gente se entere de qué pasa vía medios no corporativos y descubra qué colectivos existen sobre lo que le preocupa.

Cuando un colectivo listado aquí tiene instancia Flavor, enlazamos a ella. El camino natural de quien quiere pasar de informarse a organizarse es esa transición.

## Arquitectura

Dos piezas acopladas pero desplegables por separado:

### `backend/` — Plugin WordPress headless

Plugin `flavor-news-hub` que convierte una instalación WP normal en backend del sistema. WP porque la parte editorial (alta manual de medios, verificación de colectivos, taxonomías) es exactamente lo que WP hace bien, y porque cualquier colectivo con hosting básico puede autohospedarlo.

Incluye:

- CPTs `source`, `item`, `collective` y taxonomía compartida `topic`.
- Ingesta automática de feeds RSS/Atom cada 30 minutos vía `wp_cron` (SimplePie). Dedupe por `guid`.
- API REST pública (namespace `flavor-news/v1`) de solo lectura para items, sources, collectives y topics; más un endpoint `POST /collectives/submit` con rate limit y honeypot.
- Admin WordPress con acciones específicas (ingesta manual por fuente, verificación masiva de colectivos pendientes, log de ingesta).
- Plantillas web públicas mínimas `/n/{slug}`, `/c/{slug}`, `/f/{slug}` como fallback para enlaces compartidos desde la app.
- WP-CLI: `wp flavor-news ingest [--source=<id>]`.

Requisitos: WordPress 6.4+, PHP 8.1+, PSR-4, composer. Licencia AGPL-3.0.

### `app/` — Aplicación Flutter

App Flutter multiplataforma que consume la API del backend. Enfocada a Android primero (por público objetivo y por viabilidad de distribución fuera de Play Store: F-Droid y APK directa).

Nueve pantallas: Feed, Filtros, Detalle de noticia, Ficha editorial de medio, Directorio de colectivos, Ficha de colectivo, Alta de colectivo, Ajustes, Acerca de.

Requisitos: Flutter estable actual, Dart 3.x, i18n con ARB (es, ca, eu, gl, en), Material 3, cacheo offline básico, **cero** analítica/telemetría/Firebase/publicidad/IA. Licencia AGPL-3.0.

## Estructura del repositorio

```
flavor-news-hub/
├── README.md              visión, arquitectura, cómo contribuir
├── MANIFESTO.md           los principios irrenunciables
├── LICENSE                AGPL-3.0
├── backend/               plugin WordPress
├── app/                   aplicación Flutter
└── .github/workflows/     CI para tests del backend y build de la app
```

## CI

Dos workflows en `.github/workflows/`:

- **`backend-tests.yml`** — levanta MySQL 8, instala PHP (matriz 8.1 / 8.2) + svn, corre `composer install`, `bin/install-wp-tests.sh`, lint PHP sobre todo el plugin y `phpunit`. Se dispara al tocar `backend/**`.
- **`app-build.yml`** — instala Java 17 + Flutter stable (con caché del SDK), regenera freezed/json_serializable, corre `flutter analyze`, `flutter test` y compila un APK debug que sube como artifact con retención de 7 días. Se dispara al tocar `app/**`.

Los archivos `.freezed.dart` / `.g.dart` **no** se commitean (están en `.gitignore`): se regeneran en CI y en local con `dart run build_runner build --delete-conflicting-outputs`.

## Cómo autohospedar

Uno de los principios del proyecto es la **apropiabilidad**: cualquier colectivo debe poder levantar su propia instancia sin pedir permiso.

- **Backend:** instalar el plugin en una instalación WP estándar (via symlink desde este monorepo, zip manual, o Composer cuando esté publicado).
- **App:** la pantalla de ajustes permite cambiar la URL de la instancia backend. Por defecto apunta a la instancia oficial, pero nada impide apuntar a la tuya.

Instrucciones detalladas en `backend/README.md` y `app/README.md` (pendientes, a medida que esas piezas vayan existiendo).

## Cómo contribuir

Antes de mandar código o abrir un issue, **lee el [MANIFESTO](MANIFESTO.md)**. Si tu propuesta entra en conflicto con alguno de los principios irrenunciables, probablemente no encaje en este proyecto (pero puede encajar en un fork o en otro proyecto adyacente).

- Bugs reales y mejoras que respeten el manifiesto: issues y PRs bienvenidos.
- Features nuevas: abre primero una discusión. La vara es alta: solo entran si son claramente necesarias, no si "podrían estar bien".
- Traducciones: muy bienvenidas. Castellano, catalán, euskera, gallego e inglés son idiomas de primera clase desde el día 1.

Idioma de desarrollo interno: castellano (comentarios de código, mensajes de commit, issues). La interfaz y la documentación pública son multilingües.

## Licencia

[AGPL-3.0](LICENSE). Si despliegas una instancia modificada accesible por red, debes publicar tus modificaciones bajo la misma licencia.
