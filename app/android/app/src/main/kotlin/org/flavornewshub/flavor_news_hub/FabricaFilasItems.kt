package org.flavornewshub.flavor_news_hub

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL

/**
 * Factory de filas para los `ListView` de los widgets de lista de items
 * (titulares, vídeos, podcasts). Antes vivía sólo en
 * `TitularesRemoteViewsService`; al aparecer los widgets de vídeos y
 * podcasts se parametrizó por el prefijo de claves, ya que la lógica
 * (leer prefs, descargar miniaturas, pintar fila, fillInIntent) es
 * idéntica en los tres.
 *
 * La lista canónica vive en SharedPreferences (claves
 * `<prefijo>_{1..10}_*`, escritas por la app Flutter o por el refresco
 * del propio widget); aquí la leemos en `onDataSetChanged` y
 * decodificamos las miniaturas a bitmaps pequeños.
 */
class FabricaFilasItems(
    private val contexto: Context,
    private val prefijoClaveItem: String,
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "FabricaFilasItems"
        private const val MAX_ITEMS = 10
        // Tamaño máximo del lado largo de la miniatura tras decodificar.
        // Por encima de esto inSampleSize la divide entre 2/4/8 hasta
        // entrar — evita meter bitmaps gigantes en RemoteViews.
        private const val LIMITE_LADO_PX = 200
    }

    private data class FilaItem(
        val titulo: String,
        val fuente: String,
        val idItem: String,
        val urlImagen: String,
        val miniatura: Bitmap?,
    )

    private val items = mutableListOf<FilaItem>()

    // Modo oscuro que el provider detectó con su `context` del broadcast
    // y dejó en las prefs. Lo usamos en `getViewAt` en lugar de recalcular
    // con `applicationContext`, que reportaba claro aunque el sistema
    // estuviera en oscuro (texto negro sobre fondo oscuro).
    private var temaOscuro: Boolean = false

    override fun onCreate() {}

    override fun onDataSetChanged() {
        // Llamado por Android cada vez que el provider notifica un
        // cambio de datos (`notifyAppWidgetViewDataChanged`). Bloquea
        // este hilo hasta terminar — está pensado para hacer I/O.
        items.clear()
        val prefs = HomeWidgetPlugin.getData(contexto)
        temaOscuro = prefs.getBoolean(
            TemaWidget.CLAVE_TEMA_OSCURO,
            TemaWidget.esOscuro(contexto),
        )
        for (indice in 1..MAX_ITEMS) {
            val titulo = prefs.getString("${prefijoClaveItem}_${indice}_titulo", "") ?: ""
            if (titulo.isEmpty()) continue
            val fuente = prefs.getString("${prefijoClaveItem}_${indice}_fuente", "") ?: ""
            val idItem = prefs.getString("${prefijoClaveItem}_${indice}_id", "") ?: ""
            val urlImagen = prefs.getString("${prefijoClaveItem}_${indice}_imagen", "") ?: ""
            val miniatura = if (urlImagen.isNotEmpty()) descargarMiniatura(urlImagen) else null
            items.add(FilaItem(titulo, fuente, idItem, urlImagen, miniatura))
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(posicion: Int): RemoteViews {
        val fila = items[posicion]
        val vista = RemoteViews(contexto.packageName, R.layout.items_widget_fila)
        vista.setTextViewText(R.id.item_fila_titulo, fila.titulo)
        vista.setTextViewText(R.id.item_fila_fuente, fila.fuente)
        // Colores aplicados en runtime según el modo claro/oscuro del
        // sistema. El XML no puede usar `?android:attr/textColor*` aquí
        // porque resuelve contra el tema del launcher (no del widget),
        // saliendo negro contra el fondo oscuro estándar. Usamos el modo
        // que persistió el provider (ver `temaOscuro`) para coincidir
        // siempre con el color del fondo.
        val oscuro = temaOscuro
        val colorTitulo = if (oscuro) android.graphics.Color.WHITE
            else android.graphics.Color.parseColor("#111111")
        val colorFuente = if (oscuro) android.graphics.Color.parseColor("#CCE0E0E0")
            else android.graphics.Color.parseColor("#66000000")
        vista.setTextColor(R.id.item_fila_titulo, colorTitulo)
        vista.setTextColor(R.id.item_fila_fuente, colorFuente)
        if (fila.miniatura != null) {
            vista.setImageViewBitmap(R.id.item_fila_imagen, fila.miniatura)
            vista.setViewVisibility(R.id.item_fila_imagen, View.VISIBLE)
        } else {
            // Sin imagen o descarga falló: ocultamos el slot de miniatura
            // para que el texto ocupe el ancho completo.
            vista.setViewVisibility(R.id.item_fila_imagen, View.GONE)
        }

        // El tap del item se delega al `PendingIntentTemplate` que
        // configura el provider — aquí sólo aportamos el "fillInIntent"
        // con el URI específico de este item.
        if (fila.idItem.isNotEmpty()) {
            val intentRelleno = Intent().apply {
                data = Uri.parse("flavornews://items/${fila.idItem}")
            }
            vista.setOnClickFillInIntent(R.id.item_fila_root, intentRelleno)
        }
        return vista
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(posicion: Int): Long = posicion.toLong()
    override fun hasStableIds(): Boolean = true

    /**
     * Descarga la miniatura de la URL y la decodifica con submuestreo
     * para que no infle el bitmap en memoria. Devuelve null si la URL
     * es inválida, la red falla o el cuerpo no es una imagen — el
     * factory pinta esa fila sin imagen.
     */
    private fun descargarMiniatura(urlImagen: String): Bitmap? {
        return try {
            val url = URL(urlImagen)
            val conexion = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 5_000
                readTimeout = 5_000
                requestMethod = "GET"
                setRequestProperty("Accept", "image/*")
                instanceFollowRedirects = true
            }
            if (conexion.responseCode !in 200..299) {
                Log.d(TAG, "Miniatura HTTP ${conexion.responseCode}: $urlImagen")
                return null
            }
            // Bajamos el cuerpo a un byte[] para poder decodificar dos
            // veces (medir + decodificar definitivo) sin abrir dos
            // conexiones. La mayoría de imágenes web pesan <200 KB —
            // tenerlo en memoria un instante no es problemático.
            val bytes = conexion.inputStream.use { it.readBytes() }
            val opcionesMedida = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opcionesMedida)
            val ladoMaximo = maxOf(opcionesMedida.outWidth, opcionesMedida.outHeight)
            val muestreo = if (ladoMaximo <= LIMITE_LADO_PX) 1
                else Integer.highestOneBit(ladoMaximo / LIMITE_LADO_PX)
            val opcionesDecodificacion = BitmapFactory.Options().apply {
                inSampleSize = muestreo.coerceAtLeast(1)
                inPreferredConfig = Bitmap.Config.RGB_565
            }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opcionesDecodificacion)
        } catch (error: Exception) {
            Log.d(TAG, "descargarMiniatura falló: $urlImagen — $error")
            null
        }
    }
}
