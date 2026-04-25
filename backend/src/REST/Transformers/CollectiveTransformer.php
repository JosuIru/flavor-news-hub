<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

use FlavorNewsHub\Support\TerritoryNormalizer;

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
        $websiteUrl = (string) get_post_meta($idColectivo, '_fnh_website_url', true);
        $flavorUrl = (string) get_post_meta($idColectivo, '_fnh_flavor_url', true);
        $territorio = (string) get_post_meta($idColectivo, '_fnh_territory', true);
        $ubicacion = self::obtenerUbicacion($idColectivo, $territorio);

        $idsSourcesCrudo = get_post_meta($idColectivo, '_fnh_source_ids', true);
        $idsSources = [];
        if (is_array($idsSourcesCrudo)) {
            foreach ($idsSourcesCrudo as $id) {
                $idEntero = is_numeric($id) ? (int) $id : 0;
                if ($idEntero > 0) {
                    $idsSources[] = $idEntero;
                }
            }
        }
        $idsSources = array_values(array_unique($idsSources));

        return [
            'id'          => $idColectivo,
            'slug'        => (string) $post->post_name,
            'name'        => get_the_title($post),
            'description' => (string) apply_filters('the_content', $post->post_content),
            'url'         => (string) get_permalink($post),
            'website_url' => $websiteUrl,
            'flavor_url'  => $flavorUrl,
            'support_url' => (string) get_post_meta($idColectivo, '_fnh_support_url', true),
            'territory'   => $territorio,
            'country'     => $ubicacion['country'],
            'region'      => $ubicacion['region'],
            'city'        => $ubicacion['city'],
            'has_contact' => $emailInterno !== '' || $websiteUrl !== '' || $flavorUrl !== '',
            'verified'    => (bool) get_post_meta($idColectivo, '_fnh_verified', true),
            'topics'      => TopicsHelper::obtenerTopicsDelPost($idColectivo),
            'source_ids'  => $idsSources,
        ];
    }

    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    private static function obtenerUbicacion(int $idColectivo, string $territorio): array
    {
        $country = (string) get_post_meta($idColectivo, '_fnh_country', true);
        $region = (string) get_post_meta($idColectivo, '_fnh_region', true);
        $city = (string) get_post_meta($idColectivo, '_fnh_city', true);
        if ($country === '' && $region === '' && $city === '') {
            return TerritoryNormalizer::desglosar($territorio);
        }
        return [
            'country' => $country,
            'region' => $region,
            'city' => $city,
            'network' => '',
        ];
    }
}
