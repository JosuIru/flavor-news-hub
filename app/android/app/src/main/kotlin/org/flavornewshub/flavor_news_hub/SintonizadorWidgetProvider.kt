package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

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

    private fun obtenerRadios(context: Context): List<Triple<Int, String, String>> {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(CLAVE_RADIOS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Triple(
                    o.optInt("id", 0),
                    o.optString("name", ""),
                    o.optString("territory", ""),
                )
            }.filter { it.first > 0 && it.second.isNotEmpty() }
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
        val (idRadio, nombre, territorio) = radios[indice]
        views.setTextViewText(R.id.sintonizador_nombre, nombre)
        views.setTextViewText(R.id.sintonizador_territorio, territorio.ifEmpty { "·" })
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

        // Botón play → deep link a radios/play/<id>. Abre la app y
        // arranca la emisora sintonizada vía ReproductorRadioProvider.
        val intentPlay = Intent(Intent.ACTION_VIEW, Uri.parse("flavornews://radios/play/$idRadio")).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pPlay = PendingIntent.getActivity(
            context, widgetId * 10 + 3, intentPlay,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_play, pPlay)
        views.setOnClickPendingIntent(R.id.sintonizador_dial, pPlay)

        // Botón stop → deep link genérico a /audio que abre la pestaña
        // de audio; el usuario pulsa stop allí. Alternativa: crear un
        // deep link específico `flavornews://radios/stop` — por ahora
        // mantenemos el flujo actual para evitar cambios en Dart.
        val intentStop = Intent(Intent.ACTION_VIEW, Uri.parse("flavornews://radios/play/$idRadio")).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pStop = PendingIntent.getActivity(
            context, widgetId * 10 + 4, intentStop,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
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
