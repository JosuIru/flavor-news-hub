<?php
declare(strict_types=1);

namespace FlavorNewsHub\Activation;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Database\IngestLogTable;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Options\OptionsRepository;

/**
 * Tareas de activación del plugin.
 *
 * El hook `register_activation_hook` se ejecuta una sola vez al activar el
 * plugin; no pasa por `init` habitual, así que aquí registramos a mano CPTs
 * y taxonomía antes del flush para que los permalinks nuevos queden escritos.
 */
final class Activator
{
    public static function activate(): void
    {
        // Registro manual: la activación corre fuera del ciclo 'init' estándar.
        Source::registrar();
        Item::registrar();
        Collective::registrar();
        Radio::registrar();
        Topic::registrar();

        self::precargarTematicasCanonicas();

        IngestLogTable::crearOActualizar();
        OptionsRepository::asegurarDefaults();

        // `wp_schedule_event()` valida la recurrence contra el filtro
        // `cron_schedules`, y en la request de activación `plugins_loaded`
        // puede no haber corrido aún. Enganchamos el filtro a mano aquí
        // para garantizar que la recurrence existe al agendar.
        add_filter('cron_schedules', [Scheduler::class, 'registrarIntervalo']);
        Scheduler::agendarSiHaceFalta();
        Scheduler::agendarLimpiezaLogs();

        flush_rewrite_rules();
    }

    /**
     * Inserta las 15 temáticas canónicas si aún no existen.
     * Idempotente: reactivar el plugin no duplica términos ni machaca los
     * que el usuario haya añadido manualmente.
     *
     * Es `public` para que los tests puedan repoblar topics en su set_up
     * cuando el wrapper transaccional de `WP_UnitTestCase` los haya
     * revertido entre casos.
     */
    public static function precargarTematicasCanonicas(): void
    {
        foreach (Topic::TEMATICAS_PRECARGADAS as $slugTematica => $etiquetaTematica) {
            $terminoExistente = term_exists($slugTematica, Topic::SLUG);
            if ($terminoExistente !== 0 && $terminoExistente !== null) {
                continue;
            }
            wp_insert_term(
                $etiquetaTematica,
                Topic::SLUG,
                ['slug' => $slugTematica]
            );
        }
    }
}
