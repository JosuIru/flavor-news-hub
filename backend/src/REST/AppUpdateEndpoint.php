<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\Support\Transients;

/**
 * Endpoint público que la app Flutter consulta al arrancar para saber si
 * hay una versión nueva del APK. Responde con metadatos mínimos (versión,
 * URL de descarga, changelog, flag opcional de "obligatorio").
 *
 * Modos de operación, controlados por el admin desde la página Sistema
 * (tab "Actualizaciones app", opción `fnh_anuncio_actualizacion_app`):
 *
 *  - **Auto** (por defecto, si la opción está vacía o tiene `tag=''`):
 *    fuente de verdad = la última release del repo GitHub con asset
 *    `.apk`. Comportamiento histórico — el admin no tiene que tocar
 *    nada para que cada release nueva se anuncie.
 *
 *  - **Manual** (`tag` no vacío): el admin fija la versión que quiere
 *    anunciar (puede ser antigua, p. ej. para hacer rollback, o
 *    cualquier release con APK). El flag `es_obligatoria` también
 *    se guarda en la opción y sustituye al sniff `[mandatory]` del
 *    changelog.
 *
 * Cacheado en transients (TTL en `Transients::CACHE_RELEASE_GITHUB`)
 * para no golpear la API de GitHub en cada arranque de cada app. El
 * cache se cachean por modo + tag para que conmutar manual ↔ auto no
 * sirva la respuesta del modo anterior.
 */
final class AppUpdateEndpoint
{
    private const REPO_GITHUB = 'JosuIru/flavor-news-hub';
    private const TRANSIENT_CACHE = 'fnh_app_update_cache';

