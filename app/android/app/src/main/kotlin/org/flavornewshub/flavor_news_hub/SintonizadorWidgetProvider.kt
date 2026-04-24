package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.net.URLEncoder

/**
 * Widget "Sintonizador" — radio antigua de madera con cuatro botones
 * (◄ anterior · ■ stop · ▶ play · ► siguiente). El índice de emisora
 * actual vive en SharedPreferences del propio widget.
 *
 * ◄ / ► disparan broadcast al propio provider → cambia el índice y
 * redibuja. Play ejecuta deep link `flavornews://radios/play/<id>`
 * que abre la app y arranca la radio con el reproductor existente.
 * Stop abre la app con un link especial que detiene la radio.
 *
 * Flutter empuja la lista de radios activas como JSON en la clave
 * `sintonizador_radios` (`WidgetSintonizadorWriter`).
 */
class SintonizadorWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACCION_ANTERIOR = "org.flavornewshub.flavor_news_hub.SINTONIZADOR_ANTERIOR"
        const val ACCION_SIGUIENTE = "org.flavornewshub.flavor_news_hub.SINTONIZADOR_SIGUIENTE"
        const val CLAVE_INDICE = "sintonizador_indice_actual"
        const val CLAVE_RADIOS = "sintonizador_radios"
        const val NUM_LEDS = 10
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            actualizarUno(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACCION_ANTERIOR -> ajustarIndice(context, delta = -1)
            ACCION_SIGUIENTE -> ajustarIndice(context, delta = +1)
        }
    }

    data class Radio(val id: Int, val nombre: String, val territorio: String, val streamUrl: String)

    private fun obtenerRadios(context: Context): List<Radio> {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(CLAVE_RADIOS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Radio(
                    id = o.optInt("id", 0),
                    nombre = o.optString("name", ""),
                    territorio = o.optString("territory", ""),
                    streamUrl = o.optString("stream_url", ""),
                )
            }.filter { it.id > 0 && it.nombre.isNotEmpty() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun ajustarIndice(context: Context, delta: Int) {
        val radios = obtenerRadios(context)
        if (radios.isEmpty()) return
        val prefs = HomeWidgetPlugin.getData(context)
        val actual = prefs.getInt(CLAVE_INDICE, 0).coerceIn(0, radios.size - 1)
        val nuevo = ((actual + delta) % radios.size + radios.size) % radios.size
        prefs.edit().putInt(CLAVE_INDICE, nuevo).apply()

        // Si ya hay radio sonando (marca escrita por el callback Dart
        // al reproducir), disparar play de la nueva emisora — así ◄/►
        // funciona como "cambiar de emisora en directo" sin pasar por
        // el botón ▶. Si el widget está parado, sólo cambiamos el dial.
        val reproduciendo = prefs.getString("sintonizador_reproduciendo_id", "") ?: ""
        if (reproduciendo.isNotEmpty()) {
            val nuevaRadio = radios[nuevo]
            val urlCodificada = URLEncoder.encode(nuevaRadio.streamUrl, "UTF-8")
            val tituloCodificado = URLEncoder.encode(nuevaRadio.nombre, "UTF-8")
            val uriPlay = Uri.parse(
                "flavornews://sintonizador/play?id=${nuevaRadio.id}&url=$urlCodificada&titulo=$tituloCodificado"
            )
            try {
                HomeWidgetBackgroundIntent.getBroadcast(context, uriPlay).send()
            } catch (_: Exception) {
                // send() puede lanzar PendingIntent.CanceledException en
                // race conditions — ignoramos y el usuario re-pulsa.
            }
        }

        // Forzar redibujado inmediato del widget.
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            ComponentName(context, SintonizadorWidgetProvider::class.java)
        )
        if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
    }

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.sintonizador_widget)
        val radios = obtenerRadios(context)
        val prefs = HomeWidgetPlugin.getData(context)

        if (radios.isEmpty()) {
            views.setTextViewText(R.id.sintonizador_nombre, context.getString(R.string.widget_sintonizador_sin_radios))
            views.setTextViewText(R.id.sintonizador_territorio, "")
            views.setTextViewText(R.id.sintonizador_leds, repeatCompat("· ", NUM_LEDS).trim())
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        val indice = prefs.getInt(CLAVE_INDICE, 0).coerceIn(0, radios.size - 1)
        val radio = radios[indice]
        val idRadio = radio.id
        views.setTextViewText(R.id.sintonizador_nombre, radio.nombre)
        views.setTextViewText(R.id.sintonizador_territorio, radio.territorio.ifEmpty { "·" })
        views.setTextViewText(R.id.sintonizador_leds, construirLeds(indice, radios.size))

        // Botón anterior → broadcast ACCION_ANTERIOR.
        val intentAnt = Intent(context, SintonizadorWidgetProvider::class.java).apply { action = ACCION_ANTERIOR }
        val pAnt = PendingIntent.getBroadcast(
            context, widgetId * 10 + 1, intentAnt,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_anterior, pAnt)

        // Botón siguiente → broadcast ACCION_SIGUIENTE.
        val intentSig = Intent(context, SintonizadorWidgetProvider::class.java).apply { action = ACCION_SIGUIENTE }
        val pSig = PendingIntent.getBroadcast(
            context, widgetId * 10 + 2, intentSig,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_siguiente, pSig)

        // Botón play → HomeWidgetBackgroundIntent que dispara el
        // callback Dart del widget (registrado en main.dart) en un
        // isolate background, sin abrir la app. El callback arranca
        // AudioPlayer con la URL del stream.
        val urlCodificada = URLEncoder.encode(radio.streamUrl, "UTF-8")
        val tituloCodificado = URLEncoder.encode(radio.nombre, "UTF-8")
        val uriPlay = Uri.parse(
            "flavornews://sintonizador/play?id=$idRadio&url=$urlCodificada&titulo=$tituloCodificado"
        )
        val pPlay = HomeWidgetBackgroundIntent.getBroadcast(context, uriPlay)
        views.setOnClickPendingIntent(R.id.sintonizador_btn_play, pPlay)

        // Tap en el display abre la app (comportamiento clásico:
        // "ver más" lleva al sitio detallado). Mantenemos el deep link.
        val intentDial = Intent(Intent.ACTION_VIEW, Uri.parse("flavornews://radios/play/$idRadio")).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pDial = PendingIntent.getActivity(
            context, widgetId * 10 + 3, intentDial,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_dial, pDial)

        // Botón stop → HomeWidgetBackgroundIntent → callback Dart
        // detiene el AudioPlayer del widget. También sin abrir la app.
        val uriStop = Uri.parse("flavornews://sintonizador/stop")
        val pStop = HomeWidgetBackgroundIntent.getBroadcast(context, uriStop)
        views.setOnClickPendingIntent(R.id.sintonizador_btn_stop, pStop)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /**
     * Construye la hilera de LEDs: 10 puntos con el activo en posición
     * proporcional al índice. Si hay menos de 10 radios, la posición
     * del activo se mapea linealmente.
     */
    private fun construirLeds(indice: Int, total: Int): String {
        val activo = if (total <= 1) 0 else (indice.toDouble() * (NUM_LEDS - 1) / (total - 1)).toInt()
        return (0 until NUM_LEDS).joinToString(" ") { if (it == activo) "◉" else "·" }
    }

    private fun repeatCompat(s: String, n: Int): String = buildString { repeat(n) { append(s) } }
}
