<?php
declare(strict_types=1);

namespace FlavorNewsHub\CPT;

/**
 * CPT `fnh_collective`: un colectivo real (asociación, cooperativa, iniciativa
 * barrial, etc.) que trabaja sobre alguna temática.
 *
 * Las altas públicas vía REST (`POST /flavor-news/v1/collectives/submit`) se
 * crean en estado `pending` y requieren verificación manual desde el admin
 * antes de ser visibles. El campo meta `_fnh_contact_email` y
 * `_fnh_submitted_by_email` jamás se exponen en la API pública.
 *
 * Slug de URL pública: /c/{slug} (plantilla en capa 6).
 */
final class Collective
{
    public const SLUG = 'fnh_collective';

    public static function registrar(): void
    {
        $etiquetasAdmin = [
            'name'               => _x('Colectivos', 'post type general name', 'flavor-news-hub'),
            'singular_name'      => _x('Colectivo', 'post type singular name', 'flavor-news-hub'),
            'menu_name'          => _x('Colectivos', 'admin menu', 'flavor-news-hub'),
            'add_new'            => __('Añadir colectivo', 'flavor-news-hub'),
            'add_new_item'       => __('Añadir nuevo colectivo', 'flavor-news-hub'),
            'edit_item'          => __('Editar colectivo', 'flavor-news-hub'),
            'new_item'           => __('Nuevo colectivo', 'flavor-news-hub'),
            'view_item'          => __('Ver colectivo', 'flavor-news-hub'),
            'view_items'         => __('Ver colectivos', 'flavor-news-hub'),
            'all_items'          => __('Todos los colectivos', 'flavor-news-hub'),
            'search_items'       => __('Buscar colectivos', 'flavor-news-hub'),
            'not_found'          => __('No hay colectivos registrados', 'flavor-news-hub'),
            'not_found_in_trash' => __('No hay colectivos en la papelera', 'flavor-news-hub'),
        ];

        register_post_type(self::SLUG, [
            'labels'              => $etiquetasAdmin,
            'description'         => __('Colectivos organizados sobre las temáticas del directorio.', 'flavor-news-hub'),
            'public'              => true,
            'publicly_queryable'  => true,
            'exclude_from_search' => false,
            'has_archive'         => false,
            'show_in_rest'        => true,
            'rest_base'           => 'fnh-collectives',
            'supports'            => ['title', 'editor', 'thumbnail', 'custom-fields'],
            'rewrite'             => ['slug' => 'c', 'with_front' => false],
            'menu_icon'           => 'dashicons-groups',
            'show_in_menu'        => 'flavor-news-hub',
            'capability_type'     => 'post',
            'map_meta_cap'        => true,
        ]);
    }
}
