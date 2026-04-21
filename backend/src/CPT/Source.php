<?php
declare(strict_types=1);

namespace FlavorNewsHub\CPT;

/**
 * CPT `fnh_source`: un medio/fuente agregado al sistema.
 *
 * Cada source tiene asociado un feed RSS/Atom (o similar), una ficha editorial
 * con quién lo posee y cómo se financia, y un flag de actividad. La ingesta
 * (capa 3) recorre los sources con `active=true` y crea items desde su feed.
 *
 * Slug de URL pública: /f/{slug} (la plantilla real se crea en capa 6).
 */
final class Source
{
    public const SLUG = 'fnh_source';

    public static function registrar(): void
    {
        $etiquetasAdmin = [
            'name'               => _x('Medios', 'post type general name', 'flavor-news-hub'),
            'singular_name'      => _x('Medio', 'post type singular name', 'flavor-news-hub'),
            'menu_name'          => _x('Medios', 'admin menu', 'flavor-news-hub'),
            'add_new'            => __('Añadir medio', 'flavor-news-hub'),
            'add_new_item'       => __('Añadir nuevo medio', 'flavor-news-hub'),
            'edit_item'          => __('Editar medio', 'flavor-news-hub'),
            'new_item'           => __('Nuevo medio', 'flavor-news-hub'),
            'view_item'          => __('Ver medio', 'flavor-news-hub'),
            'view_items'         => __('Ver medios', 'flavor-news-hub'),
            'all_items'          => __('Todos los medios', 'flavor-news-hub'),
            'search_items'       => __('Buscar medios', 'flavor-news-hub'),
            'not_found'          => __('No se encontraron medios', 'flavor-news-hub'),
            'not_found_in_trash' => __('No hay medios en la papelera', 'flavor-news-hub'),
        ];

        register_post_type(self::SLUG, [
            'labels'              => $etiquetasAdmin,
            'description'         => __('Medios alternativos agregados por su feed.', 'flavor-news-hub'),
            'public'              => true,
            'publicly_queryable'  => true,
            'exclude_from_search' => true,
            'has_archive'         => false,
            'show_in_rest'        => true,
            'rest_base'           => 'fnh-sources',
            'supports'            => ['title', 'editor', 'excerpt', 'thumbnail', 'custom-fields'],
            'rewrite'             => ['slug' => 'f', 'with_front' => false],
            'menu_icon'           => 'dashicons-rss',
            'show_in_menu'        => 'flavor-news-hub',
            'capability_type'     => 'post',
            'map_meta_cap'        => true,
        ]);
    }
}
