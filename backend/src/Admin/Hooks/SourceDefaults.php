<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Hooks;

use FlavorNewsHub\CPT\Source;

/**
 * Escribe defaults del CPT `fnh_source` cuando el usuario lo crea sin
 * pasar por el metabox (p.ej. vía quick edit) y no hay meta persistido aún.
 *
 * Resuelve la ambigüedad documentada en capa 2: el default `_fnh_active=true`
 * declarado en `register_post_meta` existe sólo como valor por defecto al
 * LEER; al FILTRAR con `meta_query` necesitamos la fila escrita. Este hook
 * garantiza que siempre lo esté.
 */
final class SourceDefaults
{
    public static function aplicarDefaults(int $idPost, \WP_Post $post): void
    {
        if ($post->post_type !== Source::SLUG) {
            return;
        }
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }

        // Sólo escribir si la fila meta no existe (no fue nunca seteada).
        $tieneActivo = metadata_exists('post', $idPost, '_fnh_active');
        if (!$tieneActivo) {
            update_post_meta($idPost, '_fnh_active', true);
        }
        $tieneTipoFeed = metadata_exists('post', $idPost, '_fnh_feed_type');
        if (!$tieneTipoFeed) {
            update_post_meta($idPost, '_fnh_feed_type', 'rss');
        }
    }
}
