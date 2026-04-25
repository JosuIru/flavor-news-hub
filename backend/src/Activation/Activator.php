<?php
declare(strict_types=1);

namespace FlavorNewsHub\Activation;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Catalog\CreadorPaginas;
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

        // Migraciones idempotentes.
        self::ejecutarMigracionesPendientes();

        // Crea las 4 páginas frontend (Noticias / Radios / Vídeos /
        // Colectivos) con shortcode dentro. Si Flavor Platform + VBP
        // están disponibles, usa su endpoint styled para wrap visual;
        // si no, páginas WP planas. Idempotente: `_fnh_pagina_auto`
        // evita recrearlas.
        CreadorPaginas::crearSiNoExisten();

        // Las rewrite rules de los CPTs /n /f /c necesitan que esta
        // función corra tras `Item/Source/Collective::registrar()`,
        // que ya sucedió arriba — `flush_rewrite_rules()` al final
        // del método las graba.

        // `wp_schedule_event()` valida la recurrence contra el filtro
        // `cron_schedules`, y en la request de activación `plugins_loaded`
        // puede no haber corrido aún. Enganchamos el filtro a mano aquí
        // para garantizar que la recurrence existe al agendar.
        add_filter('cron_schedules', [Scheduler::class, 'registrarIntervalo']);
        Scheduler::agendarSiHaceFalta();
        Scheduler::agendarLimpiezaLogs();
        Scheduler::agendarInformeSemanal();

        flush_rewrite_rules();
    }

    /**
     * Inserta las 18 temáticas canónicas si aún no existen.
     * Idempotente: reactivar el plugin no duplica términos ni machaca los
     * que el usuario haya añadido manualmente.
     *
     * Es `public` para que los tests puedan repoblar topics en su set_up
     * cuando el wrapper transaccional de `WP_UnitTestCase` los haya
     * revertido entre casos.
     */
    /**
     * Punto único para lanzar todas las migraciones pendientes — se
     * llama tanto desde `activate()` como desde `init` del Plugin, así
     * que usuarios que actualizan el plugin sin reactivar reciben los
     * fixes automáticamente. Cada migración se auto-gestiona con un
     * flag de option y no vuelve a ejecutarse tras finalizar.
     */
    public static function ejecutarMigracionesPendientes(): void
    {
        self::migrarTimestampsPublicacion();
    }

    /**
     * Rellena `_fnh_published_at_ts` (Unix int) a partir del ISO
     * `_fnh_published_at` en items ya ingestados. Idempotente via
     * option flag — no vuelve a correr una vez terminada.
     */
    private static function migrarTimestampsPublicacion(): void
    {
        $claveFlag = 'fnh_mig_published_at_ts_v1';
        if (get_option($claveFlag) === 'done') {
            return;
        }
        global $wpdb;
        // Slug del CPT Item en runtime. Evitamos import para no acoplar.
        $tabla = $wpdb->postmeta;
        // Buscamos items sin el nuevo meta y con el antiguo presente.
        $filas = $wpdb->get_results(
            "SELECT pm1.post_id AS id, pm1.meta_value AS iso
             FROM {$tabla} pm1
             LEFT JOIN {$tabla} pm2
               ON pm2.post_id = pm1.post_id
              AND pm2.meta_key = '_fnh_published_at_ts'
             WHERE pm1.meta_key = '_fnh_published_at'
               AND pm2.meta_id IS NULL
             LIMIT 5000"
        );
        foreach ($filas as $fila) {
            $ts = (int) strtotime((string) $fila->iso);
            if ($ts > 0) {
                update_post_meta((int) $fila->id, '_fnh_published_at_ts', $ts);
            }
        }
        update_option($claveFlag, 'done', false);
    }

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
