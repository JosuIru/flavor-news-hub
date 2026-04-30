<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Source;

/**
 * Coordina el ciclo de vida items ⇄ source: cuando se manda a la
 * papelera una `fnh_source`, sus `fnh_item` la siguen automáticamente;
 * al restaurar la source, los items que se trashearon por este
 * mecanismo vuelven a publicarse.
 *
 * Por qué hace falta:
 *  - El cron de ingesta filtra por `post_status='publish'` AND
 *    (`_fnh_active=1` OR sin meta), así que al trashear la source,
 *    el cron deja de tocar su feed. Pero los items ya ingestados
 *    siguen en la BD como `publish`, listos para aparecer en
 *    `/items` y en la app — el admin pensaba que había borrado
 *    "Suba", pero las noticias seguían apareciendo porque su
 *    fuente desapareció pero los items no.
 *
 *  - Sin esto, la única salida era un `wp post delete --force` por
 *    CLI o ir a wp-admin a borrar items uno a uno. Mal UX.
 *
 * Marcado con meta `_fnh_trashed_by_source`:
 *  - Diferencia los items que trasheamos por este flujo de los que
 *    el admin trasheó manualmente. Sólo restauramos al hacer untrash
 *    los que tienen esa meta apuntando a esta source. Si el admin
 *    había borrado un item concreto a mano, no se lo "des-borra"
 *    automáticamente cuando recupera la source.
 *
 * Migración una vez por versión: en instancias preexistentes hay
 * items huérfanos (su source ya estaba en trash o no existe). El
 * `purgarHuerfanosUnaVez()` los manda a la papelera marcados, así el
 * mecanismo de untrash puede recuperarlos si la source vuelve.
 */
final class ItemsHuerfanos
{
    private const META_TRASHED_POR_SOURCE = '_fnh_trashed_por_source';
    private const OPCION_PURGA_INICIAL = 'fnh_huerfanos_purgados_v1';

    /**
     * Engancha los hooks. Llamar desde `Plugin::arrancar()`.
     *
     * Prioridad 20 para correr después de `SeedExcluidos` (que va a
     * 10 por defecto) — el orden no afecta a la corrección, pero
     * mantenerlos consecutivos hace los logs más predecibles si hay
     * que diagnosticar.
     */
    public static function registrarHooks(): void
    {
        add_action('wp_trash_post', [self::class, 'alTrashSource'], 20);
        add_action('before_delete_post', [self::class, 'alTrashSource'], 20);
        add_action('untrashed_post', [self::class, 'alUntrashSource'], 20);
    }

    /** @internal */
    public static function alTrashSource(int $idPost): void
    {
        $post = get_post($idPost);
        if (!$post || $post->post_type !== Source::SLUG) {
            return;
        }
        foreach (self::idsItemsDeFuente($idPost, 'publish') as $idItem) {
            update_post_meta($idItem, self::META_TRASHED_POR_SOURCE, (string) $idPost);
            wp_trash_post($idItem);
        }
    }

    /** @internal */
    public static function alUntrashSource(int $idPost): void
    {
        $post = get_post($idPost);
        if (!$post || $post->post_type !== Source::SLUG) {
            return;
        }
        foreach (self::idsItemsDeFuente($idPost, 'trash') as $idItem) {
            $idMarcado = (string) get_post_meta($idItem, self::META_TRASHED_POR_SOURCE, true);
            if ($idMarcado !== (string) $idPost) {
                // Trasheado a mano por el admin: no lo "des-borramos"
                // automáticamente — respetamos su decisión.
                continue;
            }
            wp_untrash_post($idItem);
            delete_post_meta($idItem, self::META_TRASHED_POR_SOURCE);
        }
    }

    /**
     * Manda a la papelera todos los items cuyo `_fnh_source_id`
     * apunta a una source que ya no existe o está en papelera. Usa
     * SQL directo (millones de items hacen `WP_Query` impracticable).
     *
     * Idempotente: marca con `wp_options::fnh_huerfanos_purgados_v1='1'`
     * y no se vuelve a ejecutar en la misma instalación. Si en el
     * futuro hay otra ola de huérfanos, basta cambiar la versión de
     * la opción (`_v2`) para forzar otra pasada controlada.
     *
     * Llamado desde `Plugin::sincronizarCatalogoTrasUpgrade()`.
     */
    public static function purgarHuerfanosUnaVez(): void
    {
        if ((string) get_option(self::OPCION_PURGA_INICIAL, '') === '1') {
            return;
        }

        global $wpdb;
        $tipoItem = Item::SLUG;
        $tipoSource = Source::SLUG;

        // Items publicados cuyo `_fnh_source_id` no apunta a una
        // source válida (existe + es del tipo correcto + estado
        // publish/draft/pending). Trash / inexistente cuentan como
        // huérfano.
        $idsHuerfanos = $wpdb->get_col($wpdb->prepare(
            "SELECT pi.ID
             FROM {$wpdb->posts} pi
             INNER JOIN {$wpdb->postmeta} pm ON pm.post_id = pi.ID
             WHERE pi.post_type = %s
               AND pi.post_status = 'publish'
               AND pm.meta_key = '_fnh_source_id'
               AND NOT EXISTS (
                  SELECT 1 FROM {$wpdb->posts} ps
                  WHERE ps.ID = pm.meta_value
                    AND ps.post_type = %s
                    AND ps.post_status IN ('publish','draft','pending')
               )",
            $tipoItem,
            $tipoSource
        ));

        foreach ($idsHuerfanos as $idCrudo) {
            $idItem = (int) $idCrudo;
            if ($idItem <= 0) {
                continue;
            }
            $idSourceFantasma = (int) get_post_meta($idItem, '_fnh_source_id', true);
            if ($idSourceFantasma > 0) {
                // Marcamos para que `alUntrashSource` pueda
                // recuperarlo si la source vuelve. Si la source ya
                // no existe físicamente, la meta queda como rastro.
                update_post_meta($idItem, self::META_TRASHED_POR_SOURCE, (string) $idSourceFantasma);
            }
            wp_trash_post($idItem);
        }

        update_option(self::OPCION_PURGA_INICIAL, '1', false);
    }

    /**
     * IDs de items que apuntan a una source concreta, filtrando por
     * estado del item.
     *
     * @return list<int>
     */
    private static function idsItemsDeFuente(int $idFuente, string $estadoItem): array
    {
        $consulta = new \WP_Query([
            'post_type'      => Item::SLUG,
            'post_status'    => $estadoItem,
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [
                [
                    'key'     => '_fnh_source_id',
                    'value'   => (string) $idFuente,
                    'compare' => '=',
                ],
            ],
        ]);
        return array_map('intval', $consulta->posts);
    }
}
