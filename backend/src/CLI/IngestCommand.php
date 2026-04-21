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
}
