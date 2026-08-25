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
    /**
     * `_fnh_source_id` de una tanda de posts en UNA consulta.
     *
     * `get_post_meta` por post sólo es barato si WP_Query ha precargado
     * el meta cache, y quien usa una ventana ampliada (ver
     * `ItemsEndpoint` con `max_per_source`) lo desactiva a propósito:
     * descarta ~3/4 de los posts y precargar todas sus metas es tirar
     * trabajo. Aquí pedimos sólo la clave que necesitamos, de golpe.
     *
     * @param array<int,\WP_Post> $posts
     * @return array<int,int> post_id → source_id
     */
    private static function sourceIdsDe(array $posts): array
    {
        $ids = [];
        foreach ($posts as $post) {
            if ($post instanceof \WP_Post) {
                $ids[] = (int) $post->ID;
            }
        }
        if (empty($ids)) {
            return [];
        }
        global $wpdb;
        // Sin $wpdb (tests unitarios puros) caemos a get_post_meta, que
        // allí está stubeado.
        if (!isset($wpdb)) {
            $mapa = [];
            foreach ($ids as $id) {
                $mapa[$id] = (int) get_post_meta($id, '_fnh_source_id', true);
            }
            return $mapa;
        }
        $placeholders = implode(',', array_fill(0, count($ids), '%d'));
        $filas = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT post_id, meta_value FROM {$wpdb->postmeta}
                 WHERE meta_key = '_fnh_source_id' AND post_id IN ($placeholders)",
                ...$ids
            ),
            ARRAY_A
        ) ?: [];
        $mapa = [];
        foreach ($filas as $fila) {
            $mapa[(int) $fila['post_id']] = (int) $fila['meta_value'];
        }
        return $mapa;
    }

    public static function aplicar(array $posts): array
    {
        if (count($posts) < 3) {
            return array_values($posts);
        }

        // Agrupar por source preservando el orden cronológico recibido.
        $sourcePorPost = self::sourceIdsDe($posts);
        $gruposPorSource = [];
        $ordenLlegadaPorSource = [];
        foreach ($posts as $post) {
            if (!$post instanceof \WP_Post) continue;
            $idSource = $sourcePorPost[(int) $post->ID] ?? 0;
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

    /**
     * Recorta la lista a `$limite` items con un tope de `$topePorSource`
     * por medio, y después la intercala con [aplicar].
     *
     * Pensado para consumidores que enseñan "lo último" en un espacio
     * pequeño (widget de podcasts, pestaña Podcasts de la app): cuando
     * una fuente muy prolífica llena la ventana cronológica entera, el
     * interleave solo no ayuda — no hay otras fuentes dentro de la
     * página que intercalar. El caller debe pasar una ventana mayor que
     * `$limite` (típico 3-4×) para que las fuentes menos frecuentes
     * entren en ella.
     *
     * Igual que en el widget Android (`repartirEntreFuentes`): primero
     * los N más recientes de cada medio, y si con eso no se llena el
     * cupo, segunda pasada rellenando con los descartados en orden —
     * mejor una página llena con repeticiones que una a medias cuando
     * hay pocas fuentes.
     *
     * @param array<int,\WP_Post> $posts ventana ordenada por fecha DESC
     * @return array<int,\WP_Post>
     */
    public static function conTopePorSource(array $posts, int $topePorSource, int $limite): array
    {
        if ($topePorSource < 1 || $limite < 1) {
            return self::aplicar(array_slice(array_values($posts), 0, max(0, $limite)));
        }
        $seleccionados = [];
        $sobrantes = [];
        $cuentaPorSource = [];
        $sourcePorPost = self::sourceIdsDe($posts);
        foreach ($posts as $post) {
            if (!$post instanceof \WP_Post) continue;
            if (count($seleccionados) >= $limite) break;
            $idSource = $sourcePorPost[(int) $post->ID] ?? 0;
            $yaPuestos = $cuentaPorSource[$idSource] ?? 0;
            if ($yaPuestos >= $topePorSource) {
                $sobrantes[] = $post;
                continue;
            }
            $cuentaPorSource[$idSource] = $yaPuestos + 1;
            $seleccionados[] = $post;
        }
        foreach ($sobrantes as $post) {
            if (count($seleccionados) >= $limite) break;
            $seleccionados[] = $post;
        }
        return self::aplicar($seleccionados);
    }
}
