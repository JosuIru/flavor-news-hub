package org.flavornewshub.flavor_news_hub

import android.content.Intent
import android.widget.RemoteViewsService

/**
 * Services que proveen las `RemoteViewsFactory` de los `ListView` de los
 * widgets de lista. Android los invoca cuando el widget pide su
 * adaptador remoto vía `RemoteViews.setRemoteAdapter`.
 *
 * Viven en el proceso de la app (no en SystemUI) — eso permite hacer red
 * para descargar las miniaturas de cada fila sin las restricciones de
 * seguridad de RemoteViews.
 *
 * Los tres comparten la implementación [FabricaFilasItems]; sólo se
 * diferencian en el prefijo de claves de SharedPreferences del que leen.
 * Hacen falta clases distintas porque cada `AppWidgetProvider` declara
 * su propio service en el manifest.
 */
class TitularesRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        FabricaFilasItems(applicationContext, "titular")
}

/** Filas del widget de últimos vídeos. */
class VideosRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        FabricaFilasItems(applicationContext, "video")
}

/** Filas del widget de últimos podcasts. */
class PodcastsRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        FabricaFilasItems(applicationContext, "podcast")
}
