package org.flavornewshub.flavor_news_hub

import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONObject

/**
 * Arranca la última emisora escuchada cuando se conecta un dispositivo de
 * audio Bluetooth (perfil A2DP: coche, altavoz, auriculares), si el
 * usuario activó "Radio al conectar el coche" en Ajustes y no hay nada
 * sonando ya.
 *
 * Por qué A2DP y no ACL_CONNECTED: el ACL es el enlace de bajo nivel y lo
 * dispara CUALQUIER dispositivo Bluetooth (reloj, mando, báscula...);
 * el estado del perfil A2DP sólo cambia cuando se conecta un sumidero de
 * audio real — exactamente el caso "me he subido al coche". Además, para
 * cuando A2DP está conectado el enrutado de audio ya apunta al coche, así
 * que el stream no arranca por el altavoz del móvil.
 *
 * Por qué el RadioService nativo y no la app Flutter: este receiver corre
 * con la app cerrada; levantar el engine Dart desde un broadcast es lento
 * y frágil (mismo motivo por el que el widget Sintonizador usa el
 * servicio). El RadioService ya sabe reproducir, poner la notificación
 * MediaStyle, saltar de emisora si la guardada está caída y actualizar
 * los widgets.
 *
 * Los datos vienen de las SharedPreferences de Flutter (fichero
 * `FlutterSharedPreferences`, claves con prefijo `flutter.`): el ajuste
 * lo escribe `PreferenciasNotifier` y la última emisora la guarda
 * `ReproductorRadioNotifier` como JSON del modelo `Radio` (snake_case:
 * `stream_url`, `name`...).
 *
 * Todo el cuerpo va en try/catch: un broadcast que peta con la app
 * cerrada es un crash silencioso que el usuario no puede reportar.
 */
class BluetoothAutoplayReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BtAutoplay"
        private const val ACCION_A2DP =
            "android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED"
        private const val PREFS_FLUTTER = "FlutterSharedPreferences"
        private const val CLAVE_AJUSTE = "flutter.fnh.pref.prepararRadioBluetooth"
        private const val CLAVE_ULTIMA_EMISORA = "flutter.fnh.radio.ultimaEmisora"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action != ACCION_A2DP) return
            val estado = intent.getIntExtra(BluetoothProfile.EXTRA_STATE, -1)
            if (estado != BluetoothProfile.STATE_CONNECTED) return

            val prefsFlutter =
                context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            if (!prefsFlutter.getBoolean(CLAVE_AJUSTE, false)) return

            // Si ya suena algo (otra app de música, la propia radio, un
            // pódcast), no nos metemos en medio.
            val gestorAudio =
                context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (gestorAudio.isMusicActive) return

            val crudo = prefsFlutter.getString(CLAVE_ULTIMA_EMISORA, null) ?: return
            val emisora = JSONObject(crudo)
            val urlStream = emisora.optString("stream_url", "")
            if (urlStream.isEmpty()) return
            val nombre = emisora.optString("name", "")
            val idRadio = emisora.optInt("id", 0).toString()

            Log.i(TAG, "A2DP conectado → autoplay de \"$nombre\"")
            val intentPlay = Intent(context, RadioService::class.java).apply {
                action = RadioService.ACCION_PLAY
                putExtra(RadioService.EXTRA_URL, urlStream)
                putExtra(RadioService.EXTRA_TITULO, nombre)
                putExtra(RadioService.EXTRA_ID_RADIO, idRadio)
            }
            ContextCompat.startForegroundService(context, intentPlay)
        } catch (error: Exception) {
            // Nunca propagar: un crash aquí ocurre con la app cerrada y
            // sin UI donde contarlo.
            Log.w(TAG, "autoplay Bluetooth falló", error)
        }
    }
}
