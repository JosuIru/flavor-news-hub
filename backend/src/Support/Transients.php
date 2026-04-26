<?php
declare(strict_types=1);

namespace FlavorNewsHub\Support;

/**
 * Política única de TTLs para los `transients` que el plugin usa
 * dentro y fuera de su capa de cache. Antes había TTLs literales
 * dispersos por el código (`HOUR_IN_SECONDS`, `10 * MINUTE_IN_SECONDS`,
 * `5 * MINUTE_IN_SECONDS`) y al pensar en cambiar uno había que
 * grep-ear el repo entero — fácil olvidar uno.
 *
 * Cada constante explica por qué tiene ese valor en su comentario.
 * Cambiar uno aquí cambia el comportamiento global; si hace falta un
 * TTL distinto sólo en un sitio, se justifica con un literal local
 * y un comentario explicando por qué se desvía.
 */
final class Transients
{
    /**
     * Cache del cuerpo descargado de un feed RSS por SimplePie.
     * WordPress por defecto cachea 12h, pero un agregador de noticias
     * en vivo no puede esperar 12h para ver una publicación nueva.
     * 10 min es agresivo sin machacar al servidor del medio.
     */
    public const CACHE_FEEDS_INGESTA = 10 * MINUTE_IN_SECONDS;

    /**
     * Lock de ingesta por fuente. Si una ingesta tarda más de esto,
     * la siguiente se permitirá aunque la anterior siga marcada como
     * en curso — protege contra locks que quedan colgados si el PHP
     * crashea sin ejecutar el `delete_transient` final.
     */
    public const LOCK_INGESTA_FEED = 5 * MINUTE_IN_SECONDS;

    /**
     * Cache de la pantalla de estadísticas del admin. Calcular
     * actividad sobre 1000+ posts es caro; 1h evita re-cálculo en
     * cada navegación entre subtabs sin volver los datos rancios.
     */
    public const CACHE_ESTADISTICAS = HOUR_IN_SECONDS;

    /**
     * Cache de la última release de GitHub usada por
     * AppUpdateEndpoint. Pulsar /update demasiado rápido contra la
     * API de GitHub gasta cuota; 1h es lo bastante fresco para que
     * un usuario que recién publicó la nueva versión no espere
     * mucho a que la app la detecte.
     */
    public const CACHE_RELEASE_GITHUB = HOUR_IN_SECONDS;

    /**
     * TTL de las propuestas del auto-descubridor de feeds en la
     * pantalla "Estado de fuentes". El admin lanza un escaneo,
     * revisa la lista y aplica selectivamente; 1h es suficiente
     * para que pueda volver desde otra pantalla sin perder la lista.
     */
    public const PROPUESTAS_AUTODESCUBRIR = HOUR_IN_SECONDS;

    /**
     * Ventana del rate limit de envíos públicos (sources +
     * collectives). Una persona con buena fe no envía dos formularios
     * por hora; abusos sí lo intentan. 1h por IP corta abusos sin
     * penalizar uso normal.
     */
    public const RATE_LIMIT_SUBMITS_PUBLICOS = HOUR_IN_SECONDS;

    private function __construct()
    {
        // Sólo constantes — no instanciable.
    }
}
