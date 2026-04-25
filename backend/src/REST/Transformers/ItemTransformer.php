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
            'excerpt'      => self::limpiarExcerpt((string) apply_filters('the_content', $post->post_content)),
            'url'          => (string) get_permalink($post),
            'original_url' => (string) get_post_meta($idItem, '_fnh_original_url', true),
            'published_at' => (string) get_post_meta($idItem, '_fnh_published_at', true),
            'media_url'        => (string) get_post_meta($idItem, '_fnh_media_url', true),
            'audio_url'        => (string) get_post_meta($idItem, '_fnh_audio_url', true),
            'duration_seconds' => (int) get_post_meta($idItem, '_fnh_duration_seconds', true),
            'source'           => SourceTransformer::transformarResumen($idSource),
            'topics'           => TopicsHelper::obtenerTopicsDelPost($idItem),
        ];
    }

    /**
     * Limpia un excerpt HTML para que se renderice bien en las cards de
     * listado, donde ya tenemos miniatura aparte (media_url). Strippa:
     *
     *  - `<img>` inline: muchos feeds duplican la imagen destacada en el
     *    contenido con `style="float:left"` que rompe el line-clamp.
     *  - Párrafos "appeared first on" de WordPress: plantillas típicas
     *    de feeds tipo `<p>The post <a>X</a> appeared first on <a>Y</a>.</p>`
     *    y `<p>The post ...</p>`.
     *  - Scripts y iframes por si acaso (defensa en profundidad; wp_kses
     *    ya los quita, pero en el excerpt de la API queremos garantías).
     */
    private static function limpiarExcerpt(string $html): string
    {
        if ($html === '') {
            return '';
        }
        // Eliminar <img>, <script>, <iframe> enteros (incluido su contenido).
        $html = preg_replace('#<img\b[^>]*>#is', '', $html) ?? $html;
        $html = preg_replace('#<script\b[^>]*>.*?</script>#is', '', $html) ?? $html;
        $html = preg_replace('#<iframe\b[^>]*>.*?</iframe>#is', '', $html) ?? $html;
        // Eliminar el párrafo "The post X appeared first on Y" que añaden
        // feeds RSS de muchos WordPress (es ruido, no contenido).
        $html = preg_replace(
            '#<p>\s*The post\s+.*?\s+appeared first on\s+.*?</p>#is',
            '',
            $html
        ) ?? $html;
        return trim($html);
    }
}
