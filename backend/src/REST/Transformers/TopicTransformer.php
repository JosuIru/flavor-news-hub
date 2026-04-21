<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST\Transformers;

/**
 * Transformador de temáticas (`fnh_topic`) para la API pública.
 * Devuelve el árbol en plano (cada término con su `parent`); la reconstrucción
 * jerárquica es trivial del lado del cliente si se necesita.
 */
final class TopicTransformer
{
    /**
     * @return array{id:int,name:string,slug:string,parent:int,count:int}
     */
    public static function transformar(\WP_Term $termino): array
    {
        return [
            'id'     => (int) $termino->term_id,
            'name'   => $termino->name,
            'slug'   => $termino->slug,
            'parent' => (int) $termino->parent,
            'count'  => (int) $termino->count,
        ];
    }
}
