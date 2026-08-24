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
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import org.json.JSONArray
import org.json.JSONObject

/**
 * Base común de los widgets que pintan una lista de items del backend
 * (titulares, vídeos, podcasts). Extraída de `TitularesWidgetProvider`
 * en v0.10.x cuando aparecieron el segundo y tercer widget de lista:
 * los tres comparten toda la fontanería (adaptador remoto sobre un
 * `RemoteViewsService`, estado actualizando/error, spinner, tema,
 * refresco HTTP directo) y sólo se diferencian en:
 *
 *   - las claves de SharedPreferences donde guardan su lista,
 *   - el filtro `source_type` que mandan al backend,
 *   - el layout y los textos de cabecera/vacío.
 *
 * La fuente de datos sigue siendo el almacén de `home_widget`
 * (SharedPreferences), escrito por la app Flutter y/o por el refresco
 * del propio widget. Tap en una fila → deep link
 * `flavornews://items/<id>`, vía `setPendingIntentTemplate` aquí +
 * `setOnClickFillInIntent` en la factory.
 *
 * Los layouts de los tres widgets reutilizan los MISMOS ids
 * (`widget_root`, `widget_titulo`, `widget_refrescar`, `items_lista`,
 * `widget_vacio`) para que este código no necesite parametrizarlos.
 */
abstract class ProveedorWidgetItemsBase : AppWidgetProvider() {

    /** Tag para logcat, propio de cada widget concreto. */
    protected abstract val etiquetaLog: String

    /** Broadcast propio que dispara el tap al icono de refrescar. */
    protected abstract val accionRefrescar: String

    /**
     * Prefijo de las claves por slot en las prefs del widget:
     * `<prefijo>_{1..10}_{titulo,fuente,id,imagen}`.
     */
    protected abstract val prefijoClaveItem: String

    /**
     * Prefijo de las claves de estado: `<prefijo>_actualizando`,
     * `<prefijo>_ultimo_error`, `<prefijo>_ultimo_refresco`.
     */
    protected abstract val prefijoClaveEstado: String

    /** Layout raíz del widget. */
    protected abstract val layoutWidget: Int

    /** Service que provee las filas del ListView. */
    protected abstract val servicioFilas: Class<out RemoteViewsService>

    /**
     * Autoridad del URI único que identifica el adaptador remoto
     * (p. ej. `titulares` → `widget://titulares/<widgetId>`).
     */
    protected abstract val autoridadAdaptador: String

    /**
     * Query string con el filtro de tipo de fuente que este widget
     * manda al backend, ya montada (p. ej.
     * `exclude_source_type=video,youtube,podcast` o
     * `source_type=podcast`).
     */
    protected abstract val filtroTipoFuente: String

    /**
     * Deep link que abre la sección de la app correspondiente a este
     * widget al tocar su cabecera (p. ej. `flavornews://videos`). Sin
     * esto el tap abriría la app por su pantalla de inicio, que para
     * un widget de vídeos o podcasts no es donde el usuario quiere ir.
     */
    protected abstract val uriCabecera: String

    /**
     * Tope de items del mismo medio en la lista, para que un canal que
     * publica en ráfaga no acapare los 10 slots. `null` = sin tope.
     *
     * Titulares no lo necesita (el feed mezcla muchísimos medios), pero
     * en podcasts y vídeos, donde publican pocas fuentes y a menudo
     * varios episodios seguidos, sin esto el widget acababa enseñando
     * un solo canal.
     */
    protected open val maximoPorFuente: Int? = null

    /**
     * Items que pedimos al backend. Con tope por fuente hace falta un
     * margen mayor: descartamos parte de lo que llega.
     *
     * Tope duro de 50: el endpoint `/items` rechaza con HTTP 400
     * cualquier `per_page` mayor, y el refresco entero se perdía
     * dejando en pantalla los datos de la vez anterior.
     */
    private val elementosPorPagina: Int
        get() = if (maximoPorFuente == null) 20 else 50

