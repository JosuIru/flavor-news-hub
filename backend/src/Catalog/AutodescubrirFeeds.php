<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

/**
 * Auto-descubrimiento de feeds RSS/Atom a partir de una URL.
 *
 * Cuando una fuente RSS deja de funcionar suele ser porque el medio ha
 * cambiado la URL del feed (CMS migrado, paso de FeedBurner a self-host,
 * reestructuración de slugs). En esos casos el servidor casi siempre
 * sigue respondiendo 200 con la página HTML del medio, que a su vez
 * declara los feeds disponibles vía `<link rel="alternate">`.
 *
 * Esta clase descarga el HTML de una URL dada y devuelve la primera URL
 * de feed encontrada — preferentemente RSS, fallback a Atom. La
 * llamamos desde la pantalla de admin "Estado de fuentes" para
 * proponer al admin URL alternativas para fuentes con error.
 */
final class AutodescubrirFeeds
{
    /** UA realista — coherente con FeedIngester, evita bloqueos Cloudflare. */
    private const USER_AGENT_NAVEGADOR =
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

    private const TIMEOUT_DESCARGA_SEGUNDOS = 15;

    /**
     * Descarga `$urlPagina` y busca declaraciones `<link rel="alternate">`.
     * Devuelve URL absoluta del feed más probable, o null si no encuentra.
     *
     * @return array{0: string, 1: string}|null Tupla [url_feed, tipo] (rss/atom), o null.
     */
    public static function detectarDesdeUrl(string $urlPagina): ?array
    {
        $urlPagina = trim($urlPagina);
        if ($urlPagina === '' || !filter_var($urlPagina, FILTER_VALIDATE_URL)) {
            return null;
        }

        $respuesta = wp_safe_remote_get($urlPagina, [
            'timeout'     => self::TIMEOUT_DESCARGA_SEGUNDOS,
            'redirection' => 5,
            'user-agent'  => self::USER_AGENT_NAVEGADOR,
            'headers'     => [
                'Accept'          => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language' => 'es,en;q=0.8',
            ],
        ]);

        if (is_wp_error($respuesta)) {
            return null;
        }

        $codigoHttp = (int) wp_remote_retrieve_response_code($respuesta);
        if ($codigoHttp < 200 || $codigoHttp >= 400) {
            return null;
        }

        $cuerpoHtml = (string) wp_remote_retrieve_body($respuesta);
        if ($cuerpoHtml === '') {
            return null;
        }

        // URL final tras redirecciones (puede haber sido redirect a homepage
        // si la URL original ya no existe). Sirve como base para resolver
        // hrefs relativos.
        $urlBaseResolucion = (string) (wp_remote_retrieve_header($respuesta, 'x-final-url') ?: $urlPagina);

        return self::detectarDesdeHtml($cuerpoHtml, $urlBaseResolucion);
    }

    /**
     * Variante para tests / reusable: parsea el HTML ya descargado.
     *
     * @return array{0: string, 1: string}|null
     */
    public static function detectarDesdeHtml(string $cuerpoHtml, string $urlBase): ?array
    {
        // Buscamos todos los <link rel="alternate" ...> con type RSS/Atom.
        // Regex pragmático — un parser DOM completo sería overkill para esto
        // y meter DOMDocument en el require path es más fricción que ganancia.
        if (preg_match_all(
            '#<link\b[^>]*?\brel\s*=\s*["\']?alternate["\']?[^>]*?>#i',
            $cuerpoHtml,
            $coincidenciasLink
        ) === false) {
            return null;
        }

        $candidatosFeed = [];
        foreach ($coincidenciasLink[0] as $tagLink) {
            // Extraer atributos individuales.
            $atributoType = '';
            $atributoHref = '';
            if (preg_match('#\btype\s*=\s*["\']([^"\']+)["\']#i', $tagLink, $coincidenciaType)) {
                $atributoType = strtolower($coincidenciaType[1]);
            }
            if (preg_match('#\bhref\s*=\s*["\']([^"\']+)["\']#i', $tagLink, $coincidenciaHref)) {
                $atributoHref = trim($coincidenciaHref[1]);
            }
            if ($atributoHref === '' || $atributoType === '') {
                continue;
            }

            $tipoFeedDetectado = null;
            if (str_contains($atributoType, 'rss')) {
                $tipoFeedDetectado = 'rss';
            } elseif (str_contains($atributoType, 'atom')) {
                $tipoFeedDetectado = 'atom';
            }
            if ($tipoFeedDetectado === null) {
                continue;
            }

            $urlFeedAbsoluta = self::resolverUrlAbsoluta($atributoHref, $urlBase);
            if ($urlFeedAbsoluta === null) {
                continue;
            }
            $candidatosFeed[] = [$urlFeedAbsoluta, $tipoFeedDetectado];
        }

        if ($candidatosFeed === []) {
            return null;
        }

        // Preferimos RSS sobre Atom — más universalmente compatible con
        // SimplePie en su configuración por defecto.
        foreach ($candidatosFeed as $candidato) {
            if ($candidato[1] === 'rss') {
                return $candidato;
            }
        }
        return $candidatosFeed[0];
    }

    /**
     * Resuelve una URL potencialmente relativa contra una base.
     * Devuelve null si el resultado no es una URL HTTP(S) válida.
     */
    private static function resolverUrlAbsoluta(string $urlPotencialmenteRelativa, string $urlBase): ?string
    {
        $partesUrl = wp_parse_url($urlPotencialmenteRelativa);
        if (is_array($partesUrl) && !empty($partesUrl['scheme'])) {
            // Ya es absoluta.
            $urlFinal = $urlPotencialmenteRelativa;
        } else {
            $partesBase = wp_parse_url($urlBase);
            if (!is_array($partesBase) || empty($partesBase['scheme']) || empty($partesBase['host'])) {
                return null;
            }
            $esquema = $partesBase['scheme'];
            $host    = $partesBase['host'];
            $puerto  = isset($partesBase['port']) ? ':' . $partesBase['port'] : '';
            if (str_starts_with($urlPotencialmenteRelativa, '//')) {
                $urlFinal = $esquema . ':' . $urlPotencialmenteRelativa;
            } elseif (str_starts_with($urlPotencialmenteRelativa, '/')) {
                $urlFinal = $esquema . '://' . $host . $puerto . $urlPotencialmenteRelativa;
            } else {
                $rutaBase = $partesBase['path'] ?? '/';
                $rutaBase = rtrim(substr($rutaBase, 0, (int) strrpos($rutaBase, '/') + 1), '/');
                $urlFinal = $esquema . '://' . $host . $puerto . $rutaBase . '/' . $urlPotencialmenteRelativa;
            }
        }

        if (!filter_var($urlFinal, FILTER_VALIDATE_URL)) {
            return null;
        }
        $esquemaFinal = strtolower((string) wp_parse_url($urlFinal, PHP_URL_SCHEME));
        if (!in_array($esquemaFinal, ['http', 'https'], true)) {
            return null;
        }
        return $urlFinal;
    }
}
