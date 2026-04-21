package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget de pantalla de inicio que muestra la radio que suena.
 *
 * Estado:
 *  - `radio_nombre`: nombre legible (o vacío/null).
 *  - `radio_estado`: reproduciendo / cargando / pausado / detenido / error.
 *
 * Tap en todo el widget → abre la app (MainActivity). En v1 no hay
 * controles inline: al abrir la app el usuario pulsa play/stop en la
 * pestaña Audio. Simplifica el flujo porque el servicio de audio vive
 * dentro de la app, no como broadcast receiver separado.
 */
class ReproductorRadioWidgetProvider : AppWidgetProvider() {

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
        val views = RemoteViews(context.packageName, R.layout.reproductor_radio_widget)
        val prefs = HomeWidgetPlugin.getData(context)
        val nombre = prefs.getString("radio_nombre", null)?.takeIf { it.isNotEmpty() }
        val estado = prefs.getString("radio_estado", "detenido") ?: "detenido"

        if (nombre != null) {
            views.setTextViewText(R.id.radio_nombre, nombre)
            val icono = when (estado) {
                "reproduciendo" -> android.R.drawable.ic_media_pause
                "cargando" -> android.R.drawable.ic_popup_sync
                "error" -> android.R.drawable.stat_notify_error
                else -> android.R.drawable.ic_media_play
            }
            views.setImageViewResource(R.id.radio_icon_estado, icono)
        } else {
            views.setTextViewText(
                R.id.radio_nombre,
                context.getString(R.string.widget_radio_sin_radio)
            )
            views.setImageViewResource(
                R.id.radio_icon_estado,
                android.R.drawable.ic_media_play
            )
        }

        // Tap en cualquier sitio → abre la app.
        val intent = Intent(context, MainActivity::class.java)
            .setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(android.R.id.background, pending)
        views.setOnClickPendingIntent(R.id.radio_nombre, pending)
        views.setOnClickPendingIntent(R.id.radio_icon_estado, pending)
        views.setOnClickPendingIntent(R.id.radio_cabecera, pending)

        // Botones media: envían KeyEvent al MediaSession de audio_service.
        // Si la sesión no existe (app nunca abierta), el sistema lo ignora;
        // en ese caso el usuario puede dar al área del nombre → abre app.
        views.setOnClickPendingIntent(R.id.radio_btn_playpause, MediaBotones.playPause(context))
        views.setOnClickPendingIntent(R.id.radio_btn_stop, MediaBotones.stop(context))

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(R.id.radio_nombre),
            idsTextoSecundario = listOf(R.id.radio_cabecera),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, ReproductorRadioWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
        }
    }
}
