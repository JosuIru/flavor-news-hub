<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

/**
 * Rate limiter por IP basado en transients.
 *
 * Simple por diseño: un transient por (zona, ip) con TTL = ventana, cuyo
 * valor es el contador de intentos. Al llegar al máximo, niega.
 *
 * Limitación conocida: si la instancia está detrás de un proxy, REMOTE_ADDR
 * puede ser la IP del proxy y no del cliente real. Para esos casos, el admin
 * debe configurar el proxy para que reescriba REMOTE_ADDR, o activar un
 * filtro que lea cabeceras de proxy confiables (no implementado en v0).
 */
final class RateLimiter
{
    public static function ipDelCliente(): string
    {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
        return filter_var((string) $ip, FILTER_VALIDATE_IP) ? (string) $ip : '0.0.0.0';
    }

    /**
     * Devuelve true si se admite esta petición (y cuenta como una más).
     * false si ya se ha alcanzado el máximo en la ventana.
     *
     * Implementación atómica: el incremento usa
     * `INSERT ... ON DUPLICATE KEY UPDATE` directamente sobre la fila
     * del transient en `wp_options`. Antes el código hacía
     * `get_transient` → check → `set_transient`, un patrón TOCTOU
     * clásico bajo el cual dos peticiones concurrentes podían leer el
     * mismo contador y ambas pasar el límite. Con InnoDB y un único
     * UPDATE, MySQL serializa el incremento por la fila → no hay
     * carrera de check-then-set.
     *
     * El timeout del transient se refresca en cada hit (sliding
     * window): mismo comportamiento que el original.
     */
    public static function registrarIntentoOAgotado(
        string $ipCliente,
        string $nombreZona,
        int $maximoEnVentana,
        int $duracionVentanaSegundos
    ): bool {
        global $wpdb;
        $claveTransient = 'fnh_rl_' . $nombreZona . '_' . md5($ipCliente);
        $nombreOptionValor = '_transient_' . $claveTransient;
        $nombreOptionTimeout = '_transient_timeout_' . $claveTransient;
        $tsExpiracion = time() + $duracionVentanaSegundos;

        // Incremento atómico del contador. ON DUPLICATE KEY UPDATE bajo
        // InnoDB toma row lock — dos requests concurrentes serializan.
        $wpdb->query($wpdb->prepare(
            "INSERT INTO {$wpdb->options} (option_name, option_value, autoload)
             VALUES (%s, '1', 'no')
             ON DUPLICATE KEY UPDATE option_value = CAST(option_value AS UNSIGNED) + 1",
            $nombreOptionValor
        ));
        // Refresca el timeout para que la ventana sea sliding. Si la
        // clave de timeout aún no existía la creamos; si existía la
        // pisamos. Sin atomicidad estricta porque sólo es para la
        // expiración del transient (no afecta al límite).
        $wpdb->query($wpdb->prepare(
            "INSERT INTO {$wpdb->options} (option_name, option_value, autoload)
             VALUES (%s, %s, 'no')
             ON DUPLICATE KEY UPDATE option_value = %s",
            $nombreOptionTimeout,
            (string) $tsExpiracion,
            (string) $tsExpiracion
        ));
        // Invalida la caché en memoria de wp_options para que un
        // `get_transient` posterior en el mismo request lea el valor
        // recién incrementado en lugar del que tenía cacheado.
        wp_cache_delete($nombreOptionValor, 'options');
        wp_cache_delete($nombreOptionTimeout, 'options');

        $valorActual = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT option_value FROM {$wpdb->options} WHERE option_name = %s",
            $nombreOptionValor
        ));
        return $valorActual <= $maximoEnVentana;
    }
}
