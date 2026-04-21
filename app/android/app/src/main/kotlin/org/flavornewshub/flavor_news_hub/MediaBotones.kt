package org.flavornewshub.flavor_news_hub

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.view.KeyEvent

/**
 * Genera `PendingIntent`s para botones media de los widgets. Cada botón
 * envía un broadcast `ACTION_MEDIA_BUTTON` con un `KeyEvent` sintético;
 * la `MediaSession` activa (gestionada por `just_audio_background` a
 * través de `com.ryanheise.audioservice.MediaButtonReceiver`) lo recibe
 * y traduce a play/pause/next/etc.
 *
 * Si no hay sesión activa (la app no ha sonado aún), el sistema lo ignora
 * silenciosamente. El fallback práctico es que el widget siga teniendo
 * área clicable que abre la app para arrancar reproducción desde ahí.
 */
object MediaBotones {

    fun playPause(ctx: Context): PendingIntent = crear(ctx, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 10)
    fun stop(ctx: Context): PendingIntent = crear(ctx, KeyEvent.KEYCODE_MEDIA_STOP, 11)
    fun siguiente(ctx: Context): PendingIntent = crear(ctx, KeyEvent.KEYCODE_MEDIA_NEXT, 12)
    fun previo(ctx: Context): PendingIntent = crear(ctx, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 13)

    private fun crear(ctx: Context, keyCode: Int, requestCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            // `setPackage` es imprescindible desde Android 8 para que el
            // broadcast llegue a un receiver declarado en el manifest.
            setPackage(ctx.packageName)
            putExtra(
                Intent.EXTRA_KEY_EVENT,
                KeyEvent(KeyEvent.ACTION_DOWN, keyCode),
            )
        }
        return PendingIntent.getBroadcast(
            ctx,
            requestCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
