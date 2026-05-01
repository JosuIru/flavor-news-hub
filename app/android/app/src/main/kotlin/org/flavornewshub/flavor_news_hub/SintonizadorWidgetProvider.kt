package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import kotlin.random.Random

/**
 * Widget "Sintonizador" — radio antigua de madera con cuatro botones
 * (◄ anterior · ■ stop · ▶ play · ► siguiente). El índice de emisora
 * actual vive en SharedPreferences del propio widget.
 *
 * ◄ / ► disparan broadcast al propio provider → cambia el índice y
 * redibuja. Si hay reproducción activa, además relanza el play con la
 * nueva emisora.
 *
 * ▶ / ■ usan `RadioService` (servicio Android nativo foreground tipo
 * mediaPlayback). El servicio reproduce el stream con `MediaPlayer`
 * directamente — sin pasar por Flutter — y vive indefinidamente
 * mientras la radio suene. Antes usábamos un callback Dart en isolate
 * background (`HomeWidgetBackgroundIntent`) y `just_audio_background`,
 * pero el `JobService` que aloja al callback tiene tiempo limitado y
 * Android terminaba matando el `FlutterEngine` background → el audio
 * se cortaba al rato sin razón aparente.
 *
 * Tap en el dial abre la app en /audio (deep link clásico — para "ver
 * más" de la emisora).
 *
 * Flutter empuja la lista de radios activas como JSON en la clave
 * `sintonizador_radios` (`WidgetSintonizadorWriter`).
 */
class SintonizadorWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACCION_ANTERIOR = "org.flavornewshub.flavor_news_hub.SINTONIZADOR_ANTERIOR"
        const val ACCION_SIGUIENTE = "org.flavornewshub.flavor_news_hub.SINTONIZADOR_SIGUIENTE"
        const val CLAVE_INDICE = "sintonizador_indice_actual"
        const val CLAVE_RADIOS = "sintonizador_radios"
        const val CLAVE_REPRODUCIENDO = "sintonizador_reproduciendo_id"
        const val CLAVE_ESTADO = "sintonizador_estado"
        // StreamTitle ICY actual (lo escribe RadioService cuando recibe
        // metadatos del servidor Icecast/Shoutcast). Vacío si la emisora
        // no expone metadatos o todavía no han llegado.
        const val CLAVE_PROGRAMA = "sintonizador_programa"
        // "app" → reproduce el AudioPlayer principal (just_audio_background).
        // "servicio" → reproduce RadioService nativo del widget.
        // "" → nada sonando.
        const val CLAVE_FUENTE = "sintonizador_fuente"
        const val FUENTE_APP = "app"
        const val FUENTE_SERVICIO = "servicio"
        const val NUM_LEDS = 10
        const val LARGO_VU = 9

        // Paleta del dial: dos estados (apagado / encendido) — los aplica
        // el provider con setTextColor en runtime. Tonos elegidos para que
        // el estado apagado destaque sobre el fondo de madera oscura
        // (#2a1a08 aprox.) sin competir con el ámbar/rojo encendidos.
        private const val COLOR_LEDS_APAGADOS = 0xFFB58850.toInt()
        private const val COLOR_LEDS_ENCENDIDOS = 0xFFFFC870.toInt()
        private const val COLOR_AGUJA_APAGADA = 0xFFB54040.toInt()
        private const val COLOR_AGUJA_ENCENDIDA = 0xFFFF4040.toInt()

        // Glifos para el botón ▶: cambia a `…` mientras carga el stream y
        // a `⏸` cuando ya está sonando — pulsarlo entonces detiene la
        // reproducción (toggle play/pause). Sin esto el botón siempre
        // mostraba `▶` aunque la radio estuviera sonando, dando la
        // impresión de que el widget no había registrado la pulsación.
        private const val GLIFO_PLAY = "▶"
        private const val GLIFO_CARGANDO = "…"
        private const val GLIFO_PAUSA = "⏸"

        // Bloques Unicode para el VU falso. Mezcla picos altos y bajos
        // en cada redibujado para que parezca señal viva — no hay
        // animación porque RemoteViews no la permite, sólo re-pintado.
        private val BARRAS_VU = charArrayOf('▁', '▂', '▃', '▄', '▅', '▆', '▇')
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACCION_ANTERIOR -> ajustarIndice(context, delta = -1)
            ACCION_SIGUIENTE -> ajustarIndice(context, delta = +1)
        }
    }

    data class Radio(val id: Int, val nombre: String, val territorio: String, val streamUrl: String)

    private fun obtenerRadios(context: Context): List<Radio> {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(CLAVE_RADIOS, "[]") ?: "[]"
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Radio(
                    id = o.optInt("id", 0),
                    nombre = o.optString("name", ""),
                    territorio = o.optString("territory", ""),
                    streamUrl = o.optString("stream_url", ""),
                )
            }.filter { it.id > 0 && it.nombre.isNotEmpty() }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun ajustarIndice(context: Context, delta: Int) {
        val radios = obtenerRadios(context)
        if (radios.isEmpty()) return
        val prefs = HomeWidgetPlugin.getData(context)
        val indiceActual = prefs.getInt(CLAVE_INDICE, 0).coerceIn(0, radios.size - 1)
        val indiceNuevo = ((indiceActual + delta) % radios.size + radios.size) % radios.size
        prefs.edit().putInt(CLAVE_INDICE, indiceNuevo).apply()

        // Si hay reproducción activa, ◄/► funciona como "cambiar de
        // emisora en directo". Cómo cambiar depende de quién está
        // reproduciendo (la app principal o nuestro servicio nativo) —
        // si delegáramos siempre al servicio cuando el dueño es la
        // app, dispararíamos un segundo stream paralelo al que ya
        // suena en just_audio_background.
        val reproduciendoId = prefs.getString(CLAVE_REPRODUCIENDO, "") ?: ""
        if (reproduciendoId.isNotEmpty()) {
            val radioNueva = radios[indiceNuevo]
            val fuenteActual = prefs.getString(CLAVE_FUENTE, "") ?: ""
            if (fuenteActual == FUENTE_APP) {
                // La fuente original era la app (just_audio_background).
                // Antes hacíamos un deep link a `flavornews://radios/play/$id`
                // confiando en que la activity estaría abierta y el
                // intent pasaría por `onNewIntent`. Pero just_audio_background
                // mantiene el playback con la activity destruida (caso
                // típico: escuchas con la pantalla bloqueada), y entonces
                // `startActivity` traía la app al frente — exactamente
                // lo contrario de lo que se espera de "siguiente radio
                // en el widget".
                //
                // En su lugar, transferimos el playback al `RadioService`
                // nativo del widget: paramos lo que esté sonando en
                // cualquier MediaSession (KEYCODE_MEDIA_STOP) y arrancamos
                // el servicio con la nueva URL. La próxima pulsación ya
                // verá `CLAVE_FUENTE = FUENTE_SERVICIO` y caerá por la
                // rama directa.
                pararPlaybackEnApp(context)
            }
            iniciarServicioPlay(context, radioNueva)
        }

        // Forzar redibujado inmediato del widget.
        val gestorWidget = AppWidgetManager.getInstance(context)
        val idsWidgets = gestorWidget.getAppWidgetIds(
            ComponentName(context, SintonizadorWidgetProvider::class.java)
        )
        if (idsWidgets.isNotEmpty()) onUpdate(context, gestorWidget, idsWidgets)
    }

    /**
     * Lanza un Intent al `RadioService` para que reproduzca la emisora
     * indicada. Usa `startForegroundService` desde Android O en adelante
     * (requisito del sistema; el servicio tiene 5 s para llamar
     * `startForeground` o se mata).
     */
    private fun iniciarServicioPlay(context: Context, radio: Radio) {
        val intent = Intent(context, RadioService::class.java).apply {
            action = RadioService.ACCION_PLAY
            putExtra(RadioService.EXTRA_URL, radio.streamUrl)
            putExtra(RadioService.EXTRA_TITULO, radio.nombre)
            putExtra(RadioService.EXTRA_ID_RADIO, radio.id.toString())
        }
        ContextCompat.startForegroundService(context, intent)
    }

    /**
     * Manda KEYCODE_MEDIA_STOP al MediaSession activo (gestionado por
     * audio_service / just_audio_background dentro de la app). Si la
     * sesión existe, para el playback. Si no, el broadcast es no-op.
     *
     * Lo usamos al cambiar de emisora con ◄/► cuando la fuente actual
     * es `FUENTE_APP`: paramos lo de la app antes de arrancar el
     * RadioService nativo, para no tener dos streams sonando en paralelo.
     */
    private fun pararPlaybackEnApp(context: Context) {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP),
            )
        }
        try {
            context.sendBroadcast(intent)
        } catch (_: Exception) {
            // Best effort: si por algún motivo el broadcast no llega, el
            // RadioService nativo arrancará igualmente con la nueva URL.
            // Lo único que se rompería es la transición limpia (puede
            // haber un breve solapamiento entre las dos fuentes).
        }
    }

    private fun actualizarUno(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.sintonizador_widget)
        val radios = obtenerRadios(context)
        val prefs = HomeWidgetPlugin.getData(context)

        if (radios.isEmpty()) {
            views.setTextViewText(R.id.sintonizador_nombre, IdiomaWidget.recursos(context).getString(R.string.widget_sintonizador_sin_radios))
            views.setTextViewText(R.id.sintonizador_territorio, "")
            views.setTextViewText(R.id.sintonizador_leds, repetirCompat("· ", NUM_LEDS).trim())
            views.setTextViewText(R.id.sintonizador_aguja, "")
            views.setTextColor(R.id.sintonizador_leds, COLOR_LEDS_APAGADOS)
            views.setTextColor(R.id.sintonizador_aguja, COLOR_AGUJA_APAGADA)
            views.setViewVisibility(R.id.sintonizador_cargando, View.GONE)
            views.setViewVisibility(R.id.sintonizador_vu, View.GONE)
            views.setViewVisibility(R.id.sintonizador_programa, View.GONE)
            views.setTextViewText(R.id.sintonizador_btn_play, GLIFO_PLAY)
            appWidgetManager.updateAppWidget(widgetId, views)
            return
        }

        val indice = prefs.getInt(CLAVE_INDICE, 0).coerceIn(0, radios.size - 1)
        val radio = radios[indice]
        val idRadio = radio.id
        // Estado del playback (lo escribe el RadioService al cambiar).
        // Tres valores:
        //   "cargando"     → buffereando; barra de progreso visible,
        //                     botón ▶ → `…`, dial todavía apagado.
        //   "reproduciendo"→ stream sonando; LEDs ámbar, VU falso visible.
        //   ""             → parado; todo apagado, botón ▶ normal.
        val estado = prefs.getString(CLAVE_ESTADO, "") ?: ""
        val sonando = estado == "reproduciendo"
        val cargando = estado == "cargando"
        val posicionLed = if (radios.size <= 1) 0
            else (indice.toDouble() * (NUM_LEDS - 1) / (radios.size - 1)).toInt()
        views.setTextViewText(R.id.sintonizador_nombre, radio.nombre)
        views.setTextViewText(R.id.sintonizador_territorio, radio.territorio.ifEmpty { "·" })
        views.setTextViewText(R.id.sintonizador_leds, construirLeds(posicionLed))
        views.setTextViewText(R.id.sintonizador_aguja, construirAguja(posicionLed))
        views.setTextColor(
            R.id.sintonizador_leds,
            if (sonando) COLOR_LEDS_ENCENDIDOS else COLOR_LEDS_APAGADOS,
        )
        views.setTextColor(
            R.id.sintonizador_aguja,
            if (sonando) COLOR_AGUJA_ENCENDIDA else COLOR_AGUJA_APAGADA,
        )
        views.setViewVisibility(
            R.id.sintonizador_cargando,
            if (cargando) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.sintonizador_vu,
            if (sonando) View.VISIBLE else View.GONE,
        )
        if (sonando) {
            views.setTextViewText(R.id.sintonizador_vu, construirVu(idRadio))
        }

        // Programa actual: visible sólo si está sonando Y el ICY del
        // stream nos dio un título. Cuando la emisora no expone metadatos
        // o todavía no han llegado, dejamos la línea oculta para no
        // mover la maquetación con un hueco vacío.
        val programa = (prefs.getString(CLAVE_PROGRAMA, "") ?: "").trim()
        if (sonando && programa.isNotEmpty()) {
            views.setTextViewText(R.id.sintonizador_programa, programa)
            views.setViewVisibility(R.id.sintonizador_programa, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.sintonizador_programa, View.GONE)
        }
        // Glifo del botón principal:
        //   cargando → `…` (no responde al click más que para reentrar
        //              al servicio, que ignora el play repetido).
        //   sonando  → `⏸` y al pulsar dispara ACCION_STOP. Antes el
        //              icono volvía siempre a `▶` aunque la radio
        //              estuviera sonando, dando la impresión de que el
        //              widget no había registrado la pulsación.
        //   parado   → `▶` y al pulsar arranca el servicio.
        val glifoBotonPrincipal = when {
            cargando -> GLIFO_CARGANDO
            sonando -> GLIFO_PAUSA
            else -> GLIFO_PLAY
        }
        views.setTextViewText(R.id.sintonizador_btn_play, glifoBotonPrincipal)

        // Botón anterior → broadcast al propio provider.
        val intentAnt = Intent(context, SintonizadorWidgetProvider::class.java).apply { action = ACCION_ANTERIOR }
        val pAnt = PendingIntent.getBroadcast(
            context, widgetId * 10 + 1, intentAnt,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_anterior, pAnt)

        // Botón siguiente → broadcast al propio provider.
        val intentSig = Intent(context, SintonizadorWidgetProvider::class.java).apply { action = ACCION_SIGUIENTE }
        val pSig = PendingIntent.getBroadcast(
            context, widgetId * 10 + 2, intentSig,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_siguiente, pSig)

        // Botón play/pausa → si nada suena, arranca RadioService en
        // foreground con la URL del stream. Si ya hay reproducción, el
        // mismo botón actúa como pausa y dispara ACCION_STOP. El servicio
        // vive independientemente y mantiene la radio sonando aunque el
        // widget se redibuje o el sistema recicle el proceso de la app.
        val pPlay = if (sonando) {
            val intentPausar = Intent(context, RadioService::class.java).apply {
                action = RadioService.ACCION_STOP
            }
            PendingIntent.getService(
                context, widgetId * 10 + 5, intentPausar,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        } else {
            val intentPlay = Intent(context, RadioService::class.java).apply {
                action = RadioService.ACCION_PLAY
                putExtra(RadioService.EXTRA_URL, radio.streamUrl)
                putExtra(RadioService.EXTRA_TITULO, radio.nombre)
                putExtra(RadioService.EXTRA_ID_RADIO, idRadio.toString())
            }
            pendingIntentForegroundService(
                context,
                // requestCode único por (widget, emisora) — sin esto Android
                // reusa un PendingIntent cacheado de la emisora anterior y al
                // pulsar ▶ con otra radio el sistema dispara el viejo Intent.
                widgetId * 1_000_000 + idRadio,
                intentPlay,
            )
        }
        views.setOnClickPendingIntent(R.id.sintonizador_btn_play, pPlay)

        // Botón stop → manda ACCION_STOP al servicio. Si no hay servicio
        // corriendo el Intent es no-op (Android lo entrega y el servicio
        // se levanta sólo para procesarlo y morirse).
        val intentStop = Intent(context, RadioService::class.java).apply {
            action = RadioService.ACCION_STOP
        }
        val pStop = PendingIntent.getService(
            context, widgetId * 10 + 4, intentStop,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_btn_stop, pStop)

        // Tap en el display abre la app en /audio (deep link clásico).
        val intentDial = Intent(Intent.ACTION_VIEW, Uri.parse("flavornews://radios/play/$idRadio")).apply {
            setPackage(context.packageName)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        val pDial = PendingIntent.getActivity(
            context, widgetId * 10 + 3, intentDial,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.sintonizador_dial, pDial)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    /**
     * `PendingIntent.getForegroundService` sólo existe desde API 26. En
     * versiones anteriores `getService` funciona porque el sistema no
     * exige el flag de foreground en el Intent.
     */
    private fun pendingIntentForegroundService(
        context: Context,
        requestCode: Int,
        intent: Intent,
    ): PendingIntent {
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, requestCode, intent, flags)
        } else {
            PendingIntent.getService(context, requestCode, intent, flags)
        }
    }

    /**
     * Construye la hilera de 10 LEDs con el activo (en posición ya
     * mapeada al rango 0-9) marcado con `◉`, los demás `·`.
     */
    private fun construirLeds(posicionLed: Int): String {
        return (0 until NUM_LEDS).joinToString(" ") { if (it == posicionLed) "◉" else "·" }
    }

    /**
     * String de la aguja: misma anchura que la hilera de LEDs (los dos
     * TextView se solapan en un FrameLayout), con `│` exactamente sobre
     * el LED activo y espacios en el resto. Como ambos comparten
     * monospace + letterSpacing="0.3", la barra cae alineada.
     *
     * La hilera de LEDs es `· · · · · · · · · ·` → posición N ocupa el
     * carácter 2*N (LED) o 2*N+1 (espacio entre LEDs). Ponemos la
     * aguja en el carácter del LED activo.
     */
    private fun construirAguja(posicionLed: Int): String {
        val total = 2 * NUM_LEDS - 1
        return buildString {
            repeat(total) { i ->
                append(if (i == posicionLed * 2) '│' else ' ')
            }
        }
    }

    /**
     * VU "decorativo": hilera de bloques Unicode de altura variable.
     * Como semilla usamos `idRadio` mezclado con el minuto del reloj
     * (`System.currentTimeMillis() / 60_000`) — así dos emisoras
     * distintas dan VUs distintos, y la misma emisora cambia su VU
     * con el tiempo aunque el usuario no toque nada (cuando Android
     * vuelva a llamar `onUpdate`). RemoteViews no permite animación
     * continua; este es el sucedáneo barato.
     */
    private fun construirVu(idRadio: Int): String {
        val rng = Random(idRadio.toLong() * 31 + (System.currentTimeMillis() / 60_000))
        return buildString {
            repeat(LARGO_VU) {
                append(BARRAS_VU[rng.nextInt(BARRAS_VU.size)])
            }
        }
    }

    private fun repetirCompat(s: String, n: Int): String = buildString { repeat(n) { append(s) } }
}
