package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Widget de pantalla de inicio que refleja la pista sonando en la cola de
 * música (`reproductorEpisodioProvider`).
 *
 * Claves escritas por Flutter:
 *  - `musica_titulo`, `musica_artista`, `musica_estado`
 *  - `musica_portada` (URL), `musica_posicion_cola` (ej. "3/20")
 *
 * Descarga la portada en un hilo secundario si no está cacheada; en
 * caso de fallo, deja el icono por defecto. No reintenta — un widget
 * debe ser barato, no terco.
 */
class ReproductorMusicaWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            actualizarUno(context, appWidgetManager, widgetId)
        }
    }

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.reproductor_musica_widget)
        val prefs = HomeWidgetPlugin.getData(context)

        val titulo = prefs.getString("musica_titulo", null)?.takeIf { it.isNotEmpty() }
        val artista = prefs.getString("musica_artista", "") ?: ""
        val estado = prefs.getString("musica_estado", "detenido") ?: "detenido"
        val portadaUrl = prefs.getString("musica_portada", "") ?: ""
        val posicionCola = prefs.getString("musica_posicion_cola", "") ?: ""

        if (titulo != null) {
            views.setTextViewText(R.id.musica_titulo, titulo)
            val sub = if (posicionCola.isNotEmpty()) {
                if (artista.isNotEmpty()) "$artista · $posicionCola" else posicionCola
            } else {
                artista
            }
            views.setTextViewText(R.id.musica_artista, sub)
            val icono = when (estado) {
                "reproduciendo" -> android.R.drawable.ic_media_pause
                "cargando" -> android.R.drawable.ic_popup_sync
                "error" -> android.R.drawable.stat_notify_error
                else -> android.R.drawable.ic_media_play
            }
            views.setImageViewResource(R.id.musica_icon_estado, icono)
        } else {
            views.setTextViewText(
                R.id.musica_titulo,
                IdiomaWidget.recursos(context).getString(R.string.widget_musica_sin_pista)
            )
            views.setTextViewText(R.id.musica_artista, "")
            views.setImageViewResource(
                R.id.musica_icon_estado,
                android.R.drawable.ic_media_play
            )
        }

        // Tap en todo el widget → abre la app.
        val intent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(
            context, 1, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.musica_titulo, pending)
        views.setOnClickPendingIntent(R.id.musica_artista, pending)
        views.setOnClickPendingIntent(R.id.musica_cabecera, pending)
        views.setOnClickPendingIntent(R.id.musica_icon_estado, pending)
        views.setOnClickPendingIntent(R.id.musica_portada, pending)

        // Controles inline: previo / play-pause / siguiente. Rutan a la
        // MediaSession activa de just_audio_background.
        views.setOnClickPendingIntent(R.id.musica_btn_prev, MediaBotones.previo(context))
        views.setOnClickPendingIntent(R.id.musica_btn_playpause, MediaBotones.playPause(context))
        views.setOnClickPendingIntent(R.id.musica_btn_next, MediaBotones.siguiente(context))

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(R.id.musica_titulo),
            idsTextoSecundario = listOf(R.id.musica_cabecera, R.id.musica_artista),
        )

        // Descarga la portada en background y actualiza el widget
        // cuando llega. Si no hay URL o falla, dejamos el icono por
        // defecto ya puesto en el layout.
        //
        // Carrera con cambios rápidos de pista: si el usuario salta
        // varias canciones seguidas, varios hilos descargan portadas
        // en paralelo y al terminar todos llaman a updateAppWidget.
        // Sin esta protección, una portada vieja podía llegar tarde
        // y sobrescribir la nueva. Solución: comparar la URL de la
        // pista actual al persistir; si cambió mientras descargábamos,
        // descartamos el resultado.
        if (portadaUrl.startsWith("http")) {
            val urlEsperada = portadaUrl
            thread(start = true, isDaemon = true, name = "fnh-cover-widget") {
                try {
                    val bitmap = descargarBitmap(urlEsperada)
                    if (bitmap != null) {
                        val urlActualEnPrefs = HomeWidgetPlugin.getData(context)
                            .getString("musica_portada", "") ?: ""
                        if (urlActualEnPrefs == urlEsperada) {
                            views.setImageViewBitmap(R.id.musica_portada, bitmap)
                            appWidgetManager.updateAppWidget(widgetId, views)
                        }
                        // Si la URL cambió mientras descargábamos,
                        // descartamos esta portada — un thread más
                        // reciente la sobrescribirá con la correcta.
                    }
                } catch (_: Exception) {
                    // Ignorar: el widget queda con el icono genérico.
                }
            }
        }

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun descargarBitmap(url: String): android.graphics.Bitmap? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 5000
        conn.readTimeout = 8000
        conn.setRequestProperty("User-Agent", "FlavorNewsHub/1.0 (widget)")
        conn.instanceFollowRedirects = true
        return try {
            if (conn.responseCode in 200..299) {
                BitmapFactory.decodeStream(conn.inputStream)
            } else {
                null
            }
        } finally {
            conn.disconnect()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, ReproductorMusicaWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        }
    }
}
