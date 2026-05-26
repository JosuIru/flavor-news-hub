<?php
declare(strict_types=1);

namespace FlavorNewsHub;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Meta\MetaRegistrar;
use FlavorNewsHub\Catalog\CatalogoPorDefecto;
use FlavorNewsHub\Catalog\ImportadorCatalogo;
use FlavorNewsHub\Catalog\ItemsHuerfanos;
use FlavorNewsHub\Catalog\SeedExcluidos;
use FlavorNewsHub\Ingest\Scheduler;
use FlavorNewsHub\Ingest\FeedIngester;
use FlavorNewsHub\CLI\IngestCommand;
use FlavorNewsHub\CLI\ImportSourcesCommand;
use FlavorNewsHub\REST\RestController;
use FlavorNewsHub\Admin\AdminController;
use FlavorNewsHub\Activation\Activator;
use FlavorNewsHub\Database\LogsCleanup;
use FlavorNewsHub\Database\ItemsCleanup;
use FlavorNewsHub\Database\UsoApiTable;
use FlavorNewsHub\Database\UsoApiCleanup;
use FlavorNewsHub\Stats\UsoTracker;
use FlavorNewsHub\Stats\Recopilador;
use FlavorNewsHub\Admin\Pages\EstadisticasPage;
use FlavorNewsHub\Notifications\WeeklyReport;
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
        // Auto-invalidación de OPcache tras un upgrade del plugin. Sin
        // esto, hostings con `opcache.validate_timestamps=0` siguen
        // ejecutando el bytecode de la versión anterior aunque
        // wp-admin → Plugins muestre la nueva — síntoma típico:
        // wp-admin reporta v0.16.0 pero el cron ejecuta el código de
        // v0.15.9. Comparamos contra una option escrita en cada
        // arranque; si la versión runtime difiere, llamamos
        // `opcache_reset()` y registramos. Coste: una option lookup
        // por request, despreciable.
        self::resetearOpcacheSiCambioVersion();

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

        // Catálogo bundleado: en una actualización, añadimos al
        // directorio cualquier fuente/radio/colectivo nuevo y
        // reponemos temáticas canónicas faltantes.
        add_action('init', [self::class, 'sincronizarCatalogoTrasUpgrade'], 8);

        // Ingesta: declaración de intervalo y enganche del job.
        // Patrón clásico de WordPress: una vez al cron, todas las
        // fuentes en bucle síncrono dentro del mismo sub-request.
        // Funcionaba bien antes de v0.15.5; volvemos a él tras una
        // serie de "optimizaciones" (cadena de eslabones, spawn_cron
        // por fuente, locks atómicos) que en este hosting introducían
        // overhead de bootstrap por sub-request mayor que la propia
        // ingesta.
        add_filter('cron_schedules', [Scheduler::class, 'registrarIntervalo']);
        add_action(Scheduler::HOOK_CRON, [FeedIngester::class, 'ingestarTodasLasFuentesActivas']);

        // Precalentado de los transients que alimentan la pestaña
        // Sistema → Descargas. Los enganchamos al MISMO cron de
        // ingesta con prioridad 20 (la ingesta corre en 10), de
        // modo que después de cada ronda de ingesta:
        //   - el bundle de stats internas refleja los items recién
        //     entrados,
        //   - el bundle de descargas de GitHub Releases ya está en
        //     el transient.
        // Sin esto, la primera visita admin tras la caducidad (1h)
        // pagaba el HTTP a api.github.com (hasta 10s de timeout) más
        // las subqueries correlacionadas del Recopilador.
        add_action(Scheduler::HOOK_CRON, [Recopilador::class, 'precalentarCacheStatsAdmin'], 20);
        add_action(Scheduler::HOOK_CRON, [EstadisticasPage::class, 'precalentarCacheDescargas'], 20);
        // Refresco en segundo plano del bundle de descargas: lo programa
        // el render (evento one-off) cuando encuentra el caché frío, para
        // no bloquear la pantalla esperando a api.github.com.
        add_action(EstadisticasPage::HOOK_REFRESCO_BG, [EstadisticasPage::class, 'precalentarCacheDescargas']);
        // Cache de la pestaña "Estado de fuentes" — purgamos al final de
        // cada ronda para que la próxima visita admin vea datos frescos.
        add_action(Scheduler::HOOK_CRON, [\FlavorNewsHub\Admin\Pages\EstadoFuentesPage::class, 'purgarCache'], 30);

        // REST pública `flavor-news/v1`.
        add_action('rest_api_init', [RestController::class, 'registrar']);

        // Tracker anónimo de uso de la API. Se engancha post-dispatch
        // para no añadir latencia al request real. Sin IPs, sin cookies:
        // sólo (día, endpoint, hash MD5 truncado del UA) — ver
        // `UsoTracker` y `UsoApiTable` para la justificación de privacidad.
        add_filter('rest_post_dispatch', [UsoTracker::class, 'registrarSiAplica'], 10, 3);

        // Job diario: limpieza de logs antiguos + purga de noticias que
        // excedan la retención (default 90 días) + limpieza de la tabla
        // de uso de la API (retención fija 90 días). Comparten el mismo
        // hook diario para no duplicar eventos en wp-cron.
        add_action(Scheduler::HOOK_CLEANUP_LOGS, [LogsCleanup::class, 'ejecutar']);
        add_action(Scheduler::HOOK_CLEANUP_LOGS, [ItemsCleanup::class, 'ejecutar']);
        add_action(Scheduler::HOOK_CLEANUP_LOGS, [UsoApiCleanup::class, 'ejecutar']);
        // Tras purgar logs antiguos, los rankings cacheados en
        // `/diagnostics` (top errores 7d / latencia 7d) podrían reflejar
        // filas ya borradas. Borramos su transient para que la próxima
        // petición recalcule sobre datos vigentes.
        add_action(Scheduler::HOOK_CLEANUP_LOGS, static function (): void {
            delete_transient(\FlavorNewsHub\REST\DiagnosticsEndpoint::TRANSIENT_TOP_METRICS);
        }, 50);

        // Job semanal: informe con stats de feeds (top activos, muertos,
        // errores, propuestas pendientes). Enganchado siempre — la propia
        // tarea decide si enviar según `weekly_report_enabled`.
        add_action(Scheduler::HOOK_WEEKLY_REPORT, [WeeklyReport::class, 'ejecutar']);
        // Asegura que el evento existe en wp-cron (idempotente). Útil
        // para usuarios que ya tienen el plugin instalado y han hecho
        // upgrade sin reactivar — el `Activator::activate` no corre en
        // este escenario, así que sin esta llamada el informe nunca
        // queda agendado.
        add_action('init', [Scheduler::class, 'agendarInformeSemanal'], 9);

        // Lista de slugs excluidos del seed: cuando el admin borra una
        // source/radio/collective desde wp-admin, la marcamos para que
        // el sync del catálogo en futuros upgrades NO la vuelva a crear.
        SeedExcluidos::registrarHooks();

        // Cuando se manda a la papelera una `fnh_source`, mandamos
        // también sus `fnh_item` — sin esto los items quedaban
        // sueltos en BD y seguían apareciendo en /items aunque el
        // admin pensara haber "borrado" la fuente.
        ItemsHuerfanos::registrarHooks();

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
        // Asegura que las tablas propias existan cuando un usuario
        // actualiza el plugin sin desactivar/reactivar — `Activator::activate`
        // sólo corre en la activación inicial. `dbDelta` es idempotente.
        \FlavorNewsHub\Database\IngestLogTable::crearOActualizar();
        UsoApiTable::crearOActualizar();
        // Invalida el cache de la release de GitHub: si el usuario acaba
        // de instalar un plugin nuevo es MUY probable que también haya
        // un APK nuevo anunciable — no tiene sentido seguir sirviendo
        // la respuesta cacheada de la release anterior durante 6h más.
        delete_transient('fnh_app_update_cache');
        delete_transient('fnh_app_update_cache_beta');
        // Limpia los transients de SimplePie (`feed_<hash>` /
        // `feed_mod_<hash>`) que WordPress crea con TTL 12h por
        // defecto. Desde v0.9.10 usamos TTL 10min, pero los transients
        // escritos con el TTL anterior siguen válidos hasta caducar
        // y hacen que fetch_feed devuelva contenido viejo durante
        // horas. Tras una actualización de plugin los borramos una
        // vez para que la próxima ingesta descargue fresco.
        global $wpdb;
        $wpdb->query(
            "DELETE FROM {$wpdb->options}
             WHERE option_name LIKE '\\_transient\\_feed\\_%'
                OR option_name LIKE '\\_transient\\_timeout\\_feed\\_%'
                OR option_name LIKE '\\_transient\\_feed\\_mod\\_%'
                OR option_name LIKE '\\_transient\\_timeout\\_feed\\_mod\\_%'"
        );
        update_option('fnh_paginas_sincronizadas_version', FNH_VERSION);
    }

    /**
     * Sincroniza el catálogo bundleado con la instancia WP cuando el
     * plugin cambia de versión. Importa fuentes, radios y colectivos
     * nuevos sin pisar los ya existentes, y repone las temáticas
     * canónicas nuevas.
     */
    public static function sincronizarCatalogoTrasUpgrade(): void
    {
        $versionSincronizada = (string) get_option('fnh_catalogo_sincronizado_version', '');
        if ($versionSincronizada === FNH_VERSION) {
            return;
        }

        Activator::precargarTematicasCanonicas();

        ImportadorCatalogo::importarSources(CatalogoPorDefecto::sources(), false, null);
        ImportadorCatalogo::importarRadios(CatalogoPorDefecto::radios(), false, null);
        ImportadorCatalogo::importarCollectives(CatalogoPorDefecto::collectives(), false, null);

        // Asignar topics del seed a sources existentes que no los tengan.
        // El importador con actualizar=false respeta las ya existentes y
        // no les asigna topics — pero muchas sources (sobre todo vídeos)
        // quedaron sin topics en versiones anteriores porque el seed
        // tampoco los tenía. Ahora el seed está al día, así que
        // backfilleamos sources sin pisar las que el admin haya editado
        // manualmente.
        self::asignarTopicsFaltantesDesdeSeed();

        // Mismo razonamiento para el flag editorial `es_movimiento`:
        // se introdujo después del lanzamiento, así que sources
        // antiguas en BD no lo tienen aunque el seed actual sí. Sin
        // este backfill, la sección "Voces de movimientos" del cliente
        // sale vacía en instancias antiguas — el filtro
        // `_fnh_es_movimiento='1'` no encuentra nada.
        self::backfillFlagsEditorialesDesdeSeed();

        // Purga única de items con source en papelera o inexistente.
        // Marcados para que un eventual untrash de la source los pueda
        // recuperar. Ver `ItemsHuerfanos` para el detalle.
        ItemsHuerfanos::purgarHuerfanosUnaVez();

        update_option('fnh_catalogo_sincronizado_version', FNH_VERSION);
    }

    /**
     * Repone flags editoriales (es_movimiento) desde el seed para
     * sources que ya existen pero no los tienen. Idempotente: si el
     * meta ya está seteado a cualquier valor, no lo pisa. Si no está
     * seteado (clave inexistente en post_meta), lo crea con el valor
     * del seed.
     *
     * Por qué no incluir más campos: aquí queremos respetar al admin.
     * Topics también respeta. Pero feed_url o territory los podría
     * haber editado a mano y no queremos pisar — sólo flags
     * declarativos del catálogo curado.
     */
    private static function backfillFlagsEditorialesDesdeSeed(): void
    {
        $entradasSeed = CatalogoPorDefecto::sources();
        foreach ($entradasSeed as $raw) {
            $slug = (string) ($raw['slug'] ?? '');
            if ($slug === '' || !array_key_exists('es_movimiento', $raw)) {
                continue;
            }
            $post = get_page_by_path($slug, OBJECT, \FlavorNewsHub\CPT\Source::SLUG);
            if (!$post) {
                continue;
            }
            $idPost = (int) $post->ID;
            // Sólo aplicamos si el meta no existe aún. Si el admin lo
            // puso a false a propósito, get_post_meta devuelve '' que
            // es distinto de la cadena 'no-existe' — usamos
            // metadata_exists para distinguir "no seteado" de
            // "seteado a false".
            if (metadata_exists('post', $idPost, '_fnh_es_movimiento')) {
                continue;
            }
            update_post_meta($idPost, '_fnh_es_movimiento', (bool) $raw['es_movimiento']);
        }
    }

    /**
     * Para cada source del seed con topics, si el source en BD existe y
     * no tiene ningún topic asignado, le copia los del seed. Idempotente
     * y no destructivo.
     */
    private static function asignarTopicsFaltantesDesdeSeed(): void
    {
        $seed = CatalogoPorDefecto::sources();
        $actualizados = 0;
        foreach ($seed as $raw) {
            $slug = (string) ($raw['slug'] ?? '');
            $topicsSlugs = $raw['topics'] ?? [];
            if ($slug === '' || !is_array($topicsSlugs) || $topicsSlugs === []) {
                continue;
            }
            $post = get_page_by_path($slug, OBJECT, \FlavorNewsHub\CPT\Source::SLUG);
            if (!$post) {
                continue;
            }
            $idPost = (int) $post->ID;
            $topicsExistentes = wp_get_object_terms($idPost, \FlavorNewsHub\Taxonomy\Topic::SLUG, ['fields' => 'ids']);
            if (is_wp_error($topicsExistentes)) {
                continue;
            }
            if (!empty($topicsExistentes)) {
                continue; // El admin ya curó topics — no pisamos.
            }
            $idsTerminos = [];
            foreach ($topicsSlugs as $slugTopic) {
                $term = get_term_by('slug', (string) $slugTopic, \FlavorNewsHub\Taxonomy\Topic::SLUG);
                if ($term && !is_wp_error($term)) {
                    $idsTerminos[] = (int) $term->term_id;
                }
            }
            if ($idsTerminos !== []) {
                wp_set_object_terms($idPost, $idsTerminos, \FlavorNewsHub\Taxonomy\Topic::SLUG, false);
                $actualizados++;
            }
        }
        if ($actualizados > 0) {
            error_log('[FlavorNewsHub] Topics asignados a ' . $actualizados . ' sources sin topics.');
        }
    }

    /**
     * Compara la versión runtime (FNH_VERSION del archivo principal,
     * que llega tras OPcache hit) con la última versión que vimos
     * activa. Si difieren, llamamos `opcache_reset()` y guardamos.
     *
     * Esto NO recupera el primer request tras el upgrade: el primer
     * arranque sigue ejecutando código viejo si OPcache lo cacheó.
     * Lo que SÍ logramos es que ese primer arranque del nuevo código
     * (cuando la option se escribe con la nueva versión) limpie el
     * resto del bytecode cacheado del plugin. La consecuencia
     * práctica: tras un upgrade que sí entró (porque WP descomprimió
     * el ZIP y fue suficiente para la página principal), las clases
     * cargadas perezosamente por el autoloader empiezan a coger el
     * código nuevo en el siguiente request.
     *
     * En sitios donde OPcache no soltó NADA del plugin tras el
     * upgrade, hace falta intervención manual una vez (desactivar
     * y reactivar el plugin, o reiniciar PHP-FPM).
     */
    private static function resetearOpcacheSiCambioVersion(): void
    {
        if (!defined('FNH_VERSION')) {
            return;
        }
        $versionEnRuntime = FNH_VERSION;
        $versionVistaPrev = (string) get_option('fnh_runtime_version', '');
        if ($versionVistaPrev === $versionEnRuntime) {
            return;
        }
        if (function_exists('opcache_reset')) {
            @opcache_reset();
            error_log('[FlavorNewsHub] OPcache reseteado tras detectar cambio de versión: '
                . $versionVistaPrev . ' → ' . $versionEnRuntime);
        }
        update_option('fnh_runtime_version', $versionEnRuntime, false);
    }
}
