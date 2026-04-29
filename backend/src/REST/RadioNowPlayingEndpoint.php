<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Radio;

/**
 * GET /radios/{id}/now-playing
 *
 * Lee el StreamTitle ICY del stream Icecast/Shoutcast de la radio y
 * devuelve `{"title": "Artista - Canción"}` (o cadena vacía si no hay
 * metadata o el stream usa un transporte sin ICY como HLS).
 *
 * Cómo funciona:
 *  1. Abrimos un socket HTTP(S) a la URL del stream con header
 *     `Icy-MetaData: 1`. El servidor responde con `icy-metaint: N`,
 *     que indica cada cuántos bytes de audio inserta un bloque de
 *     metadata.
 *  2. Saltamos N bytes de audio (los descartamos: no nos importa el
 *     audio, sólo el metadata adyacente).
 *  3. Leemos 1 byte de longitud `L`. El bloque de metadata son
 *     `L*16` bytes con NUL de relleno, en formato
 *     `StreamTitle='...';StreamUrl='...';`.
 *  4. Parseamos `StreamTitle` y cerramos el socket.
 *
 * Cache: transient `fnh_radio_now_$id` con TTL 30 s. Sin él cada
 * polling del cliente abriría un socket nuevo al servidor de la radio
 * — agresivo y, en sitios con muchos visitantes simultáneos, abusivo.
 *
 * Limitaciones:
 *  - HLS (`.m3u8`) no usa ICY. Devolvemos vacío sin intentar leer.
 *  - Si la conexión TLS falla (cert inválido), devolvemos vacío.
 *    Mejor que romper el endpoint entero.
 *  - Si el servidor no envía `icy-metaint`, devolvemos vacío.
 */
