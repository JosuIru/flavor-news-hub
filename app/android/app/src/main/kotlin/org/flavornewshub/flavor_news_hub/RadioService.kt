package org.flavornewshub.flavor_news_hub

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.support.v4.media.session.MediaSessionCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat as MediaNotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Servicio Android foreground (`mediaPlayback`) que reproduce streams de
 * radios libres invocado desde el widget Sintonizador, sin necesidad de
 * abrir la app Flutter.
 *
 * Por qué no `home_widget` background callback:
 *   El callback Dart vive en un `JobService` con tiempo limitado por el
 *   sistema (~10 min máx). Cuando la cola del JobService termina, el
 *   `FlutterEngine` background queda sin raíz y `just_audio_background`
 *   pierde su servicio asociado — el audio se cortaba al rato.
 *
 * Por qué ExoPlayer/Media3 (y no MediaPlayer del SDK):
 *   ExoPlayer trae extracción automática de metadatos ICY. Para streams
 *   Icecast/Shoutcast (la mayoría del catálogo) eso significa que cada
 *   vez que el servidor anuncia `StreamTitle='...'` lo recibimos como
 *   `MediaMetadata.title` vía `Player.Listener.onMediaMetadataChanged`,
 *   sin parseo manual. MediaPlayer del SDK no expone ICY.
 *   Coste: ~600-800 KB en el APK release tras R8.
 *
 * Por qué un MediaSession + MediaStyle:
 *   Sin MediaSession la notificación foreground es informativa pero no
 *   integrada con los media controls de Android — no aparece en la
 *   sección "Now playing" del panel de notificaciones, ni en lockscreen.
 *   Adjuntando el token del MediaSession a una NotificationCompat.MediaStyle
 *   el sistema la promociona automáticamente a "media notification".
 *
 * Convivencia con la app principal (`just_audio_background`):
 *   Son dos rutas independientes. El usuario que abre la app y arranca
 *   una radio desde la UI usa `just_audio` (MediaSession del sistema vía
 *   `audio_service` plugin). El usuario que pulsa el widget sin abrir la
 *   app pasa por aquí. Para evitar dos streams sonando a la vez:
 *     - Al pulsar play en widget, el servicio detiene cualquier instancia
 *       previa del propio servicio ANTES de arrancar la nueva.
 *     - La app principal, al arrancar reproducción de radio desde su UI,
 *       envía un Intent ACTION_STOP al servicio nativo (vía MethodChannel
 *       `fnh/radio_service`).
 *   Hay un caso residual: si el usuario tiene el servicio sonando y
 *   abre la app sin tocar nada, ambos coexisten apagados (la app no
 *   arranca audio sin acción del usuario). Aceptable.
 */
@androidx.media3.common.util.UnstableApi
class RadioService : Service() {

    companion object {
        const val ACCION_PLAY = "org.flavornewshub.flavor_news_hub.RADIO_PLAY"
        const val ACCION_STOP = "org.flavornewshub.flavor_news_hub.RADIO_STOP"

        const val EXTRA_URL = "url"
        const val EXTRA_TITULO = "titulo"
        const val EXTRA_ID_RADIO = "id_radio"
        // Sentido en el que avanzar si la emisora falla y hay que saltar a
        // otra. +1 = siguiente (▶), -1 = anterior (◄). Para play "directo"
        // desde el dial vale +1 — la cadena de saltos sólo arranca si la
        // primera emisora falla, y avanzar es la elección menos
        // sorprendente.
        const val EXTRA_DIRECCION_SKIP = "direccion_skip"
        // Índice donde el usuario inició la cadena. Si tras varios saltos
        // damos la vuelta y volvemos aquí, paramos — todas caídas.
        // -1 (default) significa "arranque fresco": el servicio lo
        // inicializa al índice actual del Sintonizador.
        const val EXTRA_INDICE_ARRANQUE = "indice_arranque"

        private const val TAG = "RadioService"
        private const val NOTIFICACION_ID = 4242
        // Reusa el canal que ya declara `just_audio_background` para que
        // no aparezcan dos canales "Radios en directo" en ajustes del sistema.
        private const val CANAL_NOTIFICACION = "org.flavornewshub.audio"
        private const val CANAL_NOMBRE = "Radios en directo"

        private const val CLAVE_ESTADO_WIDGET = "sintonizador_estado"
        private const val CLAVE_ID_REPRODUCIENDO = "sintonizador_reproduciendo_id"
        private const val CLAVE_FUENTE = "sintonizador_fuente"
        // Programa actual (ICY StreamTitle). El widget lo lee y lo pinta
        // como tercera línea del dial cuando hay valor.
        private const val CLAVE_PROGRAMA = "sintonizador_programa"
        private const val FUENTE_SERVICIO = "servicio"

        // Índice de emisora actual del Sintonizador (dentro de la lista
        // de la banda activa, ver `leerListaRadios`). Lo escriben el
        // provider del widget, la app Flutter y este servicio al saltar.
        private const val CLAVE_INDICE_ACTUAL = "sintonizador_indice_actual"

        // Claves que lee `ReproductorRadioWidgetProvider`. Las escribe la
        // app principal (WidgetRadioWriter); también las escribimos
        // nosotros para que ese widget refleje lo que está sonando cuando
        // la fuente es este servicio y no la UI Flutter.
        private const val CLAVE_REPRODUCTOR_NOMBRE = "radio_nombre"
        private const val CLAVE_REPRODUCTOR_ESTADO = "radio_estado"

        // Cap defensivo: aunque "todas caídas" no debería ocurrir en
        // condiciones normales, evitamos un bucle infinito si la red está
        // mal o si toda la lista comparte un servidor que no responde.
        private const val MAX_SALTOS_AUTOMATICOS = 8
        // Si tras este tiempo desde `prepare()` no hemos llegado a
        // STATE_READY ni a un error, el stream se ha colgado en silencio
        // — tratamos el caso como fallo y saltamos. Algunos servidores
        // Icecast aceptan la conexión TCP y luego no entregan datos sin
        // disparar `onPlayerError`.
        private const val TIMEOUT_APERTURA_MS = 8_000L
    }

