<?php
declare(strict_types=1);

namespace FlavorNewsHub\Templates;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;

/**
 * Enruta las URLs públicas `/n/{slug}`, `/c/{slug}`, `/f/{slug}` a las
 * plantillas propias del plugin, puenteando el tema activo.
 *
 * Principio: la web pública es un fallback sobrio y accesible, independiente
 * de cualquier tema. Así los enlaces compartidos desde la app funcionan
 * igual en cualquier instancia, sin asumir CSS ni plantillas del tema.
 *
 * Los colectivos sólo se sirven si están `publish` y `_fnh_verified=true`.
 * Un colectivo publicado pero aún no verificado (caso raro) responde 404.
 */
final class TemplateRouter
{
    public static function elegirPlantilla(string $plantillaTema): string
    {
        if (!is_singular()) {
            return $plantillaTema;
        }
        $postActual = get_queried_object();
        if (!$postActual instanceof \WP_Post) {
            return $plantillaTema;
        }

        switch ($postActual->post_type) {
            case Source::SLUG:
                return FNH_PLUGIN_DIR . 'templates/single-fnh-source.php';

            case Item::SLUG:
                return FNH_PLUGIN_DIR . 'templates/single-fnh-item.php';

            case Collective::SLUG:
                // El bloqueo por no-verificado se hace en `template_redirect`
                // (ver `bloquearColectivoNoVerificado`), que corre antes de
                // que WP envíe cabeceras. Aquí sólo llegamos si pasa el filtro.
                return FNH_PLUGIN_DIR . 'templates/single-fnh-collective.php';
        }
        return $plantillaTema;
    }

    /**
     * En `template_redirect` (antes de que WP envíe ninguna cabecera ni
     * output) comprobamos si la URL apunta a un colectivo aún no verificado.
     * Si es así, respondemos 404 con plantilla propia y terminamos.
     */
    public static function bloquearColectivoNoVerificado(): void
    {
        if (!is_singular(Collective::SLUG)) {
            return;
        }
        $idColectivo = (int) get_queried_object_id();
        if ($idColectivo <= 0) {
            return;
        }
        if (get_post_meta($idColectivo, '_fnh_verified', true)) {
            return;
        }

        status_header(404);
        nocache_headers();
        header('Content-Type: text/html; charset=' . get_bloginfo('charset'));
        include FNH_PLUGIN_DIR . 'templates/single-fnh-404.php';
        exit;
    }
}
