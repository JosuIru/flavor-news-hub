# Manifiesto

Este documento recoge los principios irrenunciables del proyecto. No son aspiraciones ni buenas intenciones: son el contrato de diseño. Cualquier decisión técnica, de producto o de gobernanza debe poder justificarse contra ellos. Cuando haya duda, se vuelve aquí.

## 1. Sin algoritmo de engagement

El orden del contenido es **cronológico** (o, a lo sumo, resultado de curación humana explícita). Nunca un feed ordenado por "lo que más te va a enganchar".

No hay modelos de atención que predigan qué mostrarte para que te quedes más. No hay A/B tests para maximizar tiempo en pantalla. El usuario ve lo que ha pasado en el orden en que ha pasado.

## 2. Sin tracking, sin publicidad, sin telemetría

Ni propia ni de terceros. Ni Google Analytics, ni Firebase Analytics, ni Crashlytics, ni Sentry en modo "enviar telemetría a la nube". Ni píxeles, ni fingerprinting, ni "métricas anónimas de uso".

Si hace falta saber si algo falla, logs locales en el servidor propio, sin que los datos salgan de la infraestructura del proyecto.

## 3. Sin dark patterns

La app debería poder no abrirse en una semana y ser **igual de útil** cuando se abra. Eso descarta:

- Notificaciones diseñadas para que vuelvas.
- Badges rojos que inflan urgencia artificial.
- Mensajes tipo "solo quedan X" o "alguien más está viendo esto".
- Fricción intencional para desactivar avisos o desinstalar.
- Cualquier cosa cuyo propósito sea manipular en lugar de informar.

## 4. Transparencia editorial de las fuentes

Cada medio agregado expone claramente **quién lo posee, cómo se financia y qué línea editorial declara**. Esto no es un extra ni una pantalla secundaria: es parte del contenido.

El objetivo es educar estructuralmente sobre el ecosistema mediático, incluso para quien no lee una sola noticia entera.

## 5. Apropiabilidad

Licencia [AGPL-3.0](LICENSE). Cualquier colectivo debe poder **autohospedar su instancia sin pedir permiso**.

- El backend se instala en una WordPress estándar, sin dependencias esotéricas.
- La app permite cambiar la URL de la instancia en ajustes: por defecto apunta a la oficial, pero nada impide apuntar a la tuya.
- Los datos son exportables en formatos estándar (RSS/Atom para items, JSON para el resto).

Si esta herramienta no te sirve tal cual, fork. Es lo que esperamos.

## 6. Multilingüe desde el día 1

Castellano, catalán, euskera, gallego como idiomas de **primera clase**. Inglés como cuarto. Sin jerarquías entre ellos.

Esto implica:

- i18n estándar desde el principio (gettext en backend, ARB en Flutter).
- El idioma de la interfaz no determina el contenido que ves: los filtros por idioma del contenido son independientes del idioma de la UI.
- Si algún idioma arranca con traducciones parciales, se completan — no se degradan a "lo haremos más adelante".

## 7. Accesibilidad real

Contraste AA mínimo. Tamaños de texto escalables que respetan la configuración del sistema. Etiquetas semánticas. Navegación por teclado y por lector de pantalla en la web. TalkBack y VoiceOver funcionales en la app.

La accesibilidad se prueba, no se declara.

## 8. Sencillez antes que features

Si algo se complica, probablemente pertenece a [Flavor Platform](https://github.com/JosuIru/wp-flavor-platform), no aquí. La regla práctica:

- **Preferir no hacer** a **hacer complicado**.
- **Preferir un feature menos** a **un feature más que no sea claramente necesario**.
- **Preferir enlazar a una herramienta especializada** a **replicarla peor aquí**.

La v1 se mantiene deliberadamente acotada. Si una nueva área no es claramente necesaria, el listón para aceptarla es alto.

## 9. Plural en lo social-transformador, no alineado con siglas

La plataforma no es de ningún partido, de ninguna organización concreta ni de ninguna corriente ideológica específica dentro del campo social-transformador.

Agrega medios y colectivos diversos (ecologismo, feminismos, vivienda, sanidad, memoria, rural, antirracismo, cuidados, economía social, soberanía tecnológica, etc.) sin que ninguno capture la herramienta.

La curación es necesariamente editorial — ningún proyecto humano es neutral —, pero el criterio es **ecosistémico** (pluralidad de voces no corporativas), no **partidario**.

## 10. Lo que esta herramienta no es

Para evitar derivas, conviene también declarar lo que **no** es:

- **No es una red social.** No hay perfiles, no hay seguidores, no hay feed personalizado, no hay comentarios.
- **No es una plataforma de organización interna.** Eso es Flavor.
- **No es un sustituto de los medios.** Enlaza a ellos, nunca reproduce su contenido completo. Respeta su tráfico y sus ingresos.
- **No es un agregador neutro.** La selección de qué medios entran es una decisión editorial declarada, no un algoritmo.
- **No es un producto de crecimiento.** No hay métricas de adquisición, ni funnels, ni growth hacking. Si alguien la usa una vez al mes y le sirve, ya funciona.

## Revisión del manifiesto

Este documento puede revisarse, pero no a la ligera. Cualquier cambio debe:

1. Discutirse en abierto (issue público).
2. Justificar por qué el principio afectado ya no encaja con la misión.
3. Dejar rastro en el historial del repositorio.

Un cambio silencioso en el manifiesto es una señal de que algo ha ido mal.
