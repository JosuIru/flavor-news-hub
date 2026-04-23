package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * Widget "Buscar en Flavor News" — pill estilo Google Quick Search Box
 * con el icono de la app a la izquierda y el placeholder a la derecha.
 *
 * No tiene estado dinámico: al tocar abre la app en `/search` vía deep
 * link `flavornews://search`. No necesita refresh periódico ni callbacks
 * desde Flutter — su único propósito es ser un atajo siempre presente
 * al buscador.
 */
class BuscadorWidgetProvider : AppWidgetProvider() {

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.buscador_widget)

        val deepLink = Uri.parse("flavornews://search")
        val intent = Intent(Intent.ACTION_VIEW, deepLink).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pending = PendingIntent.getActivity(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        // Cualquier tap dentro de la pill dispara la búsqueda. Ponemos
        // el PendingIntent en el root para capturar incluso los espacios
        // entre icono y texto.
        views.setOnClickPendingIntent(R.id.buscador_widget_root, pending)

        appWidgetManager.updateAppWidget(widgetId, views)
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
}
