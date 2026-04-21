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
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget de pantalla de inicio con las radios marcadas como favoritas
 * por el usuario. Máximo 3 filas visibles; si hay más favoritos, se
 * muestran los primeros (orden alfabético, mismo criterio que la app).
 *
 * Tap en una fila → abre la app con deep-link `flavornews://radios/play/<id>`.
 * La app, al recibir ese intent, navega a `/audio` y arranca esa radio.
 * Si no hay deep-link handler activo aún (versión antigua), cae a abrir
 * MainActivity sin más — el usuario navega él mismo.
 */
class FavoritosWidgetProvider : AppWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.favoritos_widget)
        val prefs = HomeWidgetPlugin.getData(context)

        var algunaPintada = false
        val filasIds = listOf(R.id.fav_fila_1, R.id.fav_fila_2, R.id.fav_fila_3)
        val nombresIds = listOf(R.id.fav_1_nombre, R.id.fav_2_nombre, R.id.fav_3_nombre)
        for (i in 0..2) {
            val claveNumerica = i + 1
            val nombre = prefs.getString("fav_radio_${claveNumerica}_nombre", null)
            val id = prefs.getString("fav_radio_${claveNumerica}_id", null)
            if (nombre.isNullOrEmpty()) {
                views.setViewVisibility(filasIds[i], View.GONE)
                continue
            }
            algunaPintada = true
            views.setViewVisibility(filasIds[i], View.VISIBLE)
            views.setTextViewText(nombresIds[i], nombre)
            // Tap en fila → deep-link con el id de la radio.
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("flavornews://radios/play/$id")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                100 + i,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(filasIds[i], pending)
        }

        views.setViewVisibility(R.id.fav_vacio, if (algunaPintada) View.GONE else View.VISIBLE)

        // Cabecera: tap → abre la app en /audio.
        val intentApp = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pendingApp = PendingIntent.getActivity(
            context, 99, intentApp,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.fav_cabecera, pendingApp)

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(
                R.id.fav_cabecera,
                R.id.fav_1_nombre, R.id.fav_2_nombre, R.id.fav_3_nombre,
            ),
            idsTextoSecundario = listOf(R.id.fav_vacio),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, FavoritosWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        }
    }
}
