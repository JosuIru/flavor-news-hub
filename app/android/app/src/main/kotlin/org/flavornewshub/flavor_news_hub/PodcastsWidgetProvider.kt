package org.flavornewshub.flavor_news_hub

import android.widget.RemoteViewsService

/**
 * Widget de pantalla de inicio con los últimos episodios de podcast
 * (fuentes con `feed_type=podcast`). Mismo esqueleto que el de
 * titulares — ver [ProveedorWidgetItemsBase].
 *
 * Se autoabastece igual que el de vídeos (nada lo escribe desde Flutter
 * en cada carga del feed): pide datos al colocarse y cada 30 minutos
 * como máximo, además del ↻ manual.
 *
 * El tap abre el detalle del episodio en la app (`flavornews://items/<id>`),
 * desde donde el usuario lo reproduce; no arranca audio directamente.
 */
class PodcastsWidgetProvider : ProveedorWidgetItemsBase() {

    companion object {
        const val ACCION_REFRESCAR = "org.flavornewshub.flavor_news_hub.WIDGET_PODCASTS_REFRESCAR"
    }

    override val etiquetaLog = "PodcastsWidget"
    override val accionRefrescar = ACCION_REFRESCAR
    override val prefijoClaveItem = "podcast"
    override val prefijoClaveEstado = "podcasts"
    override val layoutWidget = R.layout.podcasts_widget
    override val servicioFilas: Class<out RemoteViewsService> =
        PodcastsRemoteViewsService::class.java
    override val autoridadAdaptador = "podcasts"
    override val filtroTipoFuente = "source_type=podcast"
    // Cabecera → pestaña Podcasts dentro de Audio.
    override val uriCabecera = "flavornews://audio?tab=podcasts"
    override val stringCabecera = R.string.widget_podcasts_cabecera
    override val stringVacio = R.string.widget_podcasts_vacio
    override val stringActualizando = R.string.widget_titulares_actualizando
    override val stringError = R.string.widget_titulares_error
    override val minutosAutoRefresco = 30
    // Un podcast publica varios episodios seguidos: sin tope el widget
    // enseñaba un único canal aunque el directorio tenga muchos más.
    override val maximoPorFuente = 2
}
