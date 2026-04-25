<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Ingest\Scheduler;

/**
 * Endpoint que permite a los clientes móviles "despertar" la ingesta en
 * sitios con poco tráfico web donde wp-cron (que es pseudo-cron
 * disparado por visitas) no llega a correr en intervalos razonables.
 *
 * POST /wp-json/flavor-news/v1/ingest-trigger
 *
 * Mecánica:
 *  1. Comprueba un transient con la última vez que se disparó. Si el
 *     margen configurado (defecto 10 min) no ha pasado, devuelve un
 *     200 informativo sin tocar nada — evita que cada usuario que
 *     abre la app encadene ingestas.
 *  2. Si sí toca: agenda un evento one-shot para AHORA del hook de
 *     ingesta y llama a `spawn_cron()` para que wp-cron lo procese
 *     en una petición HTTP asíncrona (no bloquea al cliente).
 *  3. Actualiza el transient.
 *
 * No requiere auth: el único efecto es poner en cola una ingesta, que
 * sólo lee feeds públicos. El rate-limit evita abuso.
 */
final class IngestTriggerEndpoint
{
    private const TRANSIENT_ULTIMA_EJECUCION = 'fnh_ingest_trigger_last';
    private const MINUTOS_COOLDOWN = 10;

    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/ingest-trigger', [
            [
                'methods'             => \WP_REST_Server::CREATABLE, // POST
                'callback'            => [self::class, 'disparar'],
                'permission_callback' => '__return_true',
            ],
            [
                // GET devuelve sólo el estado (cuándo fue la última ejecución)
                // sin disparar nada. Útil para que la app muestre un "última
                // actualización: hace X min" sin efectos secundarios.
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'estado'],
                'permission_callback' => '__return_true',
            ],
        ]);
    }

    public static function disparar(\WP_REST_Request $request): \WP_REST_Response
    {
        $timestampUltimo = (int) get_transient(self::TRANSIENT_ULTIMA_EJECUCION);
        $segundosCooldown = self::MINUTOS_COOLDOWN * MINUTE_IN_SECONDS;
        $ahora = time();
        if ($timestampUltimo > 0 && ($ahora - $timestampUltimo) < $segundosCooldown) {
            return new \WP_REST_Response([
                'triggered'       => false,
                'reason'          => 'cooldown',
                'last_run_at'     => gmdate('c', $timestampUltimo),
                'next_allowed_at' => gmdate('c', $timestampUltimo + $segundosCooldown),
                'cooldown_minutes'=> self::MINUTOS_COOLDOWN,
            ], 200);
        }

        // Agendamos una ejecución inmediata del hook de ingesta. Usamos
        // time()-1 para forzar que ya esté "pendiente" cuando spawn_cron
        // arranque el runner. Si ya hay un evento de ingesta pendiente
        // próximo a dispararse (recurrente o single), no agendamos otro
        // — wp-cron correrá el existente y duplicarlo no aporta nada.
        $proximoYaAgendado = wp_next_scheduled(Scheduler::HOOK_CRON);
        if ($proximoYaAgendado === false || $proximoYaAgendado > $ahora + 30) {
            wp_schedule_single_event($ahora - 1, Scheduler::HOOK_CRON);
        }
        spawn_cron($ahora);

        set_transient(self::TRANSIENT_ULTIMA_EJECUCION, $ahora, $segundosCooldown + MINUTE_IN_SECONDS);

        return new \WP_REST_Response([
            'triggered'       => true,
            'last_run_at'     => gmdate('c', $ahora),
            'next_allowed_at' => gmdate('c', $ahora + $segundosCooldown),
            'cooldown_minutes'=> self::MINUTOS_COOLDOWN,
        ], 202);
    }

    public static function estado(\WP_REST_Request $request): \WP_REST_Response
    {
        $timestampUltimo = (int) get_transient(self::TRANSIENT_ULTIMA_EJECUCION);
        return new \WP_REST_Response([
            'last_run_at'     => $timestampUltimo > 0 ? gmdate('c', $timestampUltimo) : null,
            'cooldown_minutes'=> self::MINUTOS_COOLDOWN,
        ], 200);
    }
}
