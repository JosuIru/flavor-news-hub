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
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
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
    }

    private var reproductor: ExoPlayer? = null
    private var idRadioActual: String = ""
    private var tituloRadioActual: String = ""
    private var programaActual: String = ""

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

        crearCanalNotificacionSiHaceFalta()
        // Foreground YA con notificación de "cargando" — el sistema exige
        // que un foreground service pinte notif en los primeros 5 s.
        startForeground(NOTIFICACION_ID, construirNotificacion(cargando = true))
        actualizarEstadoWidget("cargando", idRadio, programa = "")

        // Si había ExoPlayer previo, lo soltamos y creamos uno nuevo.
        // Reusar el player con setMediaItem también funcionaría, pero un
        // player nuevo por cambio de emisora es más predecible (estado
        // interno limpio, listeners frescos).
        reproductor?.let {
            try { it.stop() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }

        val nuevoReproductor = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                /* handleAudioFocus = */ true,
            )
            .build()
            .apply {
                addListener(crearOyentePlayer())
                setMediaItem(MediaItem.fromUri(urlStream))
                playWhenReady = true
                prepare()
            }
        reproductor = nuevoReproductor
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
                        actualizarEstadoWidget("reproduciendo", idRadioActual, programaActual)
                        actualizarNotificacionAhora(cargando = false)
                    }
                }
                Player.STATE_ENDED -> {
                    // Streams en directo no deberían terminar; si lo hacen,
                    // es que el servidor cortó la conexión.
                    manejarStop()
                }
                Player.STATE_IDLE -> {
                    // Estado tras release o error grave; no refrescamos
                    // estado — `manejarStop` ya lo hace si hace falta.
                }
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            Log.w(TAG, "ExoPlayer error: ${error.errorCodeName}", error)
            manejarStop()
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
        reproductor?.let {
            try { it.stop() } catch (_: Exception) {}
            try { it.release() } catch (_: Exception) {}
        }
        reproductor = null
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
        reproductor?.let {
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
        prefs.edit()
            .putString(CLAVE_ESTADO_WIDGET, estado)
            .putString(CLAVE_ID_REPRODUCIENDO, idRadio)
            .putString(CLAVE_FUENTE, fuente)
            .putString(CLAVE_PROGRAMA, programa)
            .apply()
        val gestorWidget = AppWidgetManager.getInstance(this)
        val ids = gestorWidget.getAppWidgetIds(
            ComponentName(this, SintonizadorWidgetProvider::class.java)
        )
        if (ids.isEmpty()) return
        val intentUpdate = Intent(this, SintonizadorWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intentUpdate)
    }
}
