package org.flavornewshub.flavor_news_hub

import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extendemos `AudioServiceActivity` (de `audio_service`, dep transitiva de
 * `just_audio_background`) en vez de la `FlutterActivity` estándar para que
 * el plugin pueda conectarse con la activity en runtime y mostrar los
 * controles en la notificación del sistema.
 *
 * Además montamos un `MethodChannel` propio para que Flutter pueda leer
 * deep-links (p. ej. `flavornews://radios/play/6587` desde el widget de
 * favoritos) tanto al cold-start como con la app ya abierta.
 */
class MainActivity : AudioServiceActivity() {

    private var pendienteDeepLink: String? = null
    private var canalDeepLink: MethodChannel? = null
    private var canalPip: MethodChannel? = null
    private var pipAutoActivo: Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canalDeepLink = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fnh/deeplink",
        ).also { canal ->
            canal.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitial" -> {
                        // Primera llamada: devolvemos el URI con el que
                        // arrancó la activity, si lo había.
                        val uri = intent?.data?.toString()?.takeIf { it.startsWith("flavornews://") }
                        pendienteDeepLink = null
                        result.success(uri)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        canalPip = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fnh/pip",
        ).also { canal ->
            canal.setMethodCallHandler { call, result ->
                when (call.method) {
                    "soportaPip" -> result.success(dispositivoSoportaPip())
                    "setPipActive" -> {
                        pipAutoActivo = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    "entrarEnPip" -> result.success(entrarEnPip())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data?.toString()
        if (uri != null && uri.startsWith("flavornews://")) {
            // App ya en foreground: notificamos a Dart vía el canal.
            canalDeepLink?.invokeMethod("onLink", uri)
        }
    }

    /**
     * Cuando el usuario pulsa Home estando en el reproductor de video
     * (Dart nos habrá avisado con `setPipActive(true)`), pasamos la
     * activity a modo Picture-in-Picture para que el vídeo siga visible.
     */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipAutoActivo) {
            entrarEnPip()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        canalPip?.invokeMethod("onModeChanged", isInPictureInPictureMode)
    }

    private fun dispositivoSoportaPip(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun entrarEnPip(): Boolean {
        if (!dispositivoSoportaPip()) return false
        return try {
            val parametros = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(parametros)
        } catch (e: IllegalStateException) {
            false
        }
    }
}
