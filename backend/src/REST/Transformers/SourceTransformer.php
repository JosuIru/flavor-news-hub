<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

use FlavorNewsHub\CPT\Source;

/**
 * Transformador de fuentes (`fnh_source`) para la API pública.
 *
 * Dos variantes:
 *  - resumen (`transformarResumen`): sólo lo imprescindible para embedding
 *    en un item (id, slug, name, website_url, url).
 *  - completa (`transformarCompleto`): toda la ficha editorial.
 */
final class SourceTransformer
{
    /**
     * @return array{
     *   id:int, slug:string, name:string, website_url:string, url:string
     * }|null
     */
    public static function transformarResumen(int $idSource): ?array
    {
        if ($idSource <= 0) {
            return null;
        }
        $post = get_post($idSource);
        if (!$post || $post->post_type !== Source::SLUG || $post->post_status !== 'publish') {
            return null;
        }
        // Un medio desactivado no debe colarse embebido en items del
        // feed: el consumidor debe ver la misma visibilidad que tiene
        // `/sources`. Si el usuario desactivó una fuente, sus items
        // quedan huérfanos — lo resolverá la propia capa de items.
        if ((string) get_post_meta($post->ID, '_fnh_active', true) !== '1') {
            return null;
        }
        $tipoFeed = (string) get_post_meta($post->ID, '_fnh_feed_type', true);
        return [
            'id'          => (int) $post->ID,
            'slug'        => (string) $post->post_name,
            'name'        => get_the_title($post),
            'website_url' => (string) get_post_meta($post->ID, '_fnh_website_url', true),
            'url'         => (string) get_permalink($post),
            'feed_type'   => $tipoFeed !== '' ? $tipoFeed : 'rss',
        ];
    }

    /**
     * @return array<string,mixed>
     */
    public static function transformarCompleto(\WP_Post $post): array
    {
        $idSource = (int) $post->ID;
        $tipoFeed = (string) get_post_meta($idSource, '_fnh_feed_type', true);
        $idiomasGuardados = get_post_meta($idSource, '_fnh_languages', true);
        if (!is_array($idiomasGuardados)) {
            $idiomasGuardados = [];
        }

        return [
            'id'             => $idSource,
            'slug'           => (string) $post->post_name,
            'name'           => get_the_title($post),
            'description'    => (string) apply_filters('the_content', $post->post_content),
            'url'            => (string) get_permalink($post),
            'feed_url'       => (string) get_post_meta($idSource, '_fnh_feed_url', true),
            'feed_type'      => $tipoFeed !== '' ? $tipoFeed : 'rss',
            'website_url'    => (string) get_post_meta($idSource, '_fnh_website_url', true),
            'languages'      => array_values(array_map('strval', $idiomasGuardados)),
            'territory'      => (string) get_post_meta($idSource, '_fnh_territory', true),
            'ownership'      => (string) get_post_meta($idSource, '_fnh_ownership', true),
            'editorial_note' => (string) get_post_meta($idSource, '_fnh_editorial_note', true),
            'active'         => (bool) get_post_meta($idSource, '_fnh_active', true),
            'topics'         => TopicsHelper::obtenerTopicsDelPost($idSource),
        ];
    }
}
