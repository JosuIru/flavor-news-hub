<?php
declare(strict_types=1);

namespace FlavorNewsHub\CLI;

use FlavorNewsHub\Ingest\FeedIngester;
use FlavorNewsHub\CPT\Source;

/**
 * Comandos WP-CLI del plugin. Registrado en Plugin::arrancar() únicamente
 * cuando la constante `WP_CLI` está definida (ejecución desde CLI).
 *
 * Ejemplos:
 *   wp flavor-news ingest
 *   wp flavor-news ingest --source=42
 */
final class IngestCommand
{
    /**
     * Ingesta feeds ahora mismo, sin esperar al cron.
     *
     * ## OPTIONS
     *
     * [--source=<id>]
     * : ID de la fuente a ingestar. Si no se indica, procesa todas las activas.
     *
     * ## EXAMPLES
     *
     *     wp flavor-news ingest
     *     wp flavor-news ingest --source=42
     *
     * @param array<int,string>    $argumentosPosicionales
     * @param array<string,string> $argumentosConNombre
     */
    public function ingest($argumentosPosicionales, $argumentosConNombre): void
    {
        if (isset($argumentosConNombre['source'])) {
            $this->ingestarUnaFuente((int) $argumentosConNombre['source']);
            return;
        }
        $this->ingestarTodas();
    }

    private function ingestarUnaFuente(int $idFuente): void
    {
        if ($idFuente <= 0) {
            \WP_CLI::error('--source debe ser un ID positivo.');
        }
        $postFuente = get_post($idFuente);
        if (!$postFuente || $postFuente->post_type !== Source::SLUG) {
            \WP_CLI::error("La fuente #{$idFuente} no existe.");
        }

        \WP_CLI::log("Ingestando fuente #{$idFuente}: {$postFuente->post_title}");
        $resumen = FeedIngester::ingestarFuente($idFuente);

        if ($resumen['error'] !== '') {
            \WP_CLI::error($resumen['error']);
        }
        \WP_CLI::success(sprintf(
            'Ingesta OK. Nuevos: %d. Descartados por dedupe: %d. Log ID: %d.',
            $resumen['items_new'],
            $resumen['items_skipped'],
            $resumen['log_id']
        ));
    }

    private function ingestarTodas(): void
    {
        \WP_CLI::log('Ingestando todas las fuentes activas…');
        $resumen = FeedIngester::ingestarTodasLasFuentesActivas();

        if (!empty($resumen['skipped'])) {
            \WP_CLI::warning($resumen['reason']);
            return;
        }

        \WP_CLI::success(sprintf(
            'Procesadas %d fuentes. Nuevos: %d. Descartados: %d. Errores: %d.',
            $resumen['sources_processed'],
            $resumen['items_new_total'],
            $resumen['items_skipped_total'],
            count($resumen['errors'])
        ));
        foreach ($resumen['errors'] as $detalleError) {
            \WP_CLI::log(sprintf(' - Fuente #%d: %s', $detalleError['source_id'], $detalleError['message']));
        }
    }

    /**
     * Detecta sources publicadas con el mismo `_fnh_feed_url`. Útil
     * para diagnosticar el ruido de duplicados que aparece en la
     * pantalla "Estado de fuentes" cuando un import antiguo dejó
     * varios posts apuntando al mismo RSS.
     *
     * Por defecto sólo lista. Con `--desactivar` mantiene activa la
     * fuente con más items totales en cada grupo y desactiva el resto
     * (`_fnh_active=0`). No borra nada — los posts duplicados se
     * pueden recuperar editando el meta a mano si hace falta.
     *
     * ## OPTIONS
     *
     * [--desactivar]
     * : Si se pasa, desactiva los duplicados (mantiene el más activo).
     *
     * ## EXAMPLES
     *
     *     wp flavor-news duplicates
     *     wp flavor-news duplicates --desactivar
     *
     * @param array<int,string>    $argumentosPosicionales
     * @param array<string,string> $argumentosConNombre
     */
    public function duplicates($argumentosPosicionales, $argumentosConNombre): void
    {
        $debeDesactivar = isset($argumentosConNombre['desactivar']);
        global $wpdb;
        $filas = $wpdb->get_results($wpdb->prepare(
            "SELECT pm.meta_value AS feed_url, p.ID AS source_id, p.post_title AS nombre,
                    (SELECT COUNT(*) FROM {$wpdb->postmeta} pmi
                       INNER JOIN {$wpdb->posts} pi ON pi.ID = pmi.post_id
                       WHERE pmi.meta_key = '_fnh_source_id' AND pmi.meta_value = p.ID
                         AND pi.post_status = 'publish'
                    ) AS total_items
             FROM {$wpdb->postmeta} pm
             INNER JOIN {$wpdb->posts} p ON p.ID = pm.post_id
             WHERE pm.meta_key = '_fnh_feed_url'
               AND pm.meta_value <> ''
               AND p.post_type = %s
               AND p.post_status = 'publish'
             ORDER BY pm.meta_value, total_items DESC, p.ID ASC",
            Source::SLUG
        ), ARRAY_A);
        $filas = is_array($filas) ? $filas : [];

        $grupos = [];
        foreach ($filas as $fila) {
            $url = (string) $fila['feed_url'];
            $grupos[$url][] = $fila;
        }
        $grupos = array_filter($grupos, static fn(array $g): bool => count($g) > 1);

        if (empty($grupos)) {
            \WP_CLI::success('No hay duplicados por feed_url.');
            return;
        }

        \WP_CLI::log(sprintf('Encontrados %d grupos de duplicados:', count($grupos)));
        $totalDesactivados = 0;
        foreach ($grupos as $url => $grupo) {
            \WP_CLI::log('');
            \WP_CLI::log('  ' . $url);
            foreach ($grupo as $indice => $fila) {
                $marca = $indice === 0 ? '★' : ' ';
                \WP_CLI::log(sprintf(
                    '    %s #%d  %s  (items: %d)',
                    $marca,
                    (int) $fila['source_id'],
                    $fila['nombre'],
                    (int) $fila['total_items']
                ));
            }
            if ($debeDesactivar) {
                // Mantener el primero (más items) y desactivar el resto.
                foreach (array_slice($grupo, 1) as $fila) {
                    update_post_meta((int) $fila['source_id'], '_fnh_active', false);
                    $totalDesactivados++;
                }
            }
        }

        if ($debeDesactivar) {
            \WP_CLI::success(sprintf(
                'Desactivadas %d fuentes duplicadas. La principal (★) de cada grupo queda activa.',
                $totalDesactivados
            ));
        } else {
            \WP_CLI::log('');
            \WP_CLI::log('Vuelve a ejecutar con --desactivar para desactivar las duplicadas.');
        }
    }
}
