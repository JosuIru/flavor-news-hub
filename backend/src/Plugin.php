<?php
declare(strict_types=1);

namespace FlavorNewsHub;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Meta\MetaRegistrar;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Ingest\FeedIngester;
use FlavorNewsHub\CLI\IngestCommand;
use FlavorNewsHub\CLI\ImportSourcesCommand;
use FlavorNewsHub\REST\RestController;
use FlavorNewsHub\Admin\AdminController;
use FlavorNewsHub\Activation\Activator;
use FlavorNewsHub\Database\LogsCleanup;
use FlavorNewsHub\Integration\FlavorPlatformAddon;
use FlavorNewsHub\Shortcodes\Shortcodes;
use FlavorNewsHub\Templates\TemplateRouter;

/**
 * Orquestador principal del plugin.
 *
 * Registra en los hooks correctos los distintos módulos (CPTs, taxonomía,
 * meta fields, y más adelante: cron, REST, admin, plantillas).
 *
 * Patrón singleton a propósito por simplicidad: el plugin tiene un único
 * punto de entrada en WP y no es testable por instanciación múltiple.
 */
final class Plugin
{
    private static ?self $instanciaUnica = null;

    public static function instancia(): self
    {
        if (self::$instanciaUnica === null) {
            self::$instanciaUnica = new self();
        }
        return self::$instanciaUnica;
    }

    private function __construct()
    {
    }

    /**
     * Punto de entrada: engancha cada módulo al hook apropiado.
     */
    public function arrancar(): void
    {
        add_action('init', [$this, 'cargarTraducciones'], 1);

        // Migraciones idempotentes: se ejecutan una vez por marca de
        // option. Las ejecutamos en cada carga del plugin (no sólo en
        // activación) para que usuarios con plugin ya instalado reciban
        // los fixes sin tener que desactivar/reactivar manualmente.
        add_action('init', [Activator::class, 'ejecutarMigracionesPendientes'], 2);

        // Sincronizar páginas frontend auto-generadas tras una
        // actualización: si la versión guardada no coincide con
        // FNH_VERSION, crea páginas que falten y reconcilia slugs
        // raros. Prioridad 3 para que corra después de las
        // migraciones y del registro de CPTs.
        add_action('init', [self::class, 'sincronizarPaginasTrasUpgrade'], 3);

        // Los CPTs deben existir antes de que la taxonomía los referencie.
        add_action('init', [Source::class, 'registrar'], 5);
        add_action('init', [Item::class, 'registrar'], 5);
        add_action('init', [Collective::class, 'registrar'], 5);
        add_action('init', [Radio::class, 'registrar'], 5);

        // Taxonomía y meta fields justo después.
        add_action('init', [Topic::class, 'registrar'], 6);
        add_action('init', [MetaRegistrar::class, 'registrar'], 7);

        // Ingesta: declaración de intervalo y enganche del job.
        add_filter('cron_schedules', [Scheduler::class, 'registrarIntervalo']);
        add_action(Scheduler::HOOK_CRON, [FeedIngester::class, 'ingestarTodasLasFuentesActivas']);

        // REST pública `flavor-news/v1`.
        add_action('rest_api_init', [RestController::class, 'registrar']);

        // Job diario de limpieza de logs antiguos.
        add_action(Scheduler::HOOK_CLEANUP_LOGS, [LogsCleanup::class, 'ejecutar']);

        // Admin (menú, metaboxes, acciones, settings). Los hooks admin_*
        // sólo disparan en backend; registrar siempre es inofensivo.
        AdminController::arrancar();

        // Plantillas web públicas: sustituyen las del tema para los 3 CPTs.
        add_action('template_redirect', [TemplateRouter::class, 'bloquearColectivoNoVerificado']);
        add_filter('template_include', [TemplateRouter::class, 'elegirPlantilla']);

        // Shortcodes para incrustar feeds/radios/vídeos en páginas de WP.
        Shortcodes::registrar();

        // Integración opcional con Flavor Platform: si está activo, nos
        // registramos como addon para aparecer en su dashboard
        // unificado. Si no, este arranque es inerte.
        FlavorPlatformAddon::arrancar();

        // Registro de comandos WP-CLI sólo si estamos en CLI.
        if (defined('WP_CLI') && WP_CLI) {
            \WP_CLI::add_command('flavor-news', IngestCommand::class);
            \WP_CLI::add_command('flavor-news import', ImportSourcesCommand::class);
        }
    }

    /**
     * Carga el textdomain. Ejecutado en `init` prioridad 1 para que esté
     * disponible antes de cualquier llamada a __() desde otros hooks.
     */
    public function cargarTraducciones(): void
    {
        load_plugin_textdomain(
            'flavor-news-hub',
            false,
            dirname(plugin_basename(FNH_PLUGIN_FILE)) . '/languages'
        );
    }

    /**
     * Sincroniza las páginas auto-generadas cuando detecta un salto
     * de versión del plugin: tras una actualización via PUC (o
     * reemplazar zip manualmente), las páginas nuevas introducidas
     * por la nueva versión (ej. TV, Podcasts, Fuentes, Sobre en
     * v0.7.0) no aparecían porque `CreadorPaginas::crearSiNoExisten`
     * sólo se invocaba en `register_activation_hook` — y una
     * actualización no dispara ese hook.
     *
     * La option `fnh_paginas_sincronizadas_version` guarda la última
     * versión con la que se sincronizó. Si no coincide con
     * `FNH_VERSION`, ejecuta el sync y actualiza la marca.
     */
    public static function sincronizarPaginasTrasUpgrade(): void
    {
        $versionSincronizada = (string) get_option('fnh_paginas_sincronizadas_version', '');
        if ($versionSincronizada === FNH_VERSION) {
            return;
        }
        \FlavorNewsHub\Catalog\CreadorPaginas::crearSiNoExisten();
        update_option('fnh_paginas_sincronizadas_version', FNH_VERSION);
    }
}
