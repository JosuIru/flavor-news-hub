<?php
declare(strict_types=1);

namespace FlavorNewsHub\Database;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Options\OptionsRepository;

/**
 * Purga periódica de items antiguos (`fnh_item`) para que la tabla no
 * crezca indefinidamente. Ejecutada desde el mismo cron diario de
 * limpieza de logs (`fnh_cleanup_logs`).
 *
 * Criterios:
 *  - Borra sólo items con `post_date_gmt` más antigua que la retención
 *    configurada (default 90 días, mínimo 7).
 *  - Borra en lotes para evitar timeouts en sitios con historial largo.
 *  - Usa `wp_delete_post($id, true)` → force-delete limpia postmeta y
 *    term relationships automáticamente.
 *
 * Nota: el valor editorial de un titular decae en pocos días. Si algún
 * usuario ha guardado un item en su app, la caché local SQLite del
 * móvil mantiene una copia legible offline — el borrado del backend
 * no afecta a su biblioteca personal.
 */
final class ItemsCleanup
{
    /** Tope de items borrados por ejecución. Evita sorpresas en sitios
     *  con backfill grande: si hay 50k items antiguos, los limpiamos en
     *  varias ejecuciones diarias en vez de uno solo que tarde horas. */
    private const MAXIMO_POR_EJECUCION = 1000;

    /**
     * @return int Número de items borrados en esta ejecución.
     */
    public static function ejecutar(): int
    {
        global $wpdb;

        $diasARetener = (int) (OptionsRepository::todas()['item_retention_days'] ?? 90);
        // Orden importante: 0 = "retención desactivada" y es un valor
        // válido que se acepta desde OptionsRepository. Chequeamos el
        // 0 ANTES de aplicar el mínimo — si no, 0 se elevaba a 7 y la
        // rama de desactivación quedaba inalcanzable.
        if ($diasARetener === 0) {
            return 0;
        }
        if ($diasARetener < OptionsRepository::RETENCION_MINIMA_ITEMS_DIAS) {
            $diasARetener = OptionsRepository::RETENCION_MINIMA_ITEMS_DIAS;
        }

        $idsABorrar = $wpdb->get_col($wpdb->prepare(
            "SELECT ID FROM {$wpdb->posts}
             WHERE post_type = %s
               AND post_status IN ('publish','draft','pending','private','future','trash')
               AND post_date_gmt < DATE_SUB(UTC_TIMESTAMP(), INTERVAL %d DAY)
             LIMIT %d",
            Item::SLUG,
            $diasARetener,
            self::MAXIMO_POR_EJECUCION
        ));

        if (empty($idsABorrar)) {
            return 0;
        }

        $borrados = 0;
        foreach ($idsABorrar as $idPost) {
            $resultado = wp_delete_post((int) $idPost, true);
            if ($resultado !== false && $resultado !== null) {
                $borrados++;
            }
        }
        return $borrados;
    }
}
