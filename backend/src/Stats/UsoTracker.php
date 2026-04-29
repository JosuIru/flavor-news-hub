<?php
declare(strict_types=1);

namespace FlavorNewsHub\Stats;

use FlavorNewsHub\Database\UsoApiTable;
use FlavorNewsHub\REST\RestController;

/**
 * Contador anónimo de peticiones a la API pública.
 *
 * Filosofía:
 *  - Cero datos que identifiquen al usuario: ni IP, ni cookies, ni
 *    fingerprint. El UA se almacena hasheado (MD5 truncado) y sólo
 *    sirve para contar variedad agregada (¿1 UA o 200?).
 *  - Granularidad gruesa: por día y endpoint. No reconstruimos sesiones.
 *  - Decisión derivada: el panel responde a "¿se usa la app?" sin
 *    poder responder a "¿quién la usa?".
 *
 * Activación: el `RestController` engancha `registrarSiAplica()` al
 * filtro `rest_post_dispatch`, que se dispara después de servir cada
 * respuesta. Trabajar en post-dispatch evita meter latencia en la
 * petición — fallar silenciosamente aquí no afecta a nadie.
 */
final class UsoTracker
{
    /**
     * Endpoints a los que les hacemos seguimiento. Ignoramos rutas
     * que no son de la API pública (admin-ajax, oembed, autodiscovery)
     * para que la tabla no crezca con ruido.
     */
    private const ENDPOINTS_RELEVANTES = [
        'items',
        'items/(?P<id>\d+)',
        'sources',
        'sources/(?P<id>\d+)',
        'sources/submit',
        'collectives',
        'collectives/(?P<id>\d+)',
        'collectives/submit',
        'radios',
        'topics',
        'territorios',
        'public-settings',
    ];

    /**
     * Hook `rest_post_dispatch`: filter callback. Devolvemos siempre
     * `$response` sin tocarla. El registro va en background (best
     * effort): si la inserción falla por cualquier motivo, se ignora.
     *
     * @param mixed $response   La respuesta REST ya construida.
     * @param mixed $server     Instancia del REST server.
     * @param mixed $request    La petición.
     * @return mixed
     */
    public static function registrarSiAplica($response, $server, $request)
    {
        try {
            if (!is_object($request) || !method_exists($request, 'get_route')) {
                return $response;
            }
            $ruta = (string) $request->get_route();
            // Sólo nos interesan rutas de nuestro namespace.
            $prefijo = '/' . RestController::NAMESPACE_REST . '/';
            if (strpos($ruta, $prefijo) !== 0) {
                return $response;
            }
            $endpoint = substr($ruta, strlen($prefijo));
            // Endpoints con parámetros dinámicos (`/items/123`) los
            // canonizamos a su forma plantilla: la columna es chica y
            // no queremos `items/1`, `items/2`, … como filas distintas.
            $endpointCanonizado = self::canonizar($endpoint);
            if ($endpointCanonizado === null) {
                return $response;
            }
            // Sólo respondemos a métodos READ — submits y demás
            // peticiones de mutación las contamos también pero como
            // su propio endpoint canónico (ya están en la lista).
            $metodo = (string) $request->get_method();
            if ($metodo !== 'GET' && $metodo !== 'POST') {
                return $response;
            }

            $userAgent = (string) ($_SERVER['HTTP_USER_AGENT'] ?? '');
            $hashUa = substr(md5($userAgent), 0, 16);

            self::insertarIncrementando($endpointCanonizado, $hashUa);
        } catch (\Throwable $e) {
            // Cualquier fallo aquí no debe afectar a la respuesta REST.
            // Logueamos al error_log de PHP para diagnóstico ocasional.
            error_log('[FNH UsoTracker] ' . $e->getMessage());
        }
        return $response;
    }

