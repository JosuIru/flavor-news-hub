<?php
declare(strict_types=1);

namespace FlavorNewsHub\Ingest;

use FlavorNewsHub\Taxonomy\Topic;

/**
 * Ingester de federación pull-only para instancias de Flavor Platform.
 *
 * Se invoca desde `FeedIngester::ingestarFuente()` cuando la fuente declara
 * `feed_type = 'flavor_platform'`. Lee la API pública federada de la
 * instancia (no usa auth, no usa SimplePie) y crea `fnh_item` reutilizando
 * los helpers de `FeedIngester` para dedupe e inserción — así los items
 * federados se comportan idénticos a los de RSS en el resto del sistema.
 *
 * Principio: federación = best-effort. Si la instancia no expone alguno
 * de los endpoints (`board`, `events`), se ignora sin fallar.
 */
final class FlavorPlatformIngester
{
    private const MAXIMO_POR_ENDPOINT = 50;
    private const TIMEOUT_HTTP_SEGUNDOS = 10;

    /**
     * @return array{items_new:int,items_skipped:int,error:string}
     */
    public static function ingestarDeInstancia(int $idFuente, string $urlInstancia): array
    {
        $urlBase = self::normalizarUrlInstancia($urlInstancia);
        if ($urlBase === '') {
            return ['items_new' => 0, 'items_skipped' => 0, 'error' => 'URL de instancia inválida.'];
        }

        $idsTematicasHeredadas = wp_get_object_terms($idFuente, Topic::SLUG, ['fields' => 'ids']);
        if (is_wp_error($idsTematicasHeredadas)) {
            $idsTematicasHeredadas = [];
        }
        $idsTematicasHeredadas = array_map('intval', $idsTematicasHeredadas);

        $contadorNuevos = 0;
        $contadorDescartados = 0;
        $errores = [];

        $endpoints = [
            'board'  => ['path' => 'board',  'clave' => 'publicaciones', 'metodo' => 'normalizarPublicacion'],
            'events' => ['path' => 'events', 'clave' => 'eventos',       'metodo' => 'normalizarEvento'],
        ];

        $hostInstancia = parse_url($urlBase, PHP_URL_HOST) ?: 'desconocido';

        foreach ($endpoints as $nombreEndpoint => $config) {
            $url = $urlBase . 'wp-json/flavor-network/v1/' . $config['path']
                . '?per_page=' . self::MAXIMO_POR_ENDPOINT;
            $datosListos = self::obtenerListaDeEndpoint($url, $config['clave']);
            if ($datosListos === null) {
                $errores[] = $nombreEndpoint . ': endpoint no disponible';
                continue;
            }

            foreach ($datosListos as $registroBruto) {
                if (!is_array($registroBruto)) {
                    continue;
                }
                $datosNormalizados = self::{$config['metodo']}(
                    $registroBruto,
                    $urlBase,
                    $hostInstancia,
                    $nombreEndpoint
                );
                if ($datosNormalizados === null) {
                    continue;
                }
                if (FeedIngester::yaExisteItem($datosNormalizados['guid'], $datosNormalizados['permalink'])) {
                    $contadorDescartados++;
                    continue;
                }
                $idItem = FeedIngester::insertarItem($idFuente, $datosNormalizados, $idsTematicasHeredadas);
                if ($idItem > 0) {
                    $contadorNuevos++;
                }
            }
        }

        return [
            'items_new'     => $contadorNuevos,
            'items_skipped' => $contadorDescartados,
            'error'         => empty($errores) ? '' : implode('; ', $errores),
        ];
    }

    /**
     * Garantiza que la URL termine en `/` y con esquema, para que
     * `$urlBase . 'wp-json/...'` dé una URL válida sin duplicar barras.
     */
    private static function normalizarUrlInstancia(string $url): string
    {
        $urlLimpia = trim($url);
        if ($urlLimpia === '' || !preg_match('~^https?://~i', $urlLimpia)) {
            return '';
        }
        return rtrim($urlLimpia, '/') . '/';
    }

    /**
     * @return list<mixed>|null null si el endpoint no responde o el JSON
     *                           no tiene la forma esperada.
     */
    private static function obtenerListaDeEndpoint(string $url, string $claveLista): ?array
    {
        $respuesta = wp_remote_get($url, [
            'timeout' => self::TIMEOUT_HTTP_SEGUNDOS,
            'headers' => ['Accept' => 'application/json'],
        ]);
        if (is_wp_error($respuesta)) {
            return null;
        }
        if ((int) wp_remote_retrieve_response_code($respuesta) !== 200) {
            return null;
        }
        $decodificado = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        if (!is_array($decodificado)) {
            return null;
        }
        // Algunos endpoints devuelven `{clave:[...]}`, otros una lista pura.
        if (isset($decodificado[$claveLista]) && is_array($decodificado[$claveLista])) {
            return array_values($decodificado[$claveLista]);
        }
        if (array_is_list($decodificado)) {
            return $decodificado;
        }
        // Envoltorio `{data: [...]}` común en flavor-platform/v1.
        if (isset($decodificado['data']) && is_array($decodificado['data'])) {
            return array_values($decodificado['data']);
        }
        return null;
    }

