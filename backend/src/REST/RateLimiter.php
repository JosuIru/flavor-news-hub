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
     */
    public static function registrarIntentoOAgotado(
        string $ipCliente,
        string $nombreZona,
        int $maximoEnVentana,
        int $duracionVentanaSegundos
    ): bool {
        $claveTransient = 'fnh_rl_' . $nombreZona . '_' . md5($ipCliente);
        $contadorActual = (int) get_transient($claveTransient);

        if ($contadorActual >= $maximoEnVentana) {
            return false;
        }

        set_transient($claveTransient, $contadorActual + 1, $duracionVentanaSegundos);
        return true;
    }
}
