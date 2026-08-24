package org.flavornewshub.flavor_news_hub

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Smoke test JVM de los AppWidgetProviders. Robolectric levanta el
 * framework Android en la JVM (sin emulador), así que esto verifica lo
 * mínimo imprescindible para que un widget no tumbe el systemui: que cada
 * provider **carga e instancia** (init estático, companion, dependencias
 * resueltas en runtime) y que `onUpdate` es invocable sin lanzar.
 *
 * Es justo la clase de fallo —`NoClassDefFoundError`, `NoSuchFieldError`—
 * que dejó la app en pantalla negra al arrancar tras un bump de toolchain.
 * Llamamos `onUpdate` con un array de ids vacío a propósito: ejercita el
 * punto de entrada del provider sin inflar RemoteViews ni resolver recursos
 * localizados, que es terreno de un test de instrumentación, no de humo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetProvidersSmokeTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun onUpdateNoPeta(provider: android.appwidget.AppWidgetProvider) {
        val gestor = AppWidgetManager.getInstance(context)
        assertNotNull("AppWidgetManager no disponible bajo Robolectric", gestor)
        // Sin ids: el bucle interno no corre, pero el método debe resolverse
        // y ejecutarse limpio. Si la clase no cargara, esto ya habría petado
        // al instanciar el provider.
        provider.onUpdate(context, gestor, IntArray(0))
    }

    @Test
    fun `TitularesWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(TitularesWidgetProvider())
    }

    @Test
    fun `VideosWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(VideosWidgetProvider())
    }

    @Test
    fun `PodcastsWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(PodcastsWidgetProvider())
    }

    @Test
    fun `ReproductorRadioWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(ReproductorRadioWidgetProvider())
    }

    @Test
    fun `ReproductorMusicaWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(ReproductorMusicaWidgetProvider())
    }

    @Test
    fun `FavoritosWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(FavoritosWidgetProvider())
    }

    @Test
    fun `BuscadorWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(BuscadorWidgetProvider())
    }

    @Test
    fun `SintonizadorWidgetProvider carga y onUpdate no peta`() {
        onUpdateNoPeta(SintonizadorWidgetProvider())
    }
}
