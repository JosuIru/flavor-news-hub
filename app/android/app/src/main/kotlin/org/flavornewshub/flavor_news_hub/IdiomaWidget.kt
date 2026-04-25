package org.flavornewshub.flavor_news_hub

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import java.util.Locale

/**
 * Proveedor de `Resources` localizados para los AppWidgetProviders
 * según la preferencia de idioma elegida en Ajustes → Idioma de la
 * interfaz dentro de la app. Sin este wrapper, los widgets seguían
 * el locale del sistema Android — un usuario que tuviera la APK en
 * catalán pero el teléfono en español veía el widget en español.
 *
 * Lectura: la preferencia vive en `FlutterSharedPreferences` con la
 * clave `flutter.fnh.pref.localeCode`. Si está vacía (modo "seguir
 * sistema") o no se puede leer, devolvemos los recursos del sistema
 * — comportamiento histórico.
 */
object IdiomaWidget {
    private const val NOMBRE_PREFS = "FlutterSharedPreferences"
    private const val CLAVE_IDIOMA = "flutter.fnh.pref.localeCode"

    /**
     * Recursos del paquete con el locale elegido por el usuario
     * aplicado. Usar en vez de `context.resources` siempre que
     * queramos que el widget siga el idioma de la APK.
     */
    fun recursos(context: Context): Resources {
        val codigo = leerCodigoIdioma(context)
        if (codigo.isNullOrBlank()) return context.resources
        val locale = construirLocale(codigo)
        val configuracion = Configuration(context.resources.configuration)
        configuracion.setLocale(locale)
        return context.createConfigurationContext(configuracion).resources
    }

    private fun leerCodigoIdioma(context: Context): String? {
        return try {
            context.getSharedPreferences(NOMBRE_PREFS, Context.MODE_PRIVATE)
                .getString(CLAVE_IDIOMA, null)
        } catch (_: Exception) {
            null
        }
    }

    private fun construirLocale(codigo: String): Locale {
        // Aceptamos `es`, `pt-BR`, `pt_BR`. Aplanamos a Locale.
        val partes = codigo.replace('_', '-').split('-')
        return when (partes.size) {
            1 -> Locale(partes[0])
            else -> Locale(partes[0], partes[1])
        }
    }
}
