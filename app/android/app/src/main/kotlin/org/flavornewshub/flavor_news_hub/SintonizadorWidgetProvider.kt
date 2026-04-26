package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.net.URLEncoder
import kotlin.random.Random

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
        const val CLAVE_REPRODUCIENDO = "sintonizador_reproduciendo_id"
        const val CLAVE_ESTADO = "sintonizador_estado"
        const val NUM_LEDS = 10
        const val LARGO_VU = 9

        // Paleta del dial: dos estados (apagado / encendido) — los aplica
        // el provider con setTextColor en runtime.
        private const val COLOR_LEDS_APAGADOS = 0xFF8A6634.toInt()
        private const val COLOR_LEDS_ENCENDIDOS = 0xFFFFC870.toInt()
        private const val COLOR_AGUJA_APAGADA = 0xFF7A2A2A.toInt()
        private const val COLOR_AGUJA_ENCENDIDA = 0xFFFF3838.toInt()

        // Glifos para el botón ▶: cambia a `…` mientras carga el stream.
        private const val GLIFO_PLAY = "▶"
        private const val GLIFO_CARGANDO = "…"

        // Bloques Unicode para el VU falso. Mezcla picos altos y bajos
        // en cada redibujado para que parezca señal viva — no hay
        // animación porque RemoteViews no la permite, sólo re-pintado.
        private val BARRAS_VU = charArrayOf('▁', '▂', '▃', '▄', '▅', '▆', '▇')
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
            views.setTextViewText(R.id.sintonizador_nombre, IdiomaWidget.recursos(context).getString(R.string.widget_sintonizador_sin_radios))
            views.setTextViewText(R.id.sintonizador_territorio, "")
            views.setTextViewText(R.id.sintonizador_leds, repeatCompat("· ", NUM_LEDS).trim())
            views.setTextViewText(R.id.sintonizador_aguja, "")
            views.setTextColor(R.id.sintonizador_leds, COLOR_LEDS_APAGADOS)
            views.setTextColor(R.id.sintonizador_aguja, COLOR_AGUJA_APAGADA)
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        val indice = prefs.getInt(CLAVE_INDICE, 0).coerceIn(0, radios.size - 1)
        val radio = radios[indice]
        val idRadio = radio.id
        // Encendido: hay una radio sonando (la marca la pone el callback
        // Dart en `sintonizador_reproduciendo_id`). El dial cambia de
        // tono apagado-marrón → ámbar brillante / aguja roja viva.
        val sonando = (prefs.getString(CLAVE_REPRODUCIENDO, "") ?: "").isNotEmpty()
        val posicionLed = if (radios.size <= 1) 0
            else (indice.toDouble() * (NUM_LEDS - 1) / (radios.size - 1)).toInt()
        views.setTextViewText(R.id.sintonizador_nombre, radio.nombre)
        views.setTextViewText(R.id.sintonizador_territorio, radio.territorio.ifEmpty { "·" })
        views.setTextViewText(R.id.sintonizador_leds, construirLeds(posicionLed))
        views.setTextViewText(R.id.sintonizador_aguja, construirAguja(posicionLed))
        views.setTextColor(
            R.id.sintonizador_leds,
            if (sonando) COLOR_LEDS_ENCENDIDOS else COLOR_LEDS_APAGADOS,
        )
        views.setTextColor(
            R.id.sintonizador_aguja,
            if (sonando) COLOR_AGUJA_ENCENDIDA else COLOR_AGUJA_APAGADA,
        )

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
     * Construye la hilera de 10 LEDs con el activo (en posición ya
     * mapeada al rango 0-9) marcado con `◉`, los demás `·`.
     */
    private fun construirLeds(posicionLed: Int): String {
        return (0 until NUM_LEDS).joinToString(" ") { if (it == posicionLed) "◉" else "·" }
    }

    /**
     * String de la aguja: misma anchura que la hilera de LEDs (los dos
     * TextView se solapan en un FrameLayout), con `│` exactamente sobre
     * el LED activo y espacios en el resto. Como ambos comparten
     * monospace + letterSpacing="0.3", la barra cae alineada.
     *
     * La hilera de LEDs es `· · · · · · · · · ·` → posición N ocupa el
     * carácter 2*N (LED) o 2*N+1 (espacio entre LEDs). Ponemos la
     * aguja en el carácter del LED activo.
     */
    private fun construirAguja(posicionLed: Int): String {
        val total = 2 * NUM_LEDS - 1
        return buildString {
            repeat(total) { i ->
                append(if (i == posicionLed * 2) '│' else ' ')
            }
        }
    }

    private fun repeatCompat(s: String, n: Int): String = buildString { repeat(n) { append(s) } }
}
