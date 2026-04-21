<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

use FlavorNewsHub\Taxonomy\Topic;

/**
 * Utilidad compartida: obtener los topics asociados a un post en el formato
 * que emite la API pública.
 */
final class TopicsHelper
{
    /**
     * @return list<array{id:int,name:string,slug:string}>
     */
    public static function obtenerTopicsDelPost(int $idPost): array
    {
        $terminos = wp_get_object_terms($idPost, Topic::SLUG);
        if (is_wp_error($terminos) || empty($terminos)) {
            return [];
        }
        $salida = [];
        foreach ($terminos as $termino) {
            $salida[] = [
                'id'   => (int) $termino->term_id,
                'name' => $termino->name,
                'slug' => $termino->slug,
            ];
        }
        return $salida;
    }
}
