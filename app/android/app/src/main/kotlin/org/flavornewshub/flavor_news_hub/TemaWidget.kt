package org.flavornewshub.flavor_news_hub

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.widget.RemoteViews

/**
 * Helper para que los widgets respeten el tema claro/oscuro del sistema.
 * Se llama al final de cada `actualizarUno` para repintar colores sobre
 * el mismo layout en lugar de mantener dos XML paralelos.
 */
object TemaWidget {
    fun esOscuro(ctx: Context): Boolean {
        val modo = ctx.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        return modo == Configuration.UI_MODE_NIGHT_YES
    }

    /**
     * Aplica colores coherentes con el tema del sistema. Recibe los ids
     * relevantes del layout; los opcionales pueden ser 0.
     */
    fun aplicar(
        ctx: Context,
        views: RemoteViews,
        idFondo: Int,
        idsTextoPrincipal: List<Int> = emptyList(),
        idsTextoSecundario: List<Int> = emptyList(),
    ) {
        val oscuro = esOscuro(ctx)
        val fondoResId = if (oscuro) R.drawable.widget_fondo else R.drawable.widget_fondo_claro
        views.setInt(idFondo, "setBackgroundResource", fondoResId)
        val colorPrincipal = if (oscuro) Color.WHITE else Color.parseColor("#111111")
        val colorSecundario = if (oscuro) Color.parseColor("#CCE0E0E0") else Color.parseColor("#66000000")
        for (id in idsTextoPrincipal) {
            views.setTextColor(id, colorPrincipal)
        }
        for (id in idsTextoSecundario) {
            views.setTextColor(id, colorSecundario)
        }
    }
}
