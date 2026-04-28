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
     * Precarga en object cache las metas y términos de una lista de
     * items y sus sources antes de transformarlos. Sin esta llamada,
     * cada `transformar()` dispara ~6 queries de meta + 1 de términos
     * por item, y `SourceTransformer::transformarResumen()` añade ~7
     * más por source único. Para `/items?per_page=20` eso son
     * fácilmente >150 queries — patrón N+1 clásico.
     *
     * `update_meta_cache` y `update_object_term_cache` son helpers de
     * WP que hacen una sola query batch y rellenan la cache interna,
     * de modo que las llamadas `get_post_meta` posteriores son lookups
     * en memoria. Los sources se precargan también porque cada item
     * embebe el resumen de su fuente.
     *
     * @param list<\WP_Post> $posts
     */
    public static function precargarCachesParaListado(array $posts): void
    {
        if ($posts === []) {
            return;
        }
        $idsItems = [];
        $idsSources = [];
        foreach ($posts as $post) {
            $idsItems[] = (int) $post->ID;
            $idSource = (int) get_post_meta((int) $post->ID, '_fnh_source_id', true);
            if ($idSource > 0) {
                $idsSources[$idSource] = true;
            }
        }
        // En este punto get_post_meta de _fnh_source_id ya hizo una query
        // por item; al precargar la cache global a continuación, las
        // llamadas subsiguientes desde transformar() encuentran todo
        // en memoria. Si se llama dos veces seguidas en el mismo
        // request, la segunda es no-op.
        update_meta_cache('post', $idsItems);
        update_object_term_cache($idsItems, \FlavorNewsHub\CPT\Item::SLUG);
        if ($idsSources !== []) {
            update_meta_cache('post', array_keys($idsSources));
        }
    }

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

        // Antes pasábamos el `post_content` por `apply_filters('the_content',
        // ...)` para tener wpautop. Pero ese filtro tiene enganchados
        // shortcodes, plugins de tracking y todo tipo de hooks pesados
        // de WordPress: con un listado de 20 items en un sitio con un
        // par de plugins activos se traducía en cientos de ms de CPU
        // sólo para construir un excerpt. El contenido viene del feed
        // RSS ya como HTML; aplicamos `wpautop` directo (cubre el caso
        // de feeds que sirven texto plano con saltos de línea) y nos
        // saltamos el resto del filtro.
        return [
            'id'           => $idItem,
            'slug'         => (string) $post->post_name,
            'title'        => $tituloDecoded,
            'excerpt'      => self::limpiarExcerpt(wpautop($post->post_content)),
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
