<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Support\TerritoryNormalizer;

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
     *   id:int, slug:string, name:string, website_url:string, url:string,
     *   feed_type:string, territory:string, country:string, region:string,
     *   city:string, network:string, content_license:string
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
        $territorio = (string) get_post_meta($post->ID, '_fnh_territory', true);
        $ubicacion = self::obtenerUbicacion($post->ID, $territorio);
        return [
            'id'              => (int) $post->ID,
            'slug'            => (string) $post->post_name,
            'name'            => get_the_title($post),
            'website_url'     => (string) get_post_meta($post->ID, '_fnh_website_url', true),
            'url'             => (string) get_permalink($post),
            'feed_type'       => $tipoFeed !== '' ? $tipoFeed : 'rss',
            'territory'       => $territorio,
            'country'         => $ubicacion['country'],
            'region'          => $ubicacion['region'],
            'city'            => $ubicacion['city'],
            'network'         => $ubicacion['network'],
            // Marca "voz de movimiento" — la app la usa para boost
            // de scoring en feed y para filtrar la sección dedicada.
            // Incluida en el resumen para que cliente no necesite un
            // segundo lookup por item.
            'es_movimiento'   => (bool) get_post_meta($post->ID, '_fnh_es_movimiento', true),
            // Incluido en el resumen porque la app y la web deciden en
            // tiempo de render si pueden embebir vídeo/audio inline
            // (solo CC/public-domain/mixed). Evita un lookup extra por
            // item para obtener esta sola pieza de metadato.
            'content_license' => (string) get_post_meta($post->ID, '_fnh_content_license', true),
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
        $formatosEmision = get_post_meta($idSource, '_fnh_broadcast_format', true);
        if (!is_array($formatosEmision)) {
            $formatosEmision = [];
        }
        $tipoMedio = (string) get_post_meta($idSource, '_fnh_medium_type', true);
        $permisoStream = (string) get_post_meta($idSource, '_fnh_live_stream_permit', true);
        $territorio = (string) get_post_meta($idSource, '_fnh_territory', true);
        $ubicacion = self::obtenerUbicacion($idSource, $territorio);

        return [
            'id'                 => $idSource,
            'slug'               => (string) $post->post_name,
            'name'               => get_the_title($post),
            'description'        => (string) apply_filters('the_content', $post->post_content),
            'url'                => (string) get_permalink($post),
            'feed_url'           => (string) get_post_meta($idSource, '_fnh_feed_url', true),
            'feed_type'          => $tipoFeed !== '' ? $tipoFeed : 'rss',
            'website_url'        => (string) get_post_meta($idSource, '_fnh_website_url', true),
            'languages'          => array_values(array_map('strval', $idiomasGuardados)),
            'territory'          => $territorio,
            'country'            => $ubicacion['country'],
            'region'             => $ubicacion['region'],
            'city'               => $ubicacion['city'],
            'network'            => $ubicacion['network'],
            'support_url'        => (string) get_post_meta($idSource, '_fnh_support_url', true),
            'es_movimiento'      => (bool) get_post_meta($idSource, '_fnh_es_movimiento', true),
            'ownership'          => (string) get_post_meta($idSource, '_fnh_ownership', true),
            'editorial_note'     => (string) get_post_meta($idSource, '_fnh_editorial_note', true),
            'active'             => (bool) get_post_meta($idSource, '_fnh_active', true),
            'topics'             => TopicsHelper::obtenerTopicsDelPost($idSource),
            'medium_type'        => $tipoMedio !== '' ? $tipoMedio : 'news',
            'broadcast_format'   => array_values(array_map('strval', $formatosEmision)),
            'content_license'    => (string) get_post_meta($idSource, '_fnh_content_license', true),
            'legal_note'         => (string) get_post_meta($idSource, '_fnh_legal_note', true),
            'has_live_stream'    => (bool) get_post_meta($idSource, '_fnh_has_live_stream', true),
            'live_stream_permit' => $permisoStream !== '' ? $permisoStream : 'none',
        ];
    }

    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    private static function obtenerUbicacion(int $idSource, string $territorio): array
    {
        $country = (string) get_post_meta($idSource, '_fnh_country', true);
        $region = (string) get_post_meta($idSource, '_fnh_region', true);
        $city = (string) get_post_meta($idSource, '_fnh_city', true);
        $network = (string) get_post_meta($idSource, '_fnh_network', true);
        if ($country === '' && $region === '' && $city === '' && $network === '') {
            return TerritoryNormalizer::desglosar($territorio);
        }
        return [
            'country' => $country,
            'region' => $region,
            'city' => $city,
            'network' => $network,
        ];
    }
}
