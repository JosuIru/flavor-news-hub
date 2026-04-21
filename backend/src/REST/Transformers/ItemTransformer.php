<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

/**
 * Transformador de noticias (`fnh_item`) para la API pública.
 *
 * Incluye inline los datos de la fuente (resumen) para evitar N+1 lookups
 * desde el cliente: el listado típico es <=50 items, el coste es aceptable.
 */
final class ItemTransformer
{
    /**
     * @return array<string,mixed>
     */
    public static function transformar(\WP_Post $post): array
    {
        $idItem = (int) $post->ID;
        $idSource = (int) get_post_meta($idItem, '_fnh_source_id', true);

        // `get_the_title()` re-escapa apóstrofes tipográficas y similares
        // a entidades HTML. Decodificamos dos veces para cubrir casos de
        // doble escape (feeds que ya traían entidades escapadas).
        $tituloDecoded = html_entity_decode(get_the_title($post), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $tituloDecoded = html_entity_decode($tituloDecoded, ENT_QUOTES | ENT_HTML5, 'UTF-8');

        return [
            'id'           => $idItem,
            'slug'         => (string) $post->post_name,
            'title'        => $tituloDecoded,
            'excerpt'      => (string) apply_filters('the_content', $post->post_content),
            'url'          => (string) get_permalink($post),
            'original_url' => (string) get_post_meta($idItem, '_fnh_original_url', true),
            'published_at' => (string) get_post_meta($idItem, '_fnh_published_at', true),
            'media_url'        => (string) get_post_meta($idItem, '_fnh_media_url', true),
            'duration_seconds' => (int) get_post_meta($idItem, '_fnh_duration_seconds', true),
            'source'           => SourceTransformer::transformarResumen($idSource),
            'topics'           => TopicsHelper::obtenerTopicsDelPost($idItem),
        ];
    }
}