    /**
     * Canoniza una ruta a una de las plantillas en `ENDPOINTS_RELEVANTES`.
     * Devuelve `null` si la ruta no encaja en ninguna (filtro implícito).
     */
    private static function canonizar(string $ruta): ?string
    {
        foreach (self::ENDPOINTS_RELEVANTES as $plantilla) {
            // Cada plantilla puede tener `(?P<x>\d+)` — convertimos a regex
            // anclada y comprobamos. La ruta canónica que devolvemos es
            // la plantilla sin el grupo nombrado para hacer el panel
            // legible: `items/{id}` en lugar de `items/(?P<id>\d+)`.
            $regex = '#^' . $plantilla . '$#';
            if (preg_match($regex, $ruta) === 1) {
                return preg_replace('#\(\?P<\w+>[^)]+\)#', '{id}', $plantilla) ?? $plantilla;
            }
        }
        return null;
    }

    /**
     * Atomic upsert: una sola query MySQL. La PK (dia, endpoint,
     * ua_hash) garantiza que dos peticiones concurrentes con el mismo
     * tuple terminan sumando en lugar de pisarse o duplicarse.
     */
    private static function insertarIncrementando(string $endpoint, string $hashUa): void
    {
        global $wpdb;
        $tabla = UsoApiTable::nombreCompleto();
        $wpdb->query($wpdb->prepare(
            "INSERT INTO {$tabla} (dia, endpoint, ua_hash, peticiones)
             VALUES (CURDATE(), %s, %s, 1)
             ON DUPLICATE KEY UPDATE peticiones = peticiones + 1",
            $endpoint,
            $hashUa
        ));
    }

    /**
     * Resumen agregado de los últimos N días. Retorna:
     *   [
     *     'total_peticiones' => int,
     *     'uas_distintos'    => int,   // hashes distintos en la ventana
     *     'por_endpoint'     => [endpoint => peticiones, …],
     *     'por_dia'          => [YYYY-MM-DD => peticiones, …],
     *     'dias'             => int,
     *   ]
     */
    public static function resumen(int $dias = 7): array
    {
        $dias = max(1, min(90, $dias));
        // Cache por ventana — son 4 SUM/COUNT/GROUP BY sobre `wp_fnh_uso_api`
        // que pueden hacer filesort cuando la tabla acumula 90 días de
        // tráfico. El admin nunca necesita ver el incremento al segundo;
        // 5 min de TTL es invisible en la UX y elimina el coste de cada
        // recarga del tab.
        $claveCache = 'fnh_uso_resumen_' . $dias;
        $cacheado = get_transient($claveCache);
        if (is_array($cacheado) && isset($cacheado['total_peticiones'])) {
            return $cacheado;
        }

        global $wpdb;
        $tabla = UsoApiTable::nombreCompleto();

        $totalPeticiones = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COALESCE(SUM(peticiones), 0) FROM {$tabla}
             WHERE dia >= DATE_SUB(CURDATE(), INTERVAL %d DAY)",
            $dias
        ));
        $uasDistintos = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(DISTINCT ua_hash) FROM {$tabla}
             WHERE dia >= DATE_SUB(CURDATE(), INTERVAL %d DAY)",
            $dias
        ));
        $porEndpoint = $wpdb->get_results($wpdb->prepare(
            "SELECT endpoint, SUM(peticiones) AS total
             FROM {$tabla}
             WHERE dia >= DATE_SUB(CURDATE(), INTERVAL %d DAY)
             GROUP BY endpoint ORDER BY total DESC",
            $dias
        ));
        $porDia = $wpdb->get_results($wpdb->prepare(
            "SELECT dia, SUM(peticiones) AS total
             FROM {$tabla}
             WHERE dia >= DATE_SUB(CURDATE(), INTERVAL %d DAY)
             GROUP BY dia ORDER BY dia ASC",
            $dias
        ));

        $mapaEndpoint = [];
        foreach ($porEndpoint as $fila) {
            $mapaEndpoint[(string) $fila->endpoint] = (int) $fila->total;
        }
        $mapaDia = [];
        foreach ($porDia as $fila) {
            $mapaDia[(string) $fila->dia] = (int) $fila->total;
        }

        $resumen = [
            'total_peticiones' => $totalPeticiones,
            'uas_distintos'    => $uasDistintos,
            'por_endpoint'     => $mapaEndpoint,
            'por_dia'          => $mapaDia,
            'dias'             => $dias,
        ];
        set_transient($claveCache, $resumen, 5 * MINUTE_IN_SECONDS);
        return $resumen;
    }
}
