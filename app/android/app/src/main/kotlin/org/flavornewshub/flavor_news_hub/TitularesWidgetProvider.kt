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
import org.json.JSONArray
import org.json.JSONObject

/**
 * Widget de pantalla de inicio que pinta los 3 titulares más recientes
 * guardados por la app. Flutter escribe con `HomeWidget.saveWidgetData`
 * las claves `titular_1_*` / `titular_2_*` / `titular_3_*` — aquí las
 * leemos y las inyectamos en el RemoteViews.
 *
 * Tap en un titular → abre la app en la URL del detalle (deep link
 * `flavornews://items/<id>`). Tap en el botón refrescar → abre la app
 * normal; la app refrescará el feed al arrancar.
 */
class TitularesWidgetProvider : AppWidgetProvider() {

    companion object {
        /** Broadcast propio que dispara el tap al icono de refrescar. */
        const val ACCION_REFRESCAR = "org.flavornewshub.flavor_news_hub.WIDGET_REFRESCAR"
    }

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.titulares_widget)
        val prefs = HomeWidgetPlugin.getData(context)

        var algunoPintado = false
        for (i in 1..3) {
            val titulo = prefs.getString("titular_${i}_titulo", null)
            val fuente = prefs.getString("titular_${i}_fuente", null)
            val idItem = prefs.getString("titular_${i}_id", null)

            val idTxt = when (i) {
                1 -> R.id.titular_1; 2 -> R.id.titular_2; else -> R.id.titular_3
            }
            val idFuente = when (i) {
                1 -> R.id.titular_1_fuente; 2 -> R.id.titular_2_fuente; else -> R.id.titular_3_fuente
            }
            if (!titulo.isNullOrEmpty()) {
                algunoPintado = true
                views.setTextViewText(idTxt, titulo)
                views.setTextViewText(idFuente, fuente ?: "")
                // Deep link al detalle si hay id. Usamos PendingIntent
                // directo con ACTION_VIEW en vez de HomeWidgetBackground-
                // Intent porque éste requiere un callback Dart registrado
                // y arranca un Service que el user no necesita.
                // requestCode distinto por item (widgetId*10+i) — si
                // todos compartieran 0, Android actualiza el primero y
                // los demás se pierden.
                if (!idItem.isNullOrEmpty()) {
                    val deepLink = Uri.parse("flavornews://items/$idItem")
                    val intent = Intent(Intent.ACTION_VIEW, deepLink).apply {
                        setPackage(context.packageName)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    val pending = PendingIntent.getActivity(
                        context,
                        widgetId * 10 + i,
                        intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                    views.setOnClickPendingIntent(idTxt, pending)
                    views.setOnClickPendingIntent(idFuente, pending)
                } else {
                    // Sin id (p. ej. items personales): el slot es
                    // visible pero no navegable. Limpiamos cualquier
                    // PendingIntent previo que tuviera asignado.
                    views.setOnClickPendingIntent(idTxt, null)
                    views.setOnClickPendingIntent(idFuente, null)
                }
            } else {
                views.setTextViewText(idTxt, "")
                views.setTextViewText(idFuente, "")
                // Slot vacío: limpiamos el click para que un PendingIntent
                // de un titular anterior (cacheado por Android) no siga
                // abriendo esa noticia fantasma al tocar zona vacía.
                views.setOnClickPendingIntent(idTxt, null)
                views.setOnClickPendingIntent(idFuente, null)
            }
        }

        // Estado visual del refresh:
        //  - actualizando=true      → "Actualizando…"
        //  - error no vacío         → "No se pudo actualizar: <error>"
        //  - ningún titular pintado → mensaje estándar "no hay titulares"
        val actualizando = prefs.getBoolean("titulares_actualizando", false)
        val ultimoError = prefs.getString("titulares_ultimo_error", "") ?: ""
        val textoEstado = when {
            actualizando -> context.getString(R.string.widget_titulares_actualizando)
            !algunoPintado -> context.getString(R.string.widget_titulares_vacio)
            ultimoError.isNotEmpty() -> context.getString(
                R.string.widget_titulares_error, ultimoError
            )
            else -> ""
        }
        if (textoEstado.isNotEmpty()) {
            views.setTextViewText(R.id.widget_vacio, textoEstado)
            views.setViewVisibility(R.id.widget_vacio, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_vacio, View.GONE)
        }

        // Tap refrescar → broadcast a nosotros mismos (sin abrir la app).
        // `onReceive` detecta la acción y hace una petición HTTP directa
        // al backend en un thread Kotlin. Si el backend no responde, no
        // pasa nada visible (las radios/sources/seed RSS de Dart no se
        // ejercitan aquí — es un refresh de "lo que ve el backend ahora").
        val intentRefrescar = Intent(context, TitularesWidgetProvider::class.java).apply {
            action = ACCION_REFRESCAR
        }
        val pendingRefrescar = PendingIntent.getBroadcast(
            context, widgetId * 10 + 9, intentRefrescar,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_refrescar, pendingRefrescar)

        val intentAbrir = Intent(context, MainActivity::class.java)
        val pendingAbrir = PendingIntent.getActivity(
            context, 0, intentAbrir,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.widget_titulo, pendingAbrir)

        TemaWidget.aplicar(
            context,
            views,
            idFondo = R.id.widget_root,
            idsTextoPrincipal = listOf(
                R.id.widget_titulo,
                R.id.titular_1, R.id.titular_2, R.id.titular_3,
            ),
            idsTextoSecundario = listOf(
                R.id.titular_1_fuente, R.id.titular_2_fuente, R.id.titular_3_fuente,
                R.id.widget_vacio,
            ),
        )

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /**
     * Permite a Flutter forzar un redraw: `HomeWidget.updateWidget(...)`
     * envía un broadcast que cae aquí y reejecuta `onUpdate`. El plugin
     * home_widget no usa exactamente `ACTION_APPWIDGET_UPDATE` sino su
     * propia acción, así que aceptamos cualquier broadcast dirigido a
     * nuestro provider y forzamos re-render.
     */
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
        appWidgetIds: IntArray
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
                // Traemos más items (20) que slots (3) para poder filtrar
                // localmente por fuentes bloqueadas sin quedarnos cortos.
                val url = URL("$base/items?per_page=20&exclude_source_type=video,youtube,podcast")
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

                val filtrados = mutableListOf<JSONObject>()
                for (i in 0 until items.length()) {
                    val it = items.getJSONObject(i)
                    val idSrc = it.optJSONObject("source")?.optInt("id") ?: 0
                    if (idSrc > 0 && bloqueadas.contains(idSrc)) continue
                    filtrados.add(it)
                    if (filtrados.size >= 3) break
                }

                val editor = widgetPrefs.edit()
                for (i in 0 until 3) {
                    val slot = i + 1
                    if (i < filtrados.size) {
                        val item = filtrados[i]
                        editor.putString("titular_${slot}_titulo", item.optString("title", ""))
                        editor.putString(
                            "titular_${slot}_fuente",
                            item.optJSONObject("source")?.optString("name", "") ?: "",
                        )
                        editor.putString("titular_${slot}_id", item.optInt("id").toString())
                    } else {
                        editor.putString("titular_${slot}_titulo", "")
                        editor.putString("titular_${slot}_fuente", "")
                        editor.putString("titular_${slot}_id", "")
                    }
                }
                editor.apply()
            } catch (e: Exception) {
                errorMensaje = e.message ?: "error desconocido"
                Log.w("TitularesWidget", "refresh fallo: $errorMensaje")
            } finally {
                // Apagar flag "actualizando" y guardar último error (si
                // hubo) para que el widget pueda pintar un indicador
                // discreto sin sustituir el contenido anterior.
                widgetPrefs.edit()
                    .putBoolean("titulares_actualizando", false)
                    .putString("titulares_ultimo_error", errorMensaje ?: "")
                    .apply()
                if (ids.isNotEmpty()) onUpdate(context, mgr, ids)
            }
        }.start()
    }
}
