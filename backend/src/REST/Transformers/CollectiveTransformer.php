<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

/**
 * Transformador de colectivos (`fnh_collective`) para la API pública.
 *
 * IMPORTANTE: nunca se exponen `_fnh_contact_email` ni `_fnh_submitted_by_email`.
 * Se publica un booleano `has_contact` para que la UI pueda mostrar un botón
 * "Contactar" que abra mailto al email interno sólo si el admin así lo
 * configura en plantillas (capa 5); para apps móviles, el contacto sale por
 * la web del propio colectivo o por su instancia Flavor.
 */
final class CollectiveTransformer
{
    /**
     * @return array<string,mixed>
     */
    public static function transformar(\WP_Post $post): array
    {
        $idColectivo = (int) $post->ID;
        $emailInterno = (string) get_post_meta($idColectivo, '_fnh_contact_email', true);

        return [
            'id'          => $idColectivo,
            'slug'        => (string) $post->post_name,
            'name'        => get_the_title($post),
            'description' => (string) apply_filters('the_content', $post->post_content),
            'url'         => (string) get_permalink($post),
            'website_url' => (string) get_post_meta($idColectivo, '_fnh_website_url', true),
            'flavor_url'  => (string) get_post_meta($idColectivo, '_fnh_flavor_url', true),
            'territory'   => (string) get_post_meta($idColectivo, '_fnh_territory', true),
            'has_contact' => $emailInterno !== '',
            'verified'    => (bool) get_post_meta($idColectivo, '_fnh_verified', true),
            'topics'      => TopicsHelper::obtenerTopicsDelPost($idColectivo),
        ];
    }
}
