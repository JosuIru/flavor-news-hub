package org.flavornewshub.flavor_news_hub

import android.widget.RemoteViewsService

/**
 * Widget de pantalla de inicio que pinta los titulares más recientes.
 *
 * Toda la fontanería vive en [ProveedorWidgetItemsBase] (adaptador
 * remoto, spinner, estado de error, tema, refresco HTTP). Aquí sólo
 * queda la configuración propia: claves `titular_{1..10}_*` en el
 * almacén de `home_widget` —escritas tanto por la app Flutter en
 * `WidgetTitularesWriter` como por el botón ↻ del widget— y el filtro
 * que excluye vídeos y podcasts, que tienen widget propio.
 */
class TitularesWidgetProvider : ProveedorWidgetItemsBase() {

    companion object {
        /** Broadcast propio que dispara el tap al icono de refrescar. */
        const val ACCION_REFRESCAR = "org.flavornewshub.flavor_news_hub.WIDGET_REFRESCAR"
    }

    override val etiquetaLog = "TitularesWidget"
    override val accionRefrescar = ACCION_REFRESCAR
    override val prefijoClaveItem = "titular"
    override val prefijoClaveEstado = "titulares"
    override val layoutWidget = R.layout.titulares_widget
    override val servicioFilas: Class<out RemoteViewsService> =
        TitularesRemoteViewsService::class.java
    override val autoridadAdaptador = "titulares"
    override val filtroTipoFuente = "exclude_source_type=video,youtube,podcast"
    // Cabecera → feed principal, que es justo lo que lista el widget.
    override val uriCabecera = "flavornews://feed"
    override val stringCabecera = R.string.widget_titulares_cabecera
    override val stringVacio = R.string.widget_titulares_vacio
    override val stringActualizando = R.string.widget_titulares_actualizando
    override val stringError = R.string.widget_titulares_error
    // Sin auto-refresco: `FeedNotifier` escribe estos datos en cada
    // carga del feed, así que el widget ya llega fresco desde la app.
}