    /** Texto de cabecera; también usado como fallback del empty view. */
    protected abstract val stringCabecera: Int
    protected abstract val stringVacio: Int
    protected abstract val stringActualizando: Int
    protected abstract val stringError: Int

    /**
     * Minutos tras los cuales `onUpdate` vuelve a pedir datos al backend
     * por su cuenta. `null` = nunca (el widget depende de que la app
     * escriba los datos, como hace Titulares desde `FeedNotifier`).
     *
     * Vídeos y podcasts sí lo usan: sus listas no se escriben en cada
     * carga del feed, así que sin esto un widget recién colocado se
     * quedaría vacío hasta que el usuario tocara ↻.
     */
    protected open val minutosAutoRefresco: Int? = null

    protected companion object {
        /** Slots que se mantienen en las prefs (y tope de la lista). */
        const val MAXIMO_SLOTS = 10
    }

    private fun clavesEstado() = Triple(
        "${prefijoClaveEstado}_actualizando",
        "${prefijoClaveEstado}_ultimo_error",
        "${prefijoClaveEstado}_ultimo_refresco",
    )

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, layoutWidget)

        // Adaptador remoto del ListView. `setData` con un URI único por
        // widget — sin esto, cuando hay varios widgets del mismo tipo el
        // sistema reutiliza la factory y los datos de uno se cuelan en
        // el otro.
        val intentAdaptador = Intent(context, servicioFilas).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("widget://$autoridadAdaptador/$widgetId")
        }
        views.setRemoteAdapter(R.id.items_lista, intentAdaptador)
        views.setEmptyView(R.id.items_lista, R.id.widget_vacio)

        // PendingIntent template — el sistema lo combina con el
        // `fillInIntent` que la factory pone en cada fila para abrir el
        // detalle del item pulsado.
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
        // fila. Los templates de RemoteViews exigen mutabilidad.
        val pendingTemplate = PendingIntent.getActivity(
            context, widgetId * 10 + 8, intentTemplate,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setPendingIntentTemplate(R.id.items_lista, pendingTemplate)

        // Estado del refresh. Para no inflar el layout, el empty view
        // hace de mensajero: enseña "actualizando" o el error cuando la
        // lista está vacía. Con items, el ListView gana visibilidad y el
        // empty view se oculta automáticamente.
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        val recursos = IdiomaWidget.recursos(context)
        val (claveActualizando, claveUltimoError, _) = clavesEstado()
        val actualizando = widgetPrefs.getBoolean(claveActualizando, false)
        val ultimoError = widgetPrefs.getString(claveUltimoError, "") ?: ""
        val textoEmpty = when {
            actualizando -> recursos.getString(stringActualizando)
            ultimoError.isNotEmpty() -> recursos.getString(stringError, ultimoError)
            else -> recursos.getString(stringVacio)
        }
        views.setTextViewText(R.id.widget_vacio, textoEmpty)
        views.setTextViewText(R.id.widget_titulo, recursos.getString(stringCabecera))

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
        val intentRefrescar = Intent(context, javaClass).apply {
            action = accionRefrescar
        }
        val pendingRefrescar = PendingIntent.getBroadcast(
            context, widgetId * 10 + 9, intentRefrescar,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_refrescar, pendingRefrescar)

        // Tap en la cabecera abre la sección de la app de este widget
        // (feed, vídeos o podcasts) vía deep link `flavornews://…`, que
        // procesa `DeepLinkListener` en Flutter. Cada widget necesita su
        // propio `requestCode`; con uno compartido, el PendingIntent del
        // primero se reutilizaba para todos.
        val intentAbrir = Intent(Intent.ACTION_VIEW, Uri.parse(uriCabecera)).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pendingAbrir = PendingIntent.getActivity(
            context, widgetId * 10 + 7, intentAbrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_titulo, pendingAbrir)

        val temaOscuro = TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(R.id.widget_titulo),
            idsTextoSecundario = listOf(R.id.widget_vacio),
        )
        // Compartimos con la factory del ListView el modo detectado aquí
        // (con el `context` del broadcast, fiable). Debe escribirse ANTES
        // del notify para que `onDataSetChanged` lea el valor fresco; si
        // no, la factory caía en su `applicationContext` y pintaba texto
        // negro sobre el fondo oscuro.
        widgetPrefs.edit().putBoolean(TemaWidget.CLAVE_TEMA_OSCURO, temaOscuro).apply()

        appWidgetManager.updateAppWidget(widgetId, views)
        // Notificar a la factory que sus datos pueden haber cambiado —
        // sin esto el ListView no recarga aunque cambien las prefs.
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.items_lista)
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(etiquetaLog, "onReceive action=${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == accionRefrescar) {
            refrescarDesdeBackend(context)
            return
        }
        // ACTION_APPWIDGET_UPDATE ya lo enruta `super.onReceive` a
        // `onUpdate`; repetirlo aquí pintaba todo dos veces y la factory
        // re-descargaba las miniaturas dos veces por ciclo. El onUpdate
        // manual queda sólo para broadcasts sin ruta propia (cambio de
        // idioma/tema) que necesitan repintar.
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) return
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, javaClass))
        if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Primer widget colocado: si el widget se autoabastece, pedimos
        // datos ya para que no aparezca vacío en el home.
        if (minutosAutoRefresco != null) refrescarDesdeBackend(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(etiquetaLog, "onUpdate widgets=${appWidgetIds.size}")
        for (widgetId in appWidgetIds) {
            actualizarUno(context, appWidgetManager, widgetId)
        }
        if (appWidgetIds.isNotEmpty() && tocaRefrescoAutomatico(context)) {
            refrescarDesdeBackend(context)
        }
    }

    /**
     * ¿Corresponde pedir datos al backend en este `onUpdate`? Sólo para
     * los widgets con `minutosAutoRefresco` definido, y sólo si no hay
     * ya un refresco en vuelo y el último quedó lejos (o nunca hubo).
     *
     * El sello de tiempo se escribe al ARRANCAR el refresco, no al
     * acabar: así el `onUpdate` que dispara el propio refresco (para
     * pintar el spinner) no vuelve a entrar aquí en bucle.
     */
    private fun tocaRefrescoAutomatico(context: Context): Boolean {
        val minutos = minutosAutoRefresco ?: return false
        val prefs = HomeWidgetPlugin.getData(context)
        val (claveActualizando, _, claveUltimoRefresco) = clavesEstado()
        if (prefs.getBoolean(claveActualizando, false)) return false
        val ultimoRefresco = prefs.getLong(claveUltimoRefresco, 0L)
        val transcurrido = System.currentTimeMillis() - ultimoRefresco
        return transcurrido > minutos * 60_000L
    }

    /**
     * Petición HTTP directa al backend (en un Thread, no el main) para
     * traer los items más recientes del tipo de este widget y
     * escribirlos en el almacén sin abrir la app. Aplica los mismos
     * filtros que el feed in-app (fuentes bloqueadas, territorio,
     * idiomas de contenido) para que lo que ve el usuario en el widget
     * coincida con lo que vería dentro.
     *
     * Antes de llamar pintamos un estado "actualizando"; al terminar
     * (OK o error) lo repintamos con el dato final.
     */
    private fun refrescarDesdeBackend(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, javaClass))
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        val (claveActualizando, claveUltimoError, claveUltimoRefresco) = clavesEstado()
        // Marcar estado "actualizando" + sellar el intento antes de
        // empezar (ver `tocaRefrescoAutomatico`).
        widgetPrefs.edit()
            .putBoolean(claveActualizando, true)
            .putLong(claveUltimoRefresco, System.currentTimeMillis())
            .apply()
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
                val parametros = StringBuilder("per_page=$elementosPorPagina&$filtroTipoFuente")
                val territorioBase = prefs.getString("flutter.fnh.pref.territorioBase", "") ?: ""
                if (territorioBase.isNotBlank()) {
                    parametros.append("&territory=")
                        .append(URLEncoder.encode(territorioBase, "UTF-8"))
                }
                val idiomasContenido = leerIdiomasContenidoEfectivos(prefs)
                if (idiomasContenido.isNotEmpty()) {
                    parametros.append("&language=").append(
                        URLEncoder.encode(idiomasContenido.joinToString(","), "UTF-8")
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
                // enseñe items de medios que el usuario silenció.
                val bloqueadasRaw = prefs.getStringSet(
                    "flutter.fnh.pref.fuentesBloqueadas", emptySet()
                ) ?: emptySet()
                val bloqueadas: Set<Int> = bloqueadasRaw.mapNotNull { it.toIntOrNull() }.toSet()

                val admitidos = mutableListOf<JSONObject>()
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val idFuente = item.optJSONObject("source")?.optInt("id") ?: 0
                    if (idFuente > 0 && bloqueadas.contains(idFuente)) continue
                    admitidos.add(item)
                }
                val filtrados = repartirEntreFuentes(admitidos)

                val editor = widgetPrefs.edit()
                for (i in 0 until MAXIMO_SLOTS) {
                    val slot = i + 1
                    if (i < filtrados.size) {
                        val item = filtrados[i]
                        editor.putString(
                            "${prefijoClaveItem}_${slot}_titulo",
                            item.optString("title", ""),
                        )
                        editor.putString(
                            "${prefijoClaveItem}_${slot}_fuente",
                            item.optJSONObject("source")?.optString("name", "") ?: "",
                        )
                        editor.putString(
                            "${prefijoClaveItem}_${slot}_id",
                            item.optInt("id").toString(),
                        )
                        editor.putString(
                            "${prefijoClaveItem}_${slot}_imagen",
                            item.optString("media_url", ""),
                        )
                    } else {
                        editor.putString("${prefijoClaveItem}_${slot}_titulo", "")
                        editor.putString("${prefijoClaveItem}_${slot}_fuente", "")
                        editor.putString("${prefijoClaveItem}_${slot}_id", "")
                        editor.putString("${prefijoClaveItem}_${slot}_imagen", "")
                    }
                }
                editor.apply()
            } catch (e: Exception) {
                errorMensaje = e.message ?: "error desconocido"
                Log.w(etiquetaLog, "refresh fallo: $errorMensaje")
            } finally {
                widgetPrefs.edit()
                    .putBoolean(claveActualizando, false)
                    .putString(claveUltimoError, errorMensaje ?: "")
                    .apply()
                if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
            }
        }.start()
    }

    /**
     * Recorta la lista a los slots del widget respetando
     * [maximoPorFuente]: primero una pasada quedándose con los N
     * primeros de cada medio (el backend ya viene ordenado por fecha,
     * así que "primeros" = más recientes), y si con eso no se llenan
     * los slots, una segunda pasada rellenando con los descartados en
     * el mismo orden — mejor un widget lleno con repeticiones que uno
     * a medias cuando sólo hay dos o tres fuentes con episodios.
     */
    private fun repartirEntreFuentes(admitidos: List<JSONObject>): List<JSONObject> {
        val tope = maximoPorFuente ?: return admitidos.take(MAXIMO_SLOTS)
        val seleccionados = mutableListOf<JSONObject>()
        val sobrantes = mutableListOf<JSONObject>()
        val cuentaPorFuente = mutableMapOf<Int, Int>()
        for (item in admitidos) {
            val idFuente = item.optJSONObject("source")?.optInt("id") ?: 0
            val yaPuestos = cuentaPorFuente.getOrDefault(idFuente, 0)
            if (yaPuestos >= tope) {
                sobrantes.add(item)
                continue
            }
            cuentaPorFuente[idFuente] = yaPuestos + 1
            seleccionados.add(item)
            if (seleccionados.size >= MAXIMO_SLOTS) return seleccionados
        }
        for (item in sobrantes) {
            if (seleccionados.size >= MAXIMO_SLOTS) break
            seleccionados.add(item)
        }
        return seleccionados
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
