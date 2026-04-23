<?php
declare(strict_types=1);

namespace FlavorNewsHub\Support;

/**
 * Reordena una lista de posts de tipo `fnh_item` para evitar rachas
 * largas de items consecutivos del mismo medio.
 *
 * Problema: cuando un medio publica varias piezas seguidas (p.ej. Berria
 * sube 5 columnas de opinión en 10 minutos), al ordenar por fecha
 * descendente el usuario ve las 5 apiñadas al principio y parece que
 * "sólo hay Berria". Queremos mostrar como mucho 2 consecutivas por
 * source sin perder del todo el orden cronológico.
 *
 * Algoritmo: recorrido in-place. Cuando detecta 3+ consecutivas del
 * mismo source terminando en la posición i, busca hacia adelante el
 * primer post con un source distinto y lo intercambia con el de
 * posición i. Preserva aproximadamente el orden por fecha: sólo
 * adelanta posts como mucho tanto como la racha a romper, y sólo cuando
 * realmente hay acumulación.
 */
final class InterleaveSources
{
    /** Máximo de posts consecutivos del mismo source antes de des-apelmazar. */
    private const MAX_CONSECUTIVOS = 2;

    /**
     * @param array<int,\WP_Post> $posts
     * @return array<int,\WP_Post>
     */
    public static function aplicar(array $posts): array
    {
        if (count($posts) < self::MAX_CONSECUTIVOS + 2) {
            return array_values($posts);
        }

        $resultado = array_values($posts);
        // Cache source_id por post ID para evitar llamar a get_post_meta
        // varias veces al mismo post dentro del bucle.
        $cacheSources = [];
        $obtenerSource = static function (\WP_Post $post) use (&$cacheSources): int {
            $idPost = (int) $post->ID;
            if (!array_key_exists($idPost, $cacheSources)) {
                $cacheSources[$idPost] = (int) get_post_meta($idPost, '_fnh_source_id', true);
            }
            return $cacheSources[$idPost];
        };

        $total = count($resultado);
        for ($i = self::MAX_CONSECUTIVOS; $i < $total; $i++) {
            $sourceActual = $obtenerSource($resultado[$i]);
            // Cuenta cuántos anteriores contiguos son del mismo source.
            $contiguos = 1;
            for ($j = $i - 1; $j >= 0; $j--) {
                if ($obtenerSource($resultado[$j]) !== $sourceActual) {
                    break;
                }
                $contiguos++;
            }
            if ($contiguos <= self::MAX_CONSECUTIVOS) {
                continue;
            }
            // Buscar el siguiente post con source distinto y traerlo aquí.
            $indiceAlternativo = null;
            for ($k = $i + 1; $k < $total; $k++) {
                if ($obtenerSource($resultado[$k]) !== $sourceActual) {
                    $indiceAlternativo = $k;
                    break;
                }
            }
            if ($indiceAlternativo === null) {
                // Todos los restantes son del mismo source: no podemos
                // des-apelmazar más sin sacarnos posts de la nada. Dejamos
                // la cola tal cual.
                break;
            }
            // Swap: el post alternativo sube a $i, el del racha baja a $k.
            $temp = $resultado[$i];
            $resultado[$i] = $resultado[$indiceAlternativo];
            $resultado[$indiceAlternativo] = $temp;
        }

        return $resultado;
    }
}