    /**
     * Convierte una publicación del tablón al shape que espera
     * `FeedIngester::insertarItem()`. Devuelve null si faltan los campos
     * mínimos (título).
     *
     * @param array<string,mixed> $registro
     * @return array{title:string,excerpt:string,permalink:string,published_at:string,guid:string,media_url:string}|null
     */
    private static function normalizarPublicacion(
        array $registro,
        string $urlBase,
        string $hostInstancia,
        string $nombreEndpoint
    ): ?array {
        $idRemoto = (string) ($registro['id'] ?? '');
        $titulo = trim((string) ($registro['titulo'] ?? $registro['title'] ?? ''));
        if ($titulo === '' || $idRemoto === '') {
            return null;
        }
        $contenido = (string) ($registro['contenido'] ?? $registro['descripcion'] ?? '');
        $fechaBruta = (string) ($registro['fecha'] ?? $registro['created_at'] ?? $registro['fecha_publicacion'] ?? '');
        $imagen = (string) ($registro['imagen_url'] ?? $registro['imagen'] ?? '');
        return [
            'title'        => $titulo,
            'excerpt'      => wp_kses_post($contenido),
            // No hay page pública por publicación; enlazamos a la instancia y
            // añadimos un fragmento único para que el dedupe por URL no
            // colapse todas las publicaciones de la misma instancia.
            'permalink'    => self::permalinkUnico($urlBase, $nombreEndpoint, $idRemoto),
            'published_at' => self::normalizarFechaIso($fechaBruta),
            'guid'         => 'flavor-platform:' . $hostInstancia . ':' . $nombreEndpoint . ':' . $idRemoto,
            'media_url'    => $imagen !== '' ? esc_url_raw($imagen) : '',
        ];
    }

    /**
     * @param array<string,mixed> $registro
     * @return array{title:string,excerpt:string,permalink:string,published_at:string,guid:string,media_url:string}|null
     */
    private static function normalizarEvento(
        array $registro,
        string $urlBase,
        string $hostInstancia,
        string $nombreEndpoint
    ): ?array {
        $idRemoto = (string) ($registro['id'] ?? '');
        $titulo = trim((string) ($registro['titulo'] ?? ''));
        if ($titulo === '' || $idRemoto === '') {
            return null;
        }
        $descripcion = (string) ($registro['descripcion'] ?? '');
        // Los eventos usan fecha_inicio como evento-relevante; si no, caemos a created_at.
        $fechaBruta = (string) ($registro['fecha_inicio'] ?? $registro['created_at'] ?? '');
        $ubicacion = trim((string) ($registro['ubicacion'] ?? $registro['lugar'] ?? ''));
        $imagen = (string) ($registro['imagen'] ?? $registro['imagen_url'] ?? '');
        // Prefijo visible que deja claro que es un evento, no un titular.
        $extracto = '<p><strong>' . esc_html__('Evento', 'flavor-news-hub') . '</strong>';
        if ($ubicacion !== '') {
            $extracto .= ' — ' . esc_html($ubicacion);
        }
        $extracto .= '</p>';
        if ($descripcion !== '') {
            $extracto .= wp_kses_post($descripcion);
        }
        return [
            'title'        => $titulo,
            'excerpt'      => $extracto,
            'permalink'    => self::permalinkUnico($urlBase, $nombreEndpoint, $idRemoto),
            'published_at' => self::normalizarFechaIso($fechaBruta),
            'guid'         => 'flavor-platform:' . $hostInstancia . ':' . $nombreEndpoint . ':' . $idRemoto,
            'media_url'    => $imagen !== '' ? esc_url_raw($imagen) : '',
        ];
    }

    /**
     * Compone una URL única por entrada federada. Apunta a la instancia
     * (única landing pública que sabemos que existe) y añade un fragmento
     * identificador para que el dedupe por URL original distinga una
     * publicación de otra del mismo nodo.
     */
    private static function permalinkUnico(string $urlBase, string $nombreEndpoint, string $idRemoto): string
    {
        return $urlBase . '#fnh-federado-' . $nombreEndpoint . '-' . $idRemoto;
    }

    /**
     * La API de Flavor Platform devuelve fechas en formato MySQL local
     * (`YYYY-MM-DD HH:MM:SS`) sin TZ. Las tratamos como UTC para ser
     * consistentes con el resto del feed; es mejor un sesgo de pocas horas
     * que una fecha sin hora que acabaría en el top por orden.
     */
    private static function normalizarFechaIso(string $fechaBruta): string
    {
        if ($fechaBruta === '') {
            return '';
        }
        $timestamp = strtotime($fechaBruta . ' UTC');
        if ($timestamp === false) {
            $timestamp = strtotime($fechaBruta);
            if ($timestamp === false) {
                return '';
            }
        }
        return gmdate('c', $timestamp);
    }
}
