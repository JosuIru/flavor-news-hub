package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import org.json.JSONArray
import org.json.JSONObject

/**
 * Widget de pantalla de inicio que pinta los titulares más recientes.
 * Hasta v0.10.0 mostraba 3 slots fijos en el layout; ahora el contenido
 * lo sirve un `RemoteViewsService` (`TitularesRemoteViewsService`) que
 * provee filas en un `ListView` scrolleable, con miniatura opcional a
 * la derecha. La fuente de datos sigue siendo SharedPreferences
 * (claves `titular_{1..10}_*`), escritas tanto por la app (Flutter en
 * `WidgetTitularesWriter`) como por el botón de refrescar del propio
 * widget (`refrescarDesdeBackend` aquí abajo).
 *
 * Tap en un titular → abre la app vía deep link `flavornews://items/<id>`.
 * Configurado con `setPendingIntentTemplate` + `setOnClickFillInIntent`
 * en la factory.
 */
class TitularesWidgetProvider : AppWidgetProvider() {

    companion object {
        /** Broadcast propio que dispara el tap al icono de refrescar. */
        const val ACCION_REFRESCAR = "org.flavornewshub.flavor_news_hub.WIDGET_REFRESCAR"
    }

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.titulares_widget)

        // Configurar el adaptador remoto del ListView. Cada widget pone
        // su propio extra `appWidgetId` para que la factory pueda
        // diferenciarse si hay varios widgets a la vez (no usado hoy
        // pero estándar). El sistema invoca `onGetViewFactory` del
        // service y pinta cada fila vía la factory.
        val intentAdapter = Intent(context, TitularesRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            // setData con un URI único por widget — sin esto, cuando hay
            // varios widgets el sistema reutiliza la factory y los
            // datos de uno se cuelan en el otro.
            data = Uri.parse("widget://titulares/$widgetId")
        }
        views.setRemoteAdapter(R.id.titulares_lista, intentAdapter)
        views.setEmptyView(R.id.titulares_lista, R.id.widget_vacio)

        // PendingIntent template — el sistema lo combina con el
        // `fillInIntent` que la factory pone en cada fila para abrir el
        // detalle del titular pulsado.
        //
        // CLAVE: el template NO debe traer `data` propia. `Intent.fillIn()`
        // sólo sobreescribe el `data` del template si el template tiene ese
        // campo en null (ó si pasas FILL_IN_DATA explícitamente, cosa que
        // RemoteViews no hace al merger). Si dejamos un placeholder
        // (p.ej. "flavornews://items/") el sistema entrega ese URI sin id
        // y la app sólo se abre. Sin `data` aquí + `data` en el fillIn de
        // la factory → llega `flavornews://items/<id>` correctamente.
        val intentTemplate = Intent(Intent.ACTION_VIEW).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        // `FLAG_MUTABLE` (no `FLAG_IMMUTABLE`) — el sistema necesita
        // modificar el intent al combinarlo con el fillInIntent de cada
        // fila. Mutables son la excepción a la norma "siempre immutable":
        // los templates de RemoteViews exigen mutabilidad.
        val pendingTemplate = PendingIntent.getActivity(
            context, widgetId * 10 + 8, intentTemplate,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setPendingIntentTemplate(R.id.titulares_lista, pendingTemplate)

        // Estado del refresh — repintamos en la cabecera o como hint.
        // Para no inflar el layout, sustituimos el texto del empty view
        // por el mensaje de error o "actualizando" cuando la lista esté
        // vacía. Cuando hay items, el ListView gana visibilidad y el
        // empty view queda oculto automáticamente.
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        val recursos = IdiomaWidget.recursos(context)
        val actualizando = widgetPrefs.getBoolean("titulares_actualizando", false)
        val ultimoError = widgetPrefs.getString("titulares_ultimo_error", "") ?: ""
        val textoEmpty = when {
            actualizando -> recursos.getString(R.string.widget_titulares_actualizando)
            ultimoError.isNotEmpty() -> recursos.getString(
                R.string.widget_titulares_error, ultimoError
            )
            else -> recursos.getString(R.string.widget_titulares_vacio)
        }
        views.setTextViewText(R.id.widget_vacio, textoEmpty)

        // Spinner girando mientras dura el refresh — el icono ↻ se oculta
        // y el ProgressBar indeterminado ocupa su sitio. RemoteViews no
        // permite arrancar AnimatedVectorDrawable, así que esta es la
        // única vía fiable de mostrar movimiento.
        views.setViewVisibility(
            R.id.widget_refrescar_icono,
            if (actualizando) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_refrescar_spinner,
            if (actualizando) View.VISIBLE else View.GONE,
        )

        // Tap refrescar → broadcast a nosotros mismos.
        val intentRefrescar = Intent(context, TitularesWidgetProvider::class.java).apply {
            action = ACCION_REFRESCAR
        }
        val pendingRefrescar = PendingIntent.getBroadcast(
            context, widgetId * 10 + 9, intentRefrescar,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_refrescar, pendingRefrescar)

        // Tap en la cabecera abre la app principal.
        val intentAbrir = Intent(context, MainActivity::class.java)
        val pendingAbrir = PendingIntent.getActivity(
            context, 0, intentAbrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_titulo, pendingAbrir)

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(R.id.widget_titulo),
            idsTextoSecundario = listOf(R.id.widget_vacio),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
        // Notificar a la factory que sus datos pueden haber cambiado —
        // sin esto el ListView no recarga aunque cambien las prefs.
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.titulares_lista)
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("TitularesWidget", "onReceive action=${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == ACCION_REFRESCAR) {
            refrescarDesdeBackend(context)
            return
        }
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, TitularesWidgetProvider::class.java))
        if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d("TitularesWidget", "onUpdate widgets=${appWidgetIds.size}")
        for (widgetId in appWidgetIds) {
            actualizarUno(context, appWidgetManager, widgetId)
        }
    }

    /**
     * Petición HTTP directa al backend (en un Thread, no el main) para
     * traer los titulares más recientes y escribirlos en el almacén
     * del widget sin abrir la app. Aplica los mismos filtros que el
     * feed in-app (fuentes bloqueadas, exclude_source_type) para que
     * lo que ve el usuario en el widget coincida con el feed.
     *
     * Antes de llamar pintamos un estado "actualizando"; al terminar
     * (OK o error) lo repintamos con el dato final. Mantiene
     * consistencia visual para el usuario.
     */
    private fun refrescarDesdeBackend(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            ComponentName(context, TitularesWidgetProvider::class.java)
        )
        // Marcar estado "actualizando" antes de empezar.
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        widgetPrefs.edit().putBoolean("titulares_actualizando", true).apply()
        if (ids.isNotEmpty()) onUpdate(context, mgr, ids)

        Thread {
            var errorMensaje: String? = null
            try {
                val prefs = context.getSharedPreferences(
                    "FlutterSharedPreferences", Context.MODE_PRIVATE
                )
                val urlBase = prefs.getString("flutter.fnh.pref.backendUrl", null)
                if (urlBase.isNullOrBlank()) {
                    errorMensaje = "backend no configurado"
                    return@Thread
                }
                val base = urlBase.trimEnd('/')
                val parametros = StringBuilder("per_page=20&exclude_source_type=video,youtube,podcast")

                // Filtros transversales (slugs de topics + override de
                // territorio + override de idiomas) — mismo set que el
                // FeedNotifier compone con `filtrosTransversalesProvider`.
                val filtrosTransversales = leerFiltrosTransversales(prefs)

                val territorioBase = prefs.getString("flutter.fnh.pref.territorioBase", "") ?: ""
                // Override transversal de territorio tiene precedencia
                // sobre el territorioBase, igual que en feed_notifier.dart.
                val territorioEfectivo = filtrosTransversales.territorioOverride
                    ?.takeIf { it.isNotBlank() }
                    ?: territorioBase
                if (territorioEfectivo.isNotBlank()) {
                    parametros.append("&territory=").append(URLEncoder.encode(territorioEfectivo, "UTF-8"))
                }

                // Override de idiomas idem: si hay chips activos en
                // cualquier pestaña, ganan a la política central.
                val idiomasEfectivos = filtrosTransversales.idiomasOverride
                    .ifEmpty { leerIdiomasContenidoEfectivos(prefs) }
                if (idiomasEfectivos.isNotEmpty()) {
                    parametros.append("&language=").append(
                        URLEncoder.encode(idiomasEfectivos.joinToString(","), "UTF-8")
                    )
                }

                if (filtrosTransversales.slugsTopics.isNotEmpty()) {
                    parametros.append("&topic=").append(
                        URLEncoder.encode(filtrosTransversales.slugsTopics.joinToString(","), "UTF-8")
                    )
                }
                val url = URL("$base/items?$parametros")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 10_000
                    readTimeout = 10_000
                }
                if (conn.responseCode !in 200..299) {
                    errorMensaje = "HTTP ${conn.responseCode}"
                    return@Thread
                }
                val cuerpo = conn.inputStream.bufferedReader().use { it.readText() }
                val items = JSONArray(cuerpo)

                // Fuentes bloqueadas por el usuario (mismo filtro que el
                // FeedNotifier aplica in-app) — evita que el widget
                // enseñe titulares de medios que el usuario silenció.
                val bloqueadasRaw = prefs.getStringSet(
                    "flutter.fnh.pref.fuentesBloqueadas", emptySet()
                ) ?: emptySet()
                val bloqueadas: Set<Int> = bloqueadasRaw.mapNotNull { it.toIntOrNull() }.toSet()

                val maximoSlots = 10
                val filtrados = mutableListOf<JSONObject>()
                for (i in 0 until items.length()) {
                    val it = items.getJSONObject(i)
                    val idSrc = it.optJSONObject("source")?.optInt("id") ?: 0
                    if (idSrc > 0 && bloqueadas.contains(idSrc)) continue
                    filtrados.add(it)
                    if (filtrados.size >= maximoSlots) break
                }

                val editor = widgetPrefs.edit()
                for (i in 0 until maximoSlots) {
                    val slot = i + 1
                    if (i < filtrados.size) {
                        val item = filtrados[i]
                        editor.putString("titular_${slot}_titulo", item.optString("title", ""))
                        editor.putString(
                            "titular_${slot}_fuente",
                            item.optJSONObject("source")?.optString("name", "") ?: "",
                        )
                        editor.putString("titular_${slot}_id", item.optInt("id").toString())
                        editor.putString("titular_${slot}_imagen", item.optString("media_url", ""))
                    } else {
                        editor.putString("titular_${slot}_titulo", "")
                        editor.putString("titular_${slot}_fuente", "")
                        editor.putString("titular_${slot}_id", "")
                        editor.putString("titular_${slot}_imagen", "")
                    }
                }
                editor.apply()
            } catch (e: Exception) {
                errorMensaje = e.message ?: "error desconocido"
                Log.w("TitularesWidget", "refresh fallo: $errorMensaje")
            } finally {
                widgetPrefs.edit()
                    .putBoolean("titulares_actualizando", false)
                    .putString("titulares_ultimo_error", errorMensaje ?: "")
                    .apply()
                if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
            }
        }.start()
    }

    /**
     * Snapshot de los filtros transversales (topics + override de
     * territorio + override de idiomas) que el usuario haya fijado en
     * cualquier pestaña de la app. Se serializan a JSON en
     * `filtros_transversales.dart` bajo la clave `fnh.filters.global`.
     */
    private data class FiltrosTransversales(
        val slugsTopics: List<String>,
        val territorioOverride: String?,
        val idiomasOverride: List<String>,
    )

    /**
     * Réplica en Kotlin del estado de `filtrosTransversalesProvider`.
     * Lee el JSON persistido y devuelve los tres campos que el widget
     * sabe aplicar al query del backend. Si la preferencia no existe o
     * está corrupta devuelve filtros vacíos — equivalente a "el usuario
     * no ha tocado ningún filtro".
     */
    private fun leerFiltrosTransversales(
        prefs: android.content.SharedPreferences
    ): FiltrosTransversales {
        val crudo = prefs.getString("flutter.fnh.filters.global", null)
        if (crudo.isNullOrBlank()) {
            return FiltrosTransversales(emptyList(), null, emptyList())
        }
        return try {
            val raiz = JSONObject(crudo)
            val arraySlugs = raiz.optJSONArray("slugsTopics")
            val slugs = if (arraySlugs == null) emptyList() else
                (0 until arraySlugs.length()).mapNotNull { i ->
                    arraySlugs.optString(i, "").takeIf { it.isNotBlank() }
                }
            val territorio = raiz.optString("codigoTerritorio", "")
                .takeIf { it.isNotBlank() }
            val arrayIdiomas = raiz.optJSONArray("codigosIdiomasOverride")
            val idiomas = if (arrayIdiomas == null) emptyList() else
                (0 until arrayIdiomas.length()).mapNotNull { i ->
                    arrayIdiomas.optString(i, "").takeIf { it.isNotBlank() }
                }
            FiltrosTransversales(slugs, territorio, idiomas)
        } catch (_: Exception) {
            // JSON corrupto — degradamos a filtros vacíos en vez de
            // hacer crashear el refresh entero.
            FiltrosTransversales(emptyList(), null, emptyList())
        }
    }

    /**
     * Réplica en Kotlin de `idiomasContenidoEfectivosProvider`. Lee la
     * preferencia JSON `politicaIdiomaContenido` (escrita desde
     * Flutter en `politica_idioma_contenido.dart`) y devuelve la
     * lista de idiomas que el widget debe pasar como `language=`.
     *
     *   - `desactivado` → lista vacía (sin filtro de idioma).
     *   - `manual` → idiomas manuales fijados.
     *   - `seguirInterfaz` (o ausencia de preferencia) → idioma de UI
     *     o, en su defecto, locale del sistema. Restringido al set
     *     soportado del backend para evitar enviar `de`/`it` cuando
     *     no hay catálogo en esos idiomas.
     */
    private fun leerIdiomasContenidoEfectivos(
        prefs: android.content.SharedPreferences
    ): List<String> {
        val soportados = setOf("es", "ca", "eu", "gl", "en", "pt", "fr")
        val politicaJson = prefs.getString("flutter.fnh.pref.politicaIdiomaContenido", null)
        var modo = "seguirInterfaz"
        var manuales: List<String> = emptyList()
        if (!politicaJson.isNullOrBlank()) {
            try {
                val raiz = JSONObject(politicaJson)
                modo = raiz.optString("modo", modo)
                val arrayManuales = raiz.optJSONArray("idiomas_manuales")
                if (arrayManuales != null) {
                    val acumulado = mutableListOf<String>()
                    for (i in 0 until arrayManuales.length()) {
                        val codigo = arrayManuales.optString(i, "")
                        if (codigo.isNotBlank() && soportados.contains(codigo)) {
                            acumulado.add(codigo)
                        }
                    }
                    manuales = acumulado
                }
            } catch (_: Exception) {
                // Política corrupta — degradamos a default seguirInterfaz.
            }
        }
        return when (modo) {
            "desactivado" -> emptyList()
            "manual" -> manuales
            else -> {
                val idiomaUi = prefs.getString("flutter.fnh.pref.localeCode", null)
                val codigoEfectivo = idiomaUi?.takeIf { it.isNotBlank() && soportados.contains(it) }
                    ?: java.util.Locale.getDefault().language.lowercase()
                if (soportados.contains(codigoEfectivo)) listOf(codigoEfectivo) else emptyList()
            }
        }
    }
}