    private var reproductor: ExoPlayer? = null
    private var sesionMedia: MediaSession? = null
    private var idRadioActual: String = ""
    private var tituloRadioActual: String = ""
    private var programaActual: String = ""

    // Estado de la cadena de saltos automáticos. Se inicializa en
    // `manejarPlay` cuando el Intent llega sin `EXTRA_INDICE_ARRANQUE`
    // (= arranque fresco del usuario) y se preserva cuando el propio
    // servicio se relanza para probar la siguiente emisora.
    private var direccionSkipActual: Int = 1
    private var indiceArranqueCadena: Int = -1
    private var saltosRealizadosCadena: Int = 0

    // Handler en el main looper para programar el timeout de apertura.
    // Lo creamos lazy al primer play — antes el servicio puede ni
    // siquiera tener Looper.
    private val handlerPrincipal: Handler by lazy { Handler(Looper.getMainLooper()) }
    private var runnableTimeoutApertura: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACCION_PLAY -> manejarPlay(intent)
            ACCION_STOP -> manejarStop()
            else -> {
                // Sin acción reconocible: paramos para no dejar el servicio
                // colgando vacío.
                manejarStop()
            }
        }
        // No re-arrancamos automáticamente si el sistema mata el servicio
        // por presión de memoria — preferimos silencio a recargar el
        // stream sin que el usuario lo pidiera.
        return START_NOT_STICKY
    }

    private fun manejarPlay(intent: Intent) {
        val urlStream = intent.getStringExtra(EXTRA_URL) ?: return
        val titulo = intent.getStringExtra(EXTRA_TITULO) ?: getString(R.string.widget_sintonizador_cabecera)
        val idRadio = intent.getStringExtra(EXTRA_ID_RADIO) ?: ""
        idRadioActual = idRadio
        tituloRadioActual = titulo
        // Reset del programa al cambiar emisora — el ICY del nuevo stream
        // tarda unos segundos en llegar; mientras tanto preferimos vacío
        // a mostrar el programa de la emisora anterior.
        programaActual = ""

        // Estado de la cadena de saltos:
        //   - Si el Intent NO trae `EXTRA_INDICE_ARRANQUE` (-1), es un
        //     play "fresco" del usuario → reseteamos la cadena y tomamos
        //     como ancla el índice actual del Sintonizador.
        //   - Si lo trae, venimos de un salto automático (this servicio
        //     se relanzó a sí mismo) → preservamos el ancla y la
        //     dirección, e incrementamos el contador.
        direccionSkipActual = intent.getIntExtra(EXTRA_DIRECCION_SKIP, 1)
            .let { if (it == 0) 1 else it }
        val indiceArranqueIntent = intent.getIntExtra(EXTRA_INDICE_ARRANQUE, -1)
        if (indiceArranqueIntent < 0) {
            indiceArranqueCadena = leerIndiceActualSintonizador()
            saltosRealizadosCadena = 0
        } else {
            indiceArranqueCadena = indiceArranqueIntent
        }
        // Cualquier play en curso cancela el timeout previo — el nuevo
        // intento arma el suyo después de `prepare()`.
        cancelarTimeoutApertura()

        crearCanalNotificacionSiHaceFalta()
        // Foreground YA con notificación de "cargando" — el sistema exige
        // que un foreground service pinte notif en los primeros 5 s. La
        // notificación es MediaStyle desde el primer frame; cuando llega
        // el ICY la actualizamos en el mismo slot.
        startForeground(NOTIFICACION_ID, construirNotificacion(cargando = true))
        actualizarEstadoWidget("cargando", idRadio, programa = "")

        // Si había ExoPlayer/MediaSession previos, los soltamos y creamos
        // unos nuevos. Reusar el player con setMediaItem también funcionaría,
        // pero un player nuevo por cambio de emisora es más predecible
        // (estado interno limpio, listeners frescos, MediaSession con la
        // nueva metadata desde el principio).
        liberarReproductorYSesion()

        val nuevoReproductor = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            // Al desconectarse la salida (Bluetooth del coche, auriculares)
            // el sistema emite AUDIO_BECOMING_NOISY; con esto ExoPlayer se
            // pausa solo en vez de seguir sonando por el altavoz del móvil.
            // El listener de abajo convierte esa pausa en un stop completo
            // — para una radio en directo "pausado" no significa nada y
            // dejaría el foreground service streameando batería para nadie.
            .setHandleAudioBecomingNoisy(true)
            .build()
            .apply {
                addListener(crearOyentePlayer())
                setMediaItem(MediaItem.fromUri(urlStream))
                playWhenReady = true
                prepare()
            }
        reproductor = nuevoReproductor
        // El MediaSession se ata al ExoPlayer — todos los eventos (play,
        // pause, metadata, posición) viajan automáticamente al token que
        // la notificación referencia. El id del MediaSession es único por
        // proceso; con uno fijo Media3 lanza IllegalStateException si
        // intentamos crear otro mientras el anterior aún existe, por eso
        // `liberarReproductorYSesion()` arriba hace `release()` antes.
        sesionMedia = MediaSession.Builder(this, nuevoReproductor)
            .setId("flavor-news-hub-radio")
            .build()

        armarTimeoutApertura()
    }

    /**
     * Listener que reacciona a los eventos de ExoPlayer:
     *   - Estado del playback → traduce a "cargando" / "reproduciendo" en
     *     el widget y refresca la notificación.
     *   - Errores → para todo (stream caído, formato no soportado, etc.).
     *   - Metadatos → captura el StreamTitle ICY y lo empuja al widget
     *     para que pinte el programa actual.
     */
    private fun crearOyentePlayer(): Player.Listener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    // Buffereando: dial todavía apagado, barra de carga arriba.
                    actualizarEstadoWidget("cargando", idRadioActual, programaActual)
                }
                Player.STATE_READY -> {
                    if (reproductor?.playWhenReady == true) {
                        // El stream ha empezado a fluir — el intento ha
                        // ido bien, cancelamos el timeout de apertura y
                        // declaramos la cadena de saltos completa.
                        cancelarTimeoutApertura()
                        saltosRealizadosCadena = 0
                        actualizarEstadoWidget("reproduciendo", idRadioActual, programaActual)
                        actualizarNotificacionAhora(cargando = false)
                    }
                }
                Player.STATE_ENDED -> {
                    // Streams en directo no deberían terminar; si lo hacen,
                    // es que el servidor cortó la conexión. Para el usuario
                    // del Sintonizador es equivalente a "esta emisora ya
                    // no funciona" — intentamos la siguiente.
                    intentarSiguienteEmisoraDisponible(motivo = "stream terminó")
                }
                Player.STATE_IDLE -> {
                    // Estado tras release o error grave; no refrescamos
                    // estado — `manejarStop` ya lo hace si hace falta.
                }
            }
        }

        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            // Pausa provocada por AUDIO_BECOMING_NOISY (el coche/auriculares
            // se desconectaron): paramos del todo. Un stream en directo no
            // se puede "reanudar donde iba", y quedarnos pausados dejaría
            // el servicio foreground vivo indefinidamente.
            if (!playWhenReady &&
                reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY
            ) {
                Log.i(TAG, "Salida de audio desconectada — paramos la radio")
                manejarStop()
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            Log.w(TAG, "ExoPlayer error: ${error.errorCodeName}", error)
            intentarSiguienteEmisoraDisponible(motivo = "error ${error.errorCodeName}")
        }

        override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
            // ExoPlayer combina metadatos de varias fuentes (ICY, ID3,
            // cabeceras HTTP) en un único MediaMetadata. El StreamTitle
            // ICY suele aterrizar en `title`. Si llega vacío lo ignoramos
            // — preferimos que el widget no muestre nada antes que
            // sobrescribir un valor bueno con uno vacío transitorio.
            val titulo = mediaMetadata.title?.toString().orEmpty().trim()
            if (titulo.isEmpty()) return
            if (titulo == programaActual) return
            programaActual = titulo
            actualizarEstadoWidget(
                estado = "reproduciendo",
                idRadio = idRadioActual,
                programa = programaActual,
            )
            actualizarNotificacionAhora(cargando = false)
        }
    }

    private fun manejarStop() {
        cancelarTimeoutApertura()
        // Cualquier stop manual rompe la cadena de saltos — no quereremos
        // que un play posterior arranque "donde se quedó" intentando
        // emisoras que la usuaria ya rechazó al pulsar stop.
        indiceArranqueCadena = -1
        saltosRealizadosCadena = 0
        liberarReproductorYSesion()
        idRadioActual = ""
        tituloRadioActual = ""
        programaActual = ""
        actualizarEstadoWidget(estado = "", idRadio = "", programa = "")
        // STOP_FOREGROUND_REMOVE quita la notificación además de salir
        // de foreground; en versiones < N usamos el booleano legacy.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        liberarReproductorYSesion()
    }

    private fun liberarReproductorYSesion() {
        sesionMedia?.let {
            try { it.release() } catch (_: Exception) {}
        }
        sesionMedia = null
        reproductor?.let {
            try { it.stop() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }
        reproductor = null
    }

    private fun crearCanalNotificacionSiHaceFalta() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val gestorNotif = getSystemService(NotificationManager::class.java) ?: return
        // `IMPORTANCE_LOW` evita sonido y badge — la notificación es
        // informativa de "estás escuchando", no una alerta.
        val canal = NotificationChannel(
            CANAL_NOTIFICACION,
            CANAL_NOMBRE,
            NotificationManager.IMPORTANCE_LOW,
        )
        gestorNotif.createNotificationChannel(canal)
    }

    private fun construirNotificacion(cargando: Boolean): android.app.Notification {
        // Tap en la notificación → abrir la app (MainActivity).
        val intentAbrir = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pIntentAbrir = PendingIntent.getActivity(
            this, 0, intentAbrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        // Acción "Parar" → vuelve aquí con ACCION_STOP.
        val intentParar = Intent(this, RadioService::class.java).apply {
            action = ACCION_STOP
        }
        val pIntentParar = PendingIntent.getService(
            this, 1, intentParar,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        // Título principal: programa actual si el ICY ya llegó; si no, la
        // emisora. Subtítulo siempre la emisora cuando hay programa, o
        // texto genérico.
        val tituloMostrado = when {
            cargando -> getString(R.string.radio_service_cargando)
            programaActual.isNotEmpty() -> programaActual
            tituloRadioActual.isNotEmpty() -> tituloRadioActual
            else -> getString(R.string.widget_sintonizador_cabecera)
        }
        val subtituloMostrado = when {
            cargando -> getString(R.string.radio_service_subtitulo)
            programaActual.isNotEmpty() && tituloRadioActual.isNotEmpty() -> tituloRadioActual
            else -> getString(R.string.radio_service_subtitulo)
        }

        // MediaStyle anclada al token del MediaSession: el sistema la
        // promociona a "media notification" — aparece en lockscreen, en
        // la sección "Now playing" del panel de notificaciones, y los
        // controles del cabezal Bluetooth/auriculares también la usan.
        // Si la sesión todavía no existe (caso primer frame de
        // "cargando" antes de crear el player), el estilo cae a una
        // notificación normal — Media3 lo tolera y la próxima
        // actualización (`actualizarNotificacionAhora`) la sustituye con
        // la versión MediaStyle completa.
        val estilo = MediaNotificationCompat.MediaStyle()
            .setShowActionsInCompactView(0)
        // El MediaStyle legacy espera un `MediaSessionCompat.Token`. El
        // MediaSession Media3 expone su token framework vía `platformToken`;
        // `MediaSessionCompat.Token.fromToken` lo envuelve sin copia para
        // que ambas APIs hablen entre sí.
        sesionMedia?.platformToken?.let {
            estilo.setMediaSession(MediaSessionCompat.Token.fromToken(it))
        }

        return NotificationCompat.Builder(this, CANAL_NOTIFICACION)
            .setContentTitle(tituloMostrado)
            .setContentText(subtituloMostrado)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pIntentAbrir)
            .addAction(
                R.drawable.ic_radio_stop,
                getString(R.string.radio_service_parar),
                pIntentParar,
            )
            .setStyle(estilo)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .build()
    }

    private fun actualizarNotificacionAhora(cargando: Boolean) {
        val gestorNotif = getSystemService(NotificationManager::class.java) ?: return
        gestorNotif.notify(NOTIFICACION_ID, construirNotificacion(cargando))
    }

    /**
     * Empuja el estado del playback a las SharedPreferences que el
     * widget lee, y dispara un onUpdate del provider. Centralizado aquí
     * para que el widget refleje siempre lo que está pasando en el
     * servicio sin necesidad de un canal aparte.
     *
     * `programa` es el StreamTitle ICY actual; vacío si todavía no llegó
     * o si el servidor no expone metadatos. El widget lo pinta como
     * tercera línea del dial cuando hay contenido.
     */
    private fun actualizarEstadoWidget(estado: String, idRadio: String, programa: String) {
        val prefs = HomeWidgetPlugin.getData(this)
        // Cuando este servicio reproduce, marca FUENTE_SERVICIO. Cuando
        // para (estado vacío) limpiamos la fuente para que la app o un
        // futuro servicio pueda tomar el dial sin estado fantasma.
        val fuente = if (estado.isEmpty()) "" else FUENTE_SERVICIO
        // Para el ReproductorRadioWidgetProvider — comparte vocabulario
        // de estados con WidgetRadioWriter (Flutter). "" → "detenido".
        val estadoReproductor = if (estado.isEmpty()) "detenido" else estado
        val nombreReproductor = if (estado.isEmpty()) "" else tituloRadioActual
        prefs.edit()
            .putString(CLAVE_ESTADO_WIDGET, estado)
            .putString(CLAVE_ID_REPRODUCIENDO, idRadio)
            .putString(CLAVE_FUENTE, fuente)
            .putString(CLAVE_PROGRAMA, programa)
            .putString(CLAVE_REPRODUCTOR_NOMBRE, nombreReproductor)
            .putString(CLAVE_REPRODUCTOR_ESTADO, estadoReproductor)
            .apply()
        val gestorWidget = AppWidgetManager.getInstance(this)
        val idsSintonizador = gestorWidget.getAppWidgetIds(
            ComponentName(this, SintonizadorWidgetProvider::class.java)
        )
        if (idsSintonizador.isNotEmpty()) {
            val intentSintonizador = Intent(this, SintonizadorWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, idsSintonizador)
            }
            sendBroadcast(intentSintonizador)
        }
        // También notificamos al ReproductorRadioWidgetProvider — su
        // `onReceive` ya escucha ACTION_APPWIDGET_UPDATE y refresca los
        // ids que correspondan. Sin esto, el widget Reproductor sólo se
        // refrescaba cuando la app principal reproducía desde su UI
        // (vía WidgetRadioWriter) y se quedaba congelado mientras
        // sonaba la radio del Sintonizador.
        val idsReproductor = gestorWidget.getAppWidgetIds(
            ComponentName(this, ReproductorRadioWidgetProvider::class.java)
        )
        if (idsReproductor.isNotEmpty()) {
            val intentReproductor = Intent(this, ReproductorRadioWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, idsReproductor)
            }
            sendBroadcast(intentReproductor)
        }
    }

    /**
     * Lee la lista de radios de la banda activa del Sintonizador (todas o
     * sólo favoritas — misma lista y orden que navega el widget, ver
     * `SintonizadorWidgetProvider.leerRadiosBanda`). Devuelve tríos
     * (id, nombre, url) — sólo nos hace falta saber el tamaño y la
     * URL/nombre del índice que vayamos a probar. Compartir la banda
     * importa: la cadena de saltos no debe sacar al usuario de FAV, y el
     * índice `sintonizador_indice_actual` apunta dentro de esta lista.
     *
     * Si el JSON está malformado o la clave no existe, devolvemos lista
     * vacía y la lógica de salto cae a `manejarStop` — el servicio no se
     * inventa un siguiente cuando no hay nada que probar.
     */
    private fun leerListaRadios(): List<Triple<String, String, String>> {
        return SintonizadorWidgetProvider.leerRadiosBanda(this)
            .filter { it.streamUrl.isNotEmpty() }
            .map { Triple(it.id.toString(), it.nombre, it.streamUrl) }
    }

    private fun leerIndiceActualSintonizador(): Int {
        val prefs = HomeWidgetPlugin.getData(this)
        return prefs.getInt(CLAVE_INDICE_ACTUAL, 0)
    }

    /**
     * Núcleo del skip automático. Llamado desde `onPlayerError`, desde
     * STATE_ENDED y desde el timeout de apertura. Avanza en el sentido
     * de la cadena (`direccionSkipActual`) y relanza `manejarPlay` con
     * la siguiente emisora. Si superamos `MAX_SALTOS_AUTOMATICOS` o
     * damos la vuelta al índice de arranque, paramos — el sistema ha
     * agotado las opciones razonables.
     */
    private fun intentarSiguienteEmisoraDisponible(motivo: String) {
        cancelarTimeoutApertura()
        val radios = leerListaRadios()
        if (radios.isEmpty()) {
            Log.w(TAG, "Skip pedido ($motivo) pero no hay lista de radios en prefs")
            manejarStop()
            return
        }
        if (saltosRealizadosCadena >= MAX_SALTOS_AUTOMATICOS) {
            Log.w(TAG, "Skip pedido ($motivo) pero ya hemos probado $saltosRealizadosCadena emisoras — paramos")
            manejarStop()
            return
        }
        val indiceActual = leerIndiceActualSintonizador().coerceIn(0, radios.size - 1)
        val indiceSiguiente = (((indiceActual + direccionSkipActual) % radios.size) + radios.size) % radios.size
        // Si la cadena vuelve a su origen es señal de que hemos
        // recorrido toda la lista sin éxito (cap explícito por encima
        // del MAX_SALTOS para listas cortas — en listas largas el cap
        // de saltos pega antes).
        val anclaValida = indiceArranqueCadena in radios.indices
        if (anclaValida && indiceSiguiente == indiceArranqueCadena && saltosRealizadosCadena > 0) {
            Log.w(TAG, "Skip pedido ($motivo) ha dado la vuelta entera — paramos")
            manejarStop()
            return
        }
        val (id, nombre, url) = radios[indiceSiguiente]
        Log.i(TAG, "Skip automático ($motivo): índice $indiceActual → $indiceSiguiente ($nombre)")

        // Persistimos el nuevo índice para que el Sintonizador refleje
        // la emisora que vamos a probar (el dial avanza solo durante la
        // cadena de saltos).
        val prefs = HomeWidgetPlugin.getData(this)
        prefs.edit().putInt(CLAVE_INDICE_ACTUAL, indiceSiguiente).apply()
        saltosRealizadosCadena += 1

        val intentSiguiente = Intent(this, RadioService::class.java).apply {
            action = ACCION_PLAY
            putExtra(EXTRA_URL, url)
            putExtra(EXTRA_TITULO, nombre)
            putExtra(EXTRA_ID_RADIO, id)
            putExtra(EXTRA_DIRECCION_SKIP, direccionSkipActual)
            putExtra(EXTRA_INDICE_ARRANQUE, indiceArranqueCadena)
        }
        // Llamada directa en vez de `startService` — ya estamos en el
        // proceso del servicio y no hace falta atravesar el sistema de
        // intents. Además garantiza que se ejecute aunque el sistema
        // esté bajo presión.
        manejarPlay(intentSiguiente)
    }

    private fun armarTimeoutApertura() {
        // Capturamos id e índice actuales para distinguir si el timeout
        // dispara sobre el intento que lo armó o sobre uno posterior (en
        // ese caso lo ignoramos — el intento ya fue superado).
        val idObjetivo = idRadioActual
        val runnable = Runnable {
            if (idObjetivo != idRadioActual) return@Runnable
            // Si para cuando dispara el timeout el player ya está
            // listo y sonando, no hace falta saltar.
            val rep = reproductor ?: return@Runnable
            if (rep.playbackState == Player.STATE_READY && rep.playWhenReady) return@Runnable
            intentarSiguienteEmisoraDisponible(motivo = "timeout apertura")
        }
        runnableTimeoutApertura = runnable
        handlerPrincipal.postDelayed(runnable, TIMEOUT_APERTURA_MS)
    }

    private fun cancelarTimeoutApertura() {
        runnableTimeoutApertura?.let { handlerPrincipal.removeCallbacks(it) }
        runnableTimeoutApertura = null
    }
}