final class RadioNowPlayingEndpoint
{
    private const TTL_TRANSIENT_SEG = 30;
    private const TIMEOUT_SOCKET_SEG = 5;
    private const LIMITE_BYTES_METAINT = 1_000_000;
    private const LIMITE_BYTES_METADATA = 4080; // 255 * 16, máximo del protocolo

    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/radios/(?P<id>\d+)/now-playing', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'obtener'],
                'permission_callback' => '__return_true',
                'args'                => [
                    'id' => [
                        'type'              => 'integer',
                        'required'          => true,
                        'sanitize_callback' => 'absint',
                    ],
                ],
            ],
        ]);
    }

    public static function obtener(\WP_REST_Request $request): \WP_REST_Response
    {
        $idRadio = (int) $request->get_param('id');
        if ($idRadio <= 0) {
            return new \WP_REST_Response(['title' => ''], 200);
        }

        $claveCache = 'fnh_radio_now_' . $idRadio;
        $cacheado = get_transient($claveCache);
        if (is_array($cacheado) && array_key_exists('title', $cacheado)) {
            return new \WP_REST_Response($cacheado, 200);
        }

        $post = get_post($idRadio);
        if (!$post instanceof \WP_Post || $post->post_type !== Radio::SLUG || $post->post_status !== 'publish') {
            $resultado = ['title' => ''];
            set_transient($claveCache, $resultado, self::TTL_TRANSIENT_SEG);
            return new \WP_REST_Response($resultado, 200);
        }

        $urlStream = (string) get_post_meta($idRadio, '_fnh_stream_url', true);
        $titulo = self::leerStreamTitle($urlStream);
        $resultado = ['title' => $titulo];
        set_transient($claveCache, $resultado, self::TTL_TRANSIENT_SEG);
        return new \WP_REST_Response($resultado, 200);
    }

    /**
     * Abre un socket al stream y devuelve el primer `StreamTitle`
     * encontrado. Devuelve cadena vacía si la URL no es Icecast/Shoutcast,
     * el servidor no emite metadata, o algo falla.
     */
    public static function leerStreamTitle(string $urlStream): string
    {
        if ($urlStream === '') {
            return '';
        }
        // HLS (.m3u8) usa otro mecanismo de metadata (ID3 dentro de
        // los segmentos TS). Lo descartamos antes de gastar el timeout.
        $rutaUrl = (string) wp_parse_url($urlStream, PHP_URL_PATH);
        if ($rutaUrl !== '' && preg_match('/\.m3u8(\?|$)/i', $urlStream) === 1) {
            return '';
        }

        $partes = wp_parse_url($urlStream);
        if (!is_array($partes) || empty($partes['host']) || empty($partes['scheme'])) {
            return '';
        }
        $esquema = strtolower((string) $partes['scheme']);
        if ($esquema !== 'http' && $esquema !== 'https') {
            return '';
        }
        $esHttps = $esquema === 'https';
        $puerto = (int) ($partes['port'] ?? ($esHttps ? 443 : 80));
        $hostHeader = (string) $partes['host'];
        $hostSocket = ($esHttps ? 'tls://' : '') . $hostHeader;
        $ruta = ($partes['path'] ?? '/') . (isset($partes['query']) ? '?' . $partes['query'] : '');

        $contextoSocket = stream_context_create([
            'ssl' => [
                'verify_peer'      => true,
                'verify_peer_name' => true,
                'SNI_enabled'      => true,
            ],
        ]);
        $codigoError = 0;
        $mensajeError = '';
        $socket = @stream_socket_client(
            $hostSocket . ':' . $puerto,
            $codigoError,
            $mensajeError,
            self::TIMEOUT_SOCKET_SEG,
            STREAM_CLIENT_CONNECT,
            $contextoSocket
        );
        if (!is_resource($socket)) {
            return '';
        }
        try {
            stream_set_timeout($socket, self::TIMEOUT_SOCKET_SEG);
            // Algunos servidores no aceptan HTTP/1.1 sin Connection;
            // forzamos HTTP/1.0 + close para que cierren al acabar el
            // primer bloque de metadata sin esperar más comandos.
            $peticion = "GET {$ruta} HTTP/1.0\r\n"
                . "Host: {$hostHeader}\r\n"
                . "User-Agent: FlavorNewsHub/now-playing\r\n"
                . "Icy-MetaData: 1\r\n"
                . "Accept: */*\r\n"
                . "Connection: close\r\n\r\n";
            $escritos = fwrite($socket, $peticion);
            if ($escritos === false || $escritos < strlen($peticion)) {
                return '';
            }

            $metaint = self::leerCabecerasIcy($socket);
            if ($metaint <= 0 || $metaint > self::LIMITE_BYTES_METAINT) {
                return '';
            }

            // Saltar `metaint` bytes de audio antes del primer bloque
            // de metadata. Leemos a chunks razonables — fread con un
            // único `metaint` puede devolver menos en streams lentos.
            if (!self::saltarBytes($socket, $metaint)) {
                return '';
            }

            $byteLongitud = fread($socket, 1);
            if (!is_string($byteLongitud) || strlen($byteLongitud) < 1) {
                return '';
            }
            $longitudMeta = ord($byteLongitud) * 16;
            if ($longitudMeta <= 0 || $longitudMeta > self::LIMITE_BYTES_METADATA) {
                // Longitud 0 = "metadata no cambió desde el último bloque",
                // común si la canción no varió. Como no tenemos historial,
                // devolvemos vacío y dejamos al cache cubrir hasta el
                // próximo polling — para ese momento el bloque puede
                // tener título.
                return '';
            }
            $bloqueMeta = self::leerExactos($socket, $longitudMeta);
            if ($bloqueMeta === null) {
                return '';
            }
            return self::extraerStreamTitle($bloqueMeta);
        } finally {
            // @phpstan-ignore-next-line — fclose acepta resource.
            @fclose($socket);
        }
    }

    /**
     * Lee y parsea las cabeceras HTTP/ICY de la respuesta. Devuelve el
     * valor de `icy-metaint` o 0 si no aparece o el status no es 200.
     *
     * @param resource $socket
     */
    private static function leerCabecerasIcy($socket): int
    {
        $statusLeido = false;
        $metaint = 0;
        // Tope de líneas de cabecera para no consumir un body
        // accidentalmente si el servidor responde algo raro.
        $maxLineas = 50;
        while ($maxLineas-- > 0 && !feof($socket)) {
            $linea = fgets($socket, 4096);
            if ($linea === false) {
                return 0;
            }
            $linea = rtrim($linea, "\r\n");
            if (!$statusLeido) {
                if (!preg_match('/^(?:HTTP|ICY)\/[\d.]+\s+(\d+)/i', $linea, $coincidencia)) {
                    return 0;
                }
                if ((int) $coincidencia[1] !== 200) {
                    return 0;
                }
                $statusLeido = true;
                continue;
            }
            if ($linea === '') {
                break; // fin de cabeceras
            }
            if (preg_match('/^icy-metaint\s*:\s*(\d+)/i', $linea, $coincidencia)) {
                $metaint = (int) $coincidencia[1];
            }
        }
        return $metaint;
    }

    /**
     * Descarta `$cantidad` bytes del socket, leyendo en chunks. Devuelve
     * false si EOF o timeout antes de completar.
     *
     * @param resource $socket
     */
    private static function saltarBytes($socket, int $cantidad): bool
    {
        $leidos = 0;
        while ($leidos < $cantidad) {
            if (feof($socket)) {
                return false;
            }
            $tamPedir = min(8192, $cantidad - $leidos);
            $bloque = fread($socket, $tamPedir);
            if (!is_string($bloque) || $bloque === '') {
                return false;
            }
            $leidos += strlen($bloque);
        }
        return true;
    }

    /**
     * Lee exactamente `$cantidad` bytes del socket. Devuelve null si EOF
     * o timeout antes de completar.
     *
     * @param resource $socket
     */
    private static function leerExactos($socket, int $cantidad): ?string
    {
        $acumulador = '';
        while (strlen($acumulador) < $cantidad) {
            if (feof($socket)) {
                return null;
            }
            $bloque = fread($socket, $cantidad - strlen($acumulador));
            if (!is_string($bloque) || $bloque === '') {
                return null;
            }
            $acumulador .= $bloque;
        }
        return $acumulador;
    }

    /**
     * Parsea `StreamTitle='...';` del bloque de metadata. Maneja
     * comillas escapadas mínimamente — el protocolo ICY no estandariza
     * el escape pero algunos servidores doblan la comilla simple.
     */
    private static function extraerStreamTitle(string $bloque): string
    {
        $bloque = rtrim($bloque, "\0");
        if (preg_match("/StreamTitle='(.*?)';/", $bloque, $coincidencia) !== 1) {
            return '';
        }
        $titulo = trim((string) $coincidencia[1]);
        // Algunos servidores rellenan con caracteres no-UTF8 (latin-1).
        // Normalizamos para que el JSON salga limpio.
        if (function_exists('mb_check_encoding') && !mb_check_encoding($titulo, 'UTF-8')) {
            $titulo = mb_convert_encoding($titulo, 'UTF-8', 'ISO-8859-1');
        }
        return $titulo;
    }
}
