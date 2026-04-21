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

/**
 * Widget de pantalla de inicio que pinta los 3 titulares más recientes
 * guardados por la app. Flutter escribe con `HomeWidget.saveWidgetData`
 * las claves `titular_1_*` / `titular_2_*` / `titular_3_*` — aquí las
 * leemos y las inyectamos en el RemoteViews.
 *
 * Tap en un titular → abre la app en la URL del detalle (deep link
 * `flavornews://items/<id>`). Tap en el botón refrescar → abre la app
 * normal; la app refrescará el feed al arrancar.
 */
class TitularesWidgetProvider : AppWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.titulares_widget)
        val prefs = HomeWidgetPlugin.getData(context)

        var algunoPintado = false
        for (i in 1..3) {
            val titulo = prefs.getString("titular_${i}_titulo", null)
            val fuente = prefs.getString("titular_${i}_fuente", null)
            val idItem = prefs.getString("titular_${i}_id", null)

            val idTxt = when (i) {
                1 -> R.id.titular_1; 2 -> R.id.titular_2; else -> R.id.titular_3
            }
            val idFuente = when (i) {
                1 -> R.id.titular_1_fuente; 2 -> R.id.titular_2_fuente; else -> R.id.titular_3_fuente
            }
            if (!titulo.isNullOrEmpty()) {
                algunoPintado = true
                views.setTextViewText(idTxt, titulo)
                views.setTextViewText(idFuente, fuente ?: "")
                // Deep link al detalle si hay id.
                if (!idItem.isNullOrEmpty()) {
                    val deepLink = Uri.parse("flavornews://items/$idItem")
                    val intent = HomeWidgetBackgroundIntent.getBroadcast(context, deepLink)
                    views.setOnClickPendingIntent(idTxt, intent)
                }
            } else {
                views.setTextViewText(idTxt, "")
                views.setTextViewText(idFuente, "")
            }
        }

        views.setViewVisibility(
            R.id.widget_vacio,
            if (algunoPintado) View.GONE else View.VISIBLE
        )

        // Tap en el botón refrescar → abre la app (lanza MainActivity).
        val intentAbrir = Intent(context, MainActivity::class.java)
        val pendingAbrir = PendingIntent.getActivity(
            context, 0, intentAbrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_refrescar, pendingAbrir)
        views.setOnClickPendingIntent(R.id.widget_titulo, pendingAbrir)

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(
                R.id.widget_titulo,
                R.id.titular_1, R.id.titular_2, R.id.titular_3,
            ),
            idsTextoSecundario = listOf(
                R.id.titular_1_fuente, R.id.titular_2_fuente, R.id.titular_3_fuente,
                R.id.widget_vacio,
            ),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /**
     * Permite a Flutter forzar un redraw: `HomeWidget.updateWidget(...)`
     * envía un broadcast que cae aquí y reejecuta `onUpdate`.
     */
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, TitularesWidgetProvider::class.java))
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        }
    }
}