    /**
     * Slug de la opción de wp_options que controla el anuncio. Estructura:
     *   [
     *     'tag'             => string  // '' o 'vX.Y.Z'
     *     'es_obligatoria'  => bool
     *     'anunciado_at'    => string  // ISO-8601
     *     'anunciado_por'   => int     // user ID
     *   ]
     * Vacío o con `tag=''` ⇒ modo auto.
     */
    public const OPCION_ANUNCIO = 'fnh_anuncio_actualizacion_app';

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
                'refresh'  => [
                    'type'        => 'boolean',
                    'required'    => false,
                    'default'     => false,
                    'description' => 'Si true, ignora el transient cacheado y vuelve a leer GitHub.',
                ],
            ],
        ]);
    }

    public static function comprobar(\WP_REST_Request $request): \WP_REST_Response
    {
        $versionInstalada = (string) $request->get_param('version');
        $incluyePrereleases = $request->get_param('channel') === 'beta';
        $forzarRefresh = (bool) $request->get_param('refresh');

        // Lee la decisión del admin: si hay tag manual lo respetamos,
        // si no caemos al modo auto (última release con APK).
        $configAnuncio = self::leerConfigAnuncio();
        $tagManual = (string) ($configAnuncio['tag'] ?? '');
        $esObligatoriaManual = (bool) ($configAnuncio['es_obligatoria'] ?? false);

        if ($tagManual !== '') {
            $release = self::obtenerReleasePorTag($tagManual, $forzarRefresh);
            $modo = 'manual';
        } else {
            $release = self::obtenerUltimaRelease($incluyePrereleases, $forzarRefresh);
            $modo = 'auto';
        }

        if ($release === null) {
            return new \WP_REST_Response([
                'update_available' => false,
                'reason'           => $modo === 'manual' ? 'tag_no_encontrado' : 'no_releases',
                'modo'             => $modo,
            ], 200);
        }

        $esNueva = $versionInstalada === ''
            ? true
            : version_compare(
                self::normalizarVersion($release['version']),
                self::normalizarVersion($versionInstalada),
                '>'
            );

        // En modo manual la obligatoriedad la marca el admin desde la UI;
        // en modo auto seguimos respetando la convención `[mandatory]` en
        // el changelog (compatibilidad con releases antiguas).
        $esObligatoria = $modo === 'manual'
            ? $esObligatoriaManual
            : self::esObligatoria($release['changelog']);

        return new \WP_REST_Response([
            'update_available' => $esNueva,
            'version'          => $release['version'],
            'download_url'     => $release['download_url'],
            'release_url'      => $release['release_url'],
            'changelog'        => $release['changelog'],
            'published_at'     => $release['published_at'],
            'is_mandatory'     => $esObligatoria,
            'modo'             => $modo,
        ], 200);
    }

    /**
     * Lee la opción del admin con saneo defensivo. Devuelve siempre un
     * array con las claves esperadas — un valor mal formado equivale a
     * "modo auto" (tag vacío).
     *
     * @return array{tag:string,es_obligatoria:bool,anunciado_at:string,anunciado_por:int}
     */
    public static function leerConfigAnuncio(): array
    {
        $crudo = get_option(self::OPCION_ANUNCIO, []);
        if (!is_array($crudo)) {
            $crudo = [];
        }
        return [
            'tag'            => (string) ($crudo['tag'] ?? ''),
            'es_obligatoria' => (bool) ($crudo['es_obligatoria'] ?? false),
            'anunciado_at'   => (string) ($crudo['anunciado_at'] ?? ''),
            'anunciado_por'  => (int) ($crudo['anunciado_por'] ?? 0),
        ];
    }

    /**
     * Lista las últimas N releases con asset `.apk` para el desplegable
     * del admin. Comparte cache de 1h con el modo auto, así que tras un
     * release nuevo el admin debe pulsar "Refrescar" en la UI para verlo.
     *
     * @return list<array{version:string,published_at:string,download_url:string}>
     */
    public static function listarReleasesParaAdmin(int $limite = 10, bool $forzarRefresh = false): array
    {
        $todas = self::obtenerListadoReleases($forzarRefresh);
        $resultado = [];
        foreach ($todas as $release) {
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
            $resultado[] = [
                'version'      => (string) ($release['tag_name'] ?? ''),
                'published_at' => (string) ($release['published_at'] ?? ''),
                'download_url' => (string) ($apkAsset['browser_download_url'] ?? ''),
            ];
            if (count($resultado) >= $limite) break;
        }
        return $resultado;
    }

    /**
     * Busca una release concreta por tag entre las últimas ~30. Si no la
     * encuentra (release muy antigua o tag inexistente), devuelve null —
     * el endpoint responde con `reason=tag_no_encontrado` y el admin
     * puede cambiar la opción.
     *
     * @return array{version:string,download_url:string,release_url:string,changelog:string,published_at:string}|null
     */
    private static function obtenerReleasePorTag(string $tag, bool $forzarRefresh): ?array
    {
        $tagBuscado = trim($tag);
        if ($tagBuscado === '') return null;

        $claveCache = self::TRANSIENT_CACHE . '_tag_' . md5($tagBuscado);
        if (!$forzarRefresh) {
            $cache = get_transient($claveCache);
            if (is_array($cache)) {
                return $cache;
            }
        }

        // Iteramos sobre las últimas releases buscando el tag exacto. Si
        // no aparece en las primeras 30, tiramos la toalla (mejor "no
        // encontrado" que abrir más rate-limit en GitHub).
        $todas = self::obtenerListadoReleases($forzarRefresh);
        foreach ($todas as $release) {
            if (!is_array($release)) continue;
            if ((string) ($release['tag_name'] ?? '') !== $tagBuscado) continue;

            $apkAsset = null;
            foreach (($release['assets'] ?? []) as $asset) {
                if (!is_array($asset)) continue;
                $nombre = (string) ($asset['name'] ?? '');
                if (str_ends_with(strtolower($nombre), '.apk')) {
                    $apkAsset = $asset;
                    break;
                }
            }
            if ($apkAsset === null) return null;

            $datos = [
                'version'      => (string) ($release['tag_name'] ?? ''),
                'download_url' => (string) ($apkAsset['browser_download_url'] ?? ''),
                'release_url'  => (string) ($release['html_url'] ?? ''),
                'changelog'    => (string) ($release['body'] ?? ''),
                'published_at' => (string) ($release['published_at'] ?? ''),
            ];
            set_transient($claveCache, $datos, Transients::CACHE_RELEASE_GITHUB);
            return $datos;
        }
        return null;
    }

    /**
     * Listado bruto de las últimas releases del repo (con o sin APK,
     * con o sin prereleases). Cacheado para que `obtenerUltimaRelease`,
     * `obtenerReleasePorTag` y `listarReleasesParaAdmin` compartan una
     * sola llamada a GitHub por hora.
     *
     * @return array<int,array<string,mixed>>
     */
    private static function obtenerListadoReleases(bool $forzarRefresh): array
    {
        $claveCache = self::TRANSIENT_CACHE . '_listado';
        if ($forzarRefresh) {
            delete_transient($claveCache);
        } else {
            $cache = get_transient($claveCache);
            if (is_array($cache)) {
                return $cache;
            }
        }

        $url = 'https://api.github.com/repos/' . self::REPO_GITHUB . '/releases?per_page=30';
        $headers = ['Accept' => 'application/vnd.github+json'];
        if (defined('FLAVOR_GH_TOKEN') && FLAVOR_GH_TOKEN !== '') {
            $headers['Authorization'] = 'Bearer ' . FLAVOR_GH_TOKEN;
        }
        $respuesta = wp_remote_get($url, [
            'headers' => $headers,
            'timeout' => 10,
        ]);
        if (is_wp_error($respuesta)) {
            return [];
        }
        $http = (int) wp_remote_retrieve_response_code($respuesta);
        if ($http !== 200) {
            return [];
        }
        $cuerpo = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        if (!is_array($cuerpo)) {
            return [];
        }
        // Filtramos drafts aquí: ningún consumidor del listado los quiere.
        $listado = array_values(array_filter($cuerpo, static function ($r) {
            return is_array($r) && (($r['draft'] ?? false) !== true);
        }));
        set_transient($claveCache, $listado, Transients::CACHE_RELEASE_GITHUB);
        return $listado;
    }

    /**
     * Selecciona la primera release con asset `.apk` del listado.
     * `obtenerListadoReleases` hace la petición HTTP y la cachea, así
     * que repetir esta búsqueda es barato (in-memory + transient).
     *
     * @return array{version:string,download_url:string,release_url:string,changelog:string,published_at:string}|null
     */
    private static function obtenerUltimaRelease(bool $incluyePrereleases, bool $forzarRefresh = false): ?array
    {
        $todas = self::obtenerListadoReleases($forzarRefresh);
        foreach ($todas as $release) {
            if (!is_array($release)) continue;
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

            return [
                'version'      => (string) ($release['tag_name'] ?? ''),
                'download_url' => (string) ($apkAsset['browser_download_url'] ?? ''),
                'release_url'  => (string) ($release['html_url'] ?? ''),
                'changelog'    => (string) ($release['body'] ?? ''),
                'published_at' => (string) ($release['published_at'] ?? ''),
            ];
        }
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
