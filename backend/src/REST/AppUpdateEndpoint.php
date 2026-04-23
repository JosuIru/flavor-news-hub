<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

/**
 * Endpoint público que la app Flutter consulta al arrancar para saber si
 * hay una versión nueva del APK. Responde con metadatos mínimos (versión,
 * URL de descarga, changelog, flag opcional de "obligatorio").
 *
 * Fuente de verdad: la última release del repo GitHub del proyecto.
 * Cacheado en un transient de 6h para no golpear la API de GitHub en
 * cada arranque de cada app. Si la release no expone un asset `.apk`,
 * respondemos `update_available: false`.
 *
 * Reutiliza `Flavor_GitHub_Release_API` si Flavor Platform está activo
 * (comparte cache, rate-limit y token opcional `FLAVOR_GH_TOKEN`).
 * Si no, cae a una llamada directa a la API pública de GitHub (sin
 * token, sujeto a límite de 60 req/h por IP — sobrado con cache 6h).
 */
final class AppUpdateEndpoint
{
    private const REPO_GITHUB = 'JosuIru/flavor-news-hub';
    private const TRANSIENT_CACHE = 'fnh_app_update_cache';
    // TTL corto: 1 hora. GitHub permite 60 req/h por IP sin token, y
    // sólo el endpoint /apps/check-update dispara estas peticiones —
    // muy por debajo del límite aun con tráfico agregado.
    private const TTL_CACHE_SEGUNDOS = 1 * HOUR_IN_SECONDS;

    public static function registrarRutas(): void
    {
        register_rest_route('flavor-news/v1', '/apps/check-update', [
            'methods'             => \WP_REST_Server::READABLE,
            'callback'            => [self::class, 'comprobar'],
            'permission_callback' => '__return_true',
            'args' => [
                'version'  => [
                    'type'        => 'string',
                    'required'    => false,
                    'description' => 'Versión actualmente instalada (SemVer).',
                ],
                'platform' => [
                    'type'        => 'string',
                    'required'    => false,
                    'default'     => 'android',
                    'enum'        => ['android'],
                ],
                'channel'  => [
                    'type'        => 'string',
                    'required'    => false,
                    'default'     => 'stable',
                    'enum'        => ['stable', 'beta'],
                ],
            ],
        ]);
    }

    public static function comprobar(\WP_REST_Request $request): \WP_REST_Response
    {
        $versionInstalada = (string) $request->get_param('version');
        $incluyePrereleases = $request->get_param('channel') === 'beta';

        $ultima = self::obtenerUltimaRelease($incluyePrereleases);
        if ($ultima === null) {
            return new \WP_REST_Response([
                'update_available' => false,
                'reason'           => 'no_releases',
            ], 200);
        }

        $esNueva = $versionInstalada === ''
            ? true
            : version_compare(
                self::normalizarVersion($ultima['version']),
                self::normalizarVersion($versionInstalada),
                '>'
            );

        return new \WP_REST_Response([
            'update_available' => $esNueva,
            'version'          => $ultima['version'],
            'download_url'     => $ultima['download_url'],
            'release_url'      => $ultima['release_url'],
            'changelog'        => $ultima['changelog'],
            'published_at'     => $ultima['published_at'],
            'is_mandatory'     => self::esObligatoria($ultima['changelog']),
        ], 200);
    }

    /**
     * @return array{version:string,download_url:string,release_url:string,changelog:string,published_at:string}|null
     */
    private static function obtenerUltimaRelease(bool $incluyePrereleases): ?array
    {
        $claveCache = self::TRANSIENT_CACHE . ($incluyePrereleases ? '_beta' : '');
        $cache = get_transient($claveCache);
        if (is_array($cache)) {
            return $cache;
        }

        // Pedimos un listado en vez de `/releases/latest` porque podemos
        // publicar releases solo-plugin (sin APK adjunta), y `/latest`
        // colapsaría a una que no sirve para la app móvil. Iteramos hasta
        // encontrar la primera con un asset `.apk`. En el canal `beta`
        // aceptamos prereleases; en `stable` sólo las definitivas.
        $url = 'https://api.github.com/repos/' . self::REPO_GITHUB . '/releases?per_page=15';

        $headers = ['Accept' => 'application/vnd.github+json'];
        if (defined('FLAVOR_GH_TOKEN') && FLAVOR_GH_TOKEN !== '') {
            $headers['Authorization'] = 'Bearer ' . FLAVOR_GH_TOKEN;
        }
        $respuesta = wp_remote_get($url, [
            'headers' => $headers,
            'timeout' => 10,
        ]);
        if (is_wp_error($respuesta)) {
            return null;
        }
        $http = (int) wp_remote_retrieve_response_code($respuesta);
        if ($http !== 200) {
            return null;
        }
        $cuerpo = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        if (!is_array($cuerpo)) {
            return null;
        }

        foreach ($cuerpo as $release) {
            if (!is_array($release)) continue;
            if (($release['draft'] ?? false) === true) continue;
            if (!$incluyePrereleases && ($release['prerelease'] ?? false) === true) continue;

            $apkAsset = null;
            foreach (($release['assets'] ?? []) as $asset) {
                if (!is_array($asset)) continue;
                $nombre = (string) ($asset['name'] ?? '');
                if (str_ends_with(strtolower($nombre), '.apk')) {
                    $apkAsset = $asset;
                    break;
                }
            }
            if ($apkAsset === null) continue;

            $datos = [
                'version'      => (string) ($release['tag_name'] ?? ''),
                'download_url' => (string) ($apkAsset['browser_download_url'] ?? ''),
                'release_url'  => (string) ($release['html_url'] ?? ''),
                'changelog'    => (string) ($release['body'] ?? ''),
                'published_at' => (string) ($release['published_at'] ?? ''),
            ];
            set_transient($claveCache, $datos, self::TTL_CACHE_SEGUNDOS);
            return $datos;
        }

        // Ninguna release reciente lleva APK — no hay update anunciable.
        return null;
    }

    /**
     * Convierte `v1.2.3`, `1.2.3`, `v1.2.3-beta.1` a algo comparable con
     * `version_compare`. Quita el prefijo `v` y recorta espacios.
     */
    private static function normalizarVersion(string $v): string
    {
        $v = trim($v);
        if (strlen($v) > 0 && ($v[0] === 'v' || $v[0] === 'V')) {
            $v = substr($v, 1);
        }
        return $v;
    }

    /**
     * El admin puede marcar una release como obligatoria incluyendo
     * `[mandatory]` o `[obligatoria]` en el cuerpo de la release en
     * GitHub. Es una convención: sin servidor propio, etiquetamos en
     * el propio changelog y el cliente lo interpreta.
     */
    private static function esObligatoria(string $changelog): bool
    {
        $normalizado = strtolower($changelog);
        return str_contains($normalizado, '[mandatory]')
            || str_contains($normalizado, '[obligatoria]')
            || str_contains($normalizado, '[obligatorio]');
    }
}
