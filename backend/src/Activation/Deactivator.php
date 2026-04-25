<?php
declare(strict_types=1);

namespace FlavorNewsHub\Activation;

use FlavorNewsHub\Ingest\Scheduler;

/**
 * Tareas de desactivación.
 *
 * La desactivación NO borra datos: sólo cancela el cron y refresca
 * permalinks para que las rewrites del plugin dejen de resolver.
 *
 * El borrado real de contenidos (CPTs, términos, tabla de logs) se ejecuta
 * en `uninstall.php` y sólo si el usuario lo ha autorizado previamente en
 * la pantalla de Settings del plugin (implementada en la capa de admin).
 */
final class Deactivator
{
    public static function deactivate(): void
    {
        Scheduler::desagendar();
        Scheduler::desagendarLimpiezaLogs();
        Scheduler::desagendarInformeSemanal();
        flush_rewrite_rules();
    }
}
