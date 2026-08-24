package org.flavornewshub.flavor_news_hub

import android.widget.RemoteViewsService

/**
 * Widget de pantalla de inicio con los últimos vídeos (YouTube,
 * PeerTube y demás fuentes con `feed_type` de vídeo). Mismo esqueleto
 * que el de titulares — ver [ProveedorWidgetItemsBase].
 *
 * A diferencia de titulares, nadie escribe estos datos desde Flutter en
 * cada carga del feed, así que el widget se autoabastece: pide datos al
 * backend al colocarse y cada 30 minutos como máximo (ver
 * `minutosAutoRefresco`), además del ↻ manual.
 *
 * El `source_type` replica el de `videosProvider` en la app para que la
 * lista del widget coincida con la pestaña Vídeos.
 */
class VideosWidgetProvider : ProveedorWidgetItemsBase() {

    companion object {
        const val ACCION_REFRESCAR = "org.flavornewshub.flavor_news_hub.WIDGET_VIDEOS_REFRESCAR"
    }

    override val etiquetaLog = "VideosWidget"
    override val accionRefrescar = ACCION_REFRESCAR
    override val prefijoClaveItem = "video"
    override val prefijoClaveEstado = "videos"
    override val layoutWidget = R.layout.videos_widget
    override val servicioFilas: Class<out RemoteViewsService> =
        VideosRemoteViewsService::class.java
    override val autoridadAdaptador = "videos"
    override val filtroTipoFuente = "source_type=video,youtube,peertube"
    // Cabecera → pantalla Vídeos de la app.
    override val uriCabecera = "flavornews://videos"
    override val stringCabecera = R.string.widget_videos_cabecera
    override val stringVacio = R.string.widget_videos_vacio
    override val stringActualizando = R.string.widget_titulares_actualizando
    override val stringError = R.string.widget_titulares_error
    override val minutosAutoRefresco = 30
    // Pocas fuentes publican vídeo y lo hacen a rachas: sin tope, un
    // solo canal llenaba la lista entera.
    override val maximoPorFuente = 2
}
