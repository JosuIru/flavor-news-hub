<?php
declare(strict_types=1);

namespace FlavorNewsHub\CPT;

/**
 * CPT `fnh_item`: una noticia agregada desde el feed de un medio.
 *
 * El contenido de un item se limita SIEMPRE al extracto que provea el feed
 * de origen. Nunca se scrapea el artículo completo: respetar el tráfico y
 * los ingresos del medio es parte del contrato editorial del proyecto.
 *
 * Orden canónico: siempre por `_fnh_published_at` descendente.
 * Slug de URL pública: /n/{slug} (plantilla en capa 6).
 */
final class Item
{
    public const SLUG = 'fnh_item';

    public static function registrar(): void
    {
        $etiquetasAdmin = [
            'name'               => _x('Noticias', 'post type general name', 'flavor-news-hub'),
            'singular_name'      => _x('Noticia', 'post type singular name', 'flavor-news-hub'),
            'menu_name'          => _x('Noticias', 'admin menu', 'flavor-news-hub'),
            'add_new'            => __('Añadir noticia', 'flavor-news-hub'),
            'add_new_item'       => __('Añadir nueva noticia', 'flavor-news-hub'),
            'edit_item'          => __('Editar noticia', 'flavor-news-hub'),
            'new_item'           => __('Nueva noticia', 'flavor-news-hub'),
            'view_item'          => __('Ver noticia', 'flavor-news-hub'),
            'view_items'         => __('Ver noticias', 'flavor-news-hub'),
            'all_items'          => __('Todas las noticias', 'flavor-news-hub'),
            'search_items'       => __('Buscar noticias', 'flavor-news-hub'),
            'not_found'          => __('No hay noticias todavía', 'flavor-news-hub'),
            'not_found_in_trash' => __('No hay noticias en la papelera', 'flavor-news-hub'),
        ];

        register_post_type(self::SLUG, [
            'labels'              => $etiquetasAdmin,
            'description'         => __('Titulares agregados desde los feeds de los medios.', 'flavor-news-hub'),
            'public'              => true,
            'publicly_queryable'  => true,
            'exclude_from_search' => false,
            'has_archive'         => false,
            'show_in_rest'        => true,
            'rest_base'           => 'fnh-items',
            'supports'            => ['title', 'editor', 'thumbnail', 'custom-fields'],
            'rewrite'             => ['slug' => 'n', 'with_front' => false],
            'menu_icon'           => 'dashicons-megaphone',
            'show_in_menu'        => 'flavor-news-hub',
            'capability_type'     => 'post',
            'map_meta_cap'        => true,
        ]);
    }
}
