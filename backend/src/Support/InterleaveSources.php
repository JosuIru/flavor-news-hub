<?php
declare(strict_types=1);

namespace FlavorNewsHub\Support;

/**
 * Reordena una lista de posts de tipo `fnh_item` para que las fuentes
 * con mucha frecuencia de publicación no monopolicen la página.
 *
 * Problema antiguo (un solo medio): cuando un medio publicaba varias
 * piezas seguidas (Berria sube 5 columnas en 10 min) salían apiñadas.
 *
 * Problema nuevo detectado en pestaña Vídeos: un canal muy prolífico
 * como MakerTube llenaba 40 de los 50 últimos items y los canales
 * pequeños (Miguel Ruiz Calvo, Tu Profe de RI…) no aparecían nunca,
 * porque el interleave de "máximo 2 consecutivos" no podía
 * ayudar — todos los items eran del mismo source.
 *
 * Algoritmo round-robin con ventana ampliada:
 *  1. El caller pasa una ventana mayor que `per_page` (típico 3×).
 *  2. Agrupamos posts por source manteniendo orden cronológico.
 *  3. Round-robin: 1 item por source en cada vuelta, hasta agotar la
 *     ventana. Las fuentes con más items irán al final de cada vuelta.
 *
 * Resultado: dentro de la ventana, cada source aporta items repartidos
 * (no en racha), y los canales con poca frecuencia no quedan ocultos
 * por uno prolífico.
 */
final class InterleaveSources
{
    /**
     * @param array<int,\WP_Post> $posts
     * @return array<int,\WP_Post>
     */
    public static function aplicar(array $posts): array
    {
        if (count($posts) < 3) {
            return array_values($posts);
        }

        // Agrupar por source preservando el orden cronológico recibido.
        // Cache para no leer post_meta dos veces por post.
        $gruposPorSource = [];
        $ordenLlegadaPorSource = [];
        foreach ($posts as $post) {
            if (!$post instanceof \WP_Post) continue;
            $idSource = (int) get_post_meta((int) $post->ID, '_fnh_source_id', true);
            if (!isset($gruposPorSource[$idSource])) {
                $gruposPorSource[$idSource] = [];
                $ordenLlegadaPorSource[$idSource] = count($ordenLlegadaPorSource);
            }
            $gruposPorSource[$idSource][] = $post;
        }

        if (count($gruposPorSource) <= 1) {
            return array_values($posts);
        }

        // Round-robin: tomamos 1 item por source en cada vuelta. Para
        // estabilidad, las fuentes se ordenan por aparición original
        // (la primera en publicar el item más reciente va primero).
        // Eso preserva un sesgo cronológico aproximado.
        $idsOrdenados = array_keys($ordenLlegadaPorSource);
        usort($idsOrdenados, fn($a, $b) => $ordenLlegadaPorSource[$a] - $ordenLlegadaPorSource[$b]);

        $resultado = [];
        $hayMas = true;
        while ($hayMas) {
            $hayMas = false;
            foreach ($idsOrdenados as $idSource) {
                if (!empty($gruposPorSource[$idSource])) {
                    $resultado[] = array_shift($gruposPorSource[$idSource]);
                    if (!empty($gruposPorSource[$idSource])) {
                        $hayMas = true;
                    }
                }
            }
        }

        return $resultado;
    }
}
