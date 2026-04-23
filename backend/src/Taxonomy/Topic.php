<?php
declare(strict_types=1);

namespace FlavorNewsHub\Taxonomy;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;

/**
 * Taxonomía `fnh_topic`: temáticas compartidas entre medios, noticias y colectivos.
 *
 * Es jerárquica porque nos permite agrupaciones futuras (p.ej. una temática
 * "vivienda" con hijas "okupación", "alquiler", "hipotecas") sin migraciones
 * de datos. En la v1 solo existe el primer nivel.
 *
 * El listado precargado contiene 18 temáticas canónicas y no pretende ser
 * cerrado: los editores pueden añadir más desde el admin.
 */
final class Topic
{
    public const SLUG = 'fnh_topic';

    /**
     * Temáticas canónicas precargadas en la activación.
     * Clave = slug estable (ASCII, sin acentos), valor = etiqueta visible.
     *
     * Importante: los slugs son identificadores permanentes. Las etiquetas
     * pueden traducirse vía el panel de taxonomías o vía .mo files.
     *
     * @var array<string,string>
     */
    public const TEMATICAS_PRECARGADAS = [
        'vivienda'            => 'Vivienda',
        'sanidad'             => 'Sanidad',
        'laboral'             => 'Laboral',
        'feminismos'          => 'Feminismos',
        'ecologismo'          => 'Ecologismo',
        'antirracismo'        => 'Antirracismo',
        'educacion'           => 'Educación',
        'memoria-historica'   => 'Memoria histórica',
        'rural'               => 'Rural',
        'cultura'             => 'Cultura',
        'alimentacion'        => 'Alimentación',
        'soberania-alimentaria' => 'Soberanía alimentaria',
        'derechos-civiles'    => 'Derechos civiles',
        'internacional'       => 'Internacional',
        'tecnologia-soberana' => 'Tecnología soberana',
        'economia-social'     => 'Economía social',
        'migraciones'         => 'Migraciones',
        'cuidados'            => 'Cuidados',
    ];

    public static function registrar(): void
    {
        $etiquetasAdmin = [
            'name'                       => _x('Temáticas', 'taxonomy general name', 'flavor-news-hub'),
            'singular_name'              => _x('Temática', 'taxonomy singular name', 'flavor-news-hub'),
            'search_items'               => __('Buscar temáticas', 'flavor-news-hub'),
            'popular_items'              => __('Temáticas populares', 'flavor-news-hub'),
            'all_items'                  => __('Todas las temáticas', 'flavor-news-hub'),
            'parent_item'                => __('Temática superior', 'flavor-news-hub'),
            'parent_item_colon'          => __('Temática superior:', 'flavor-news-hub'),
            'edit_item'                  => __('Editar temática', 'flavor-news-hub'),
            'update_item'                => __('Actualizar temática', 'flavor-news-hub'),
            'view_item'                  => __('Ver temática', 'flavor-news-hub'),
            'add_new_item'               => __('Añadir nueva temática', 'flavor-news-hub'),
            'new_item_name'              => __('Nombre de la nueva temática', 'flavor-news-hub'),
            'separate_items_with_commas' => __('Separa las temáticas con comas', 'flavor-news-hub'),
            'add_or_remove_items'        => __('Añadir o quitar temáticas', 'flavor-news-hub'),
            'choose_from_most_used'      => __('Elegir entre las más usadas', 'flavor-news-hub'),
            'menu_name'                  => __('Temáticas', 'flavor-news-hub'),
        ];

        $tiposAsociados = [
            Source::SLUG,
            Item::SLUG,
            Collective::SLUG,
            Radio::SLUG,
        ];

        register_taxonomy(self::SLUG, $tiposAsociados, [
            'labels'            => $etiquetasAdmin,
            'description'       => __('Temáticas del directorio, compartidas entre medios, noticias y colectivos.', 'flavor-news-hub'),
            'hierarchical'      => true,
            'public'            => true,
            'publicly_queryable' => true,
            'show_ui'           => true,
            'show_admin_column' => true,
            'show_in_nav_menus' => true,
            'show_in_rest'      => true,
            'rest_base'         => 'fnh-topics',
            'query_var'         => true,
            'rewrite'           => [
                'slug'         => 'tematica',
                'with_front'   => false,
                'hierarchical' => true,
            ],
        ]);
    }
}
