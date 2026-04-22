<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

/**
 * Crea automáticamente las páginas frontend del plugin (Noticias,
 * Radios, Vídeos, Colectivos) si no existen. Idempotente: marca las
 * páginas generadas con `_fnh_pagina_auto` y no las recrea.
 *
 * Integración con Flavor Platform + VBP (Visual Builder Pro):
 *  - Si VBP está disponible (función `flavor_get_vbp_api_key` expuesta
 *    por Flavor Platform), usamos su endpoint REST interno para crear
 *    la página con un preset visual ("modern") y un bloque shortcode
 *    dentro. Mantiene coherencia con el resto de páginas de FP.
 *  - Si VBP no está, creamos páginas WP planas con el shortcode como
 *    contenido. Sirven igual, sólo sin los bloques de presentación
 *    preconstruidos.
 */
final class CreadorPaginas
{
    /**
     * Definición de las páginas a crear. `slug` es el path público;
     * `shortcode` es el contenido mínimo que hace que la página sea
     * útil; `preset_vbp` y `secciones_vbp` sólo se usan si VBP está
     * disponible — si no, se ignoran y cae a contenido plano.
     *
     * @var list<array{clave:string,titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>}>
     */
    private const PAGINAS = [
        [
            'clave'        => 'noticias',
            'titulo'       => 'Noticias',
            'slug'         => 'noticias',
            'shortcode'    => '[flavor_news_feed per_page="20"]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'radios',
            'titulo'       => 'Radios libres',
            'slug'         => 'radios',
            'shortcode'    => '[flavor_news_radios]',
            'preset_vbp'   => 'community',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'videos',
            'titulo'       => 'Vídeos',
            'slug'         => 'videos',
            'shortcode'    => '[flavor_news_videos per_page="20"]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'colectivos',
            'titulo'       => 'Colectivos',
            'slug'         => 'colectivos',
            'shortcode'    => '[flavor_news_feed per_page="20"]', // placeholder; hay shortcode de colectivos?
            'preset_vbp'   => 'community',
            'secciones_vbp'=> ['hero'],
        ],
    ];

    public static function crearSiNoExisten(): void
    {
        foreach (self::PAGINAS as $config) {
            if (self::yaExiste($config['clave'])) {
                continue;
            }
            $idPagina = self::vbpDisponible()
                ? self::crearConVbp($config)
                : 0;
            if ($idPagina === 0) {
                $idPagina = self::crearPlana($config);
            }
            if ($idPagina > 0) {
                update_post_meta($idPagina, '_fnh_pagina_auto', $config['clave']);
            }
        }
    }

    private static function yaExiste(string $clave): bool
    {
        $consulta = new \WP_Query([
            'post_type'      => 'page',
            'post_status'    => ['publish', 'draft', 'pending'],
            'posts_per_page' => 1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_key'       => '_fnh_pagina_auto',
            'meta_value'     => $clave,
        ]);
        return !empty($consulta->posts);
    }

    /**
     * @param array{titulo:string,slug:string,shortcode:string} $config
     */
    private static function crearPlana(array $config): int
    {
        $idPagina = wp_insert_post([
            'post_type'    => 'page',
            'post_status'  => 'publish',
            'post_title'   => $config['titulo'],
            'post_name'    => $config['slug'],
            'post_content' => $config['shortcode'],
        ], true);
        return is_int($idPagina) ? $idPagina : 0;
    }

    private static function vbpDisponible(): bool
    {
        return function_exists('flavor_get_vbp_api_key');
    }

    /**
     * Intenta crear la página vía el endpoint de VBP. Si algo falla (API
     * key no resoluble, endpoint desactivado, HTTP no 2xx), devolvemos 0
     * para que el caller caiga al método plano.
     *
     * @param array{titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>} $config
     */
    private static function crearConVbp(array $config): int
    {
        $apiKey = \flavor_get_vbp_api_key();
        if (!is_string($apiKey) || $apiKey === '') {
            return 0;
        }
        $urlEndpoint = rest_url('flavor-vbp/v1/claude/pages/styled');
        $respuesta = wp_remote_post($urlEndpoint, [
            'headers' => [
                'X-VBP-Key'    => $apiKey,
                'Content-Type' => 'application/json',
            ],
            'timeout' => 20,
            'body'    => wp_json_encode([
                'title'    => $config['titulo'],
                'slug'     => $config['slug'],
                'preset'   => $config['preset_vbp'],
                'sections' => $config['secciones_vbp'],
                'status'   => 'publish',
                // Extra: inyectamos el shortcode como bloque de
                // contenido al final. VBP suele aceptar un
                // `content_after_sections` o `extra_content`; si no
                // lo reconoce, la página queda con sus secciones y
                // sin listado — el fallback plano la completa luego.
                'extra_content' => $config['shortcode'],
            ]),
        ]);
        if (is_wp_error($respuesta)) {
            return 0;
        }
        $http = (int) wp_remote_retrieve_response_code($respuesta);
        if ($http < 200 || $http >= 300) {
            return 0;
        }
        $body = json_decode((string) wp_remote_retrieve_body($respuesta), true);
        $idCreado = is_array($body) ? (int) ($body['page_id'] ?? $body['id'] ?? 0) : 0;
        if ($idCreado <= 0) {
            return 0;
        }
        // Aseguramos que el shortcode esté en el contenido. Si VBP
        // no incluyó `extra_content`, lo añadimos al post_content
        // después de sus secciones — es la única manera de
        // garantizar que el listado aparece.
        $post = get_post($idCreado);
        if ($post instanceof \WP_Post && !str_contains((string) $post->post_content, $config['shortcode'])) {
            wp_update_post([
                'ID'           => $idCreado,
                'post_content' => trim($post->post_content . "\n\n" . $config['shortcode']),
            ]);
        }
        return $idCreado;
    }
}
