<?php
declare(strict_types=1);

namespace FlavorNewsHub\CPT;

/**
 * CPT `fnh_radio`: una emisora de radio libre con stream en directo.
 *
 * Diferencia con `fnh_source`: no hay ingesta de RSS; el stream es una
 * URL Icecast/HLS que el cliente reproduce directamente. El backend sólo
 * mantiene el directorio curado.
 *
 * Slug de URL pública: /r/{slug} (plantilla opcional en futuro).
 */
final class Radio
{
    public const SLUG = 'fnh_radio';

    public static function registrar(): void
    {
        $etiquetas = [
            'name'               => _x('Radios', 'post type general name', 'flavor-news-hub'),
            'singular_name'      => _x('Radio', 'post type singular name', 'flavor-news-hub'),
            'menu_name'          => _x('Radios', 'admin menu', 'flavor-news-hub'),
            'add_new'            => __('Añadir radio', 'flavor-news-hub'),
            'add_new_item'       => __('Añadir nueva radio', 'flavor-news-hub'),
            'edit_item'          => __('Editar radio', 'flavor-news-hub'),
            'new_item'           => __('Nueva radio', 'flavor-news-hub'),
            'view_item'          => __('Ver radio', 'flavor-news-hub'),
            'all_items'          => __('Todas las radios', 'flavor-news-hub'),
            'search_items'       => __('Buscar radios', 'flavor-news-hub'),
            'not_found'          => __('No se encontraron radios', 'flavor-news-hub'),
            'not_found_in_trash' => __('No hay radios en la papelera', 'flavor-news-hub'),
        ];

        register_post_type(self::SLUG, [
            'labels'              => $etiquetas,
            'description'         => __('Radios libres con stream en directo agregadas al sistema.', 'flavor-news-hub'),
            'public'              => true,
            'publicly_queryable'  => true,
            'exclude_from_search' => true,
            'has_archive'         => false,
            'show_in_rest'        => true,
            'rest_base'           => 'fnh-radios',
            'supports'            => ['title', 'editor', 'thumbnail', 'custom-fields'],
            'rewrite'             => ['slug' => 'r', 'with_front' => false],
            'menu_icon'           => 'dashicons-microphone',
            'show_in_menu'        => 'flavor-news-hub',
            'capability_type'     => 'post',
            'map_meta_cap'        => true,
        ]);
    }
}
