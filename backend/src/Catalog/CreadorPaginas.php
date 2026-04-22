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
            'clave'        => 'inicio',
            'titulo'       => 'Inicio',
            'slug'         => 'inicio',
            'shortcode'    => '[flavor_news_landing]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
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
        [
            'clave'        => 'tv',
            'titulo'       => 'TV',
            'slug'         => 'tv',
            'shortcode'    => '[flavor_news_tv]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'podcasts',
            'titulo'       => 'Podcasts',
            'slug'         => 'podcasts',
            'shortcode'    => '[flavor_news_podcasts per_page="30"]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'fuentes',
            'titulo'       => 'Fuentes',
            'slug'         => 'fuentes',
            'shortcode'    => '[flavor_news_sources]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
        [
            'clave'        => 'sobre',
            'titulo'       => 'Sobre el proyecto',
            'slug'         => 'sobre',
            'shortcode'    => '[flavor_news_sobre]',
            'preset_vbp'   => 'modern',
            'secciones_vbp'=> ['hero'],
        ],
    ];

    /**
     * Devuelve el estado de cada página auto-generada: si existe, su ID, URL pública y URL de edición.
     *
     * @return list<array{clave:string,titulo:string,slug:string,id:int,url:string,edit_url:string}>
     */
    public static function obtenerEstadoPaginas(): array
    {
        $estado = [];
        foreach (self::PAGINAS as $config) {
            $config = self::normalizarConfigPagina($config);
            $consulta = new \WP_Query([
                'post_type'      => 'page',
                'post_status'    => ['publish', 'draft', 'pending'],
                'posts_per_page' => 1,
                'no_found_rows'  => true,
                'meta_key'       => '_fnh_pagina_auto',
                'meta_value'     => $config['clave'],
            ]);
            $id      = 0;
            $url     = '';
            $editUrl = '';
            if (!empty($consulta->posts)) {
                $post    = $consulta->posts[0];
                $id      = (int) $post->ID;
                $url     = (string) (get_permalink($id) ?: '');
                $editUrl = (string) (get_edit_post_link($id, 'url') ?: '');
            }
            $estado[] = [
                'clave'    => $config['clave'],
                'titulo'   => $config['titulo'],
                'slug'     => $config['slug'],
                'id'       => $id,
                'url'      => $url,
                'edit_url' => $editUrl,
            ];
        }
        return $estado;
    }

    public static function crearSiNoExisten(): void
    {
        if (function_exists('pll_languages_list')) {
            self::crearParaPolylang();
            return;
        }
        if (has_filter('wpml_default_language')) {
            self::crearParaWpml();
            return;
        }

        foreach (self::PAGINAS as $config) {
            $config = self::normalizarConfigPagina($config);
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

    private static function crearParaWpml(): void
    {
        $idiomas = self::idiomasActivosWpml();
        if ($idiomas === []) {
            return;
        }

        foreach (self::PAGINAS as $configBase) {
            $mapaTraducciones = self::reconciliarPaginasExistentesWpml($configBase['clave']);
            $idiomaOriginal = self::idiomaOriginalTraduccionesWpml($mapaTraducciones);

            foreach ($idiomas as $idioma) {
                $config = self::normalizarConfigPaginaEnIdioma($configBase, $idioma);
                $existente = $mapaTraducciones[$idioma] ?? self::buscarPaginaPorClaveEIdioma($config['clave'], $idioma);
                if ($existente > 0) {
                    $mapaTraducciones[$idioma] = $existente;
                    continue;
                }

                $idPagina = self::vbpDisponible()
                    ? self::crearConVbp($config)
                    : 0;
                if ($idPagina === 0) {
                    $idPagina = self::crearPlana($config);
                }
                if ($idPagina <= 0) {
                    continue;
                }

                update_post_meta($idPagina, '_fnh_pagina_auto', $config['clave']);
                update_post_meta($idPagina, '_fnh_pagina_auto_lang', $idioma);
                self::asignarIdiomaWpml($idPagina, $idioma, $mapaTraducciones[$idiomaOriginal] ?? 0, $idiomaOriginal);
                $mapaTraducciones[$idioma] = $idPagina;
                $idiomaOriginal = self::idiomaOriginalTraduccionesWpml($mapaTraducciones);
            }
        }
    }

    private static function crearParaPolylang(): void
    {
        $idiomas = pll_languages_list(['fields' => 'slug']);
        if (!is_array($idiomas) || empty($idiomas)) {
            return;
        }

        foreach (self::PAGINAS as $configBase) {
            $mapaTraducciones = self::reconciliarPaginasExistentesPolylang($configBase['clave']);
            foreach ($idiomas as $idioma) {
                if (!is_string($idioma) || $idioma === '') {
                    continue;
                }

                $config = self::normalizarConfigPaginaEnIdioma($configBase, $idioma);
                $existente = $mapaTraducciones[$idioma] ?? self::buscarPaginaPorClaveEIdioma($config['clave'], $idioma);
                if ($existente > 0) {
                    $mapaTraducciones[$idioma] = $existente;
                    continue;
                }

                $idPagina = self::vbpDisponible()
                    ? self::crearConVbp($config)
                    : 0;
                if ($idPagina === 0) {
                    $idPagina = self::crearPlana($config);
                }
                if ($idPagina <= 0) {
                    continue;
                }

                update_post_meta($idPagina, '_fnh_pagina_auto', $config['clave']);
                update_post_meta($idPagina, '_fnh_pagina_auto_lang', $idioma);
                pll_set_post_language($idPagina, $idioma);
                $mapaTraducciones[$idioma] = $idPagina;
            }

            if (count($mapaTraducciones) > 1) {
                pll_save_post_translations($mapaTraducciones);
            }
        }
    }

    /**
     * @return array<string,int>
     */
    private static function reconciliarPaginasExistentesPolylang(string $clave): array
    {
        $consulta = new \WP_Query([
            'post_type'      => 'page',
            'post_status'    => ['publish', 'draft', 'pending'],
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_key'       => '_fnh_pagina_auto',
            'meta_value'     => $clave,
        ]);

        $idiomaPorDefecto = self::idiomaPorDefectoPolylang();
        $mapa = [];
        foreach ($consulta->posts as $postId) {
            $postId = (int) $postId;
            if ($postId <= 0) {
                continue;
            }

            $idioma = self::resolverIdiomaPaginaPolylang($postId, $idiomaPorDefecto);
            if ($idioma === '') {
                continue;
            }

            update_post_meta($postId, '_fnh_pagina_auto_lang', $idioma);
            pll_set_post_language($postId, $idioma);
            $mapa[$idioma] = $postId;
        }

        if (count($mapa) > 1) {
            pll_save_post_translations($mapa);
        }

        return $mapa;
    }

    /**
     * @return array<string,int>
     */
    private static function reconciliarPaginasExistentesWpml(string $clave): array
    {
        $consulta = new \WP_Query([
            'post_type'      => 'page',
            'post_status'    => ['publish', 'draft', 'pending'],
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_key'       => '_fnh_pagina_auto',
            'meta_value'     => $clave,
        ]);

        $idiomaPorDefecto = self::idiomaPorDefectoWpml();
        $mapa = [];
        foreach ($consulta->posts as $postId) {
            $postId = (int) $postId;
            if ($postId <= 0) {
                continue;
            }

            $idioma = self::resolverIdiomaPaginaWpml($postId, $idiomaPorDefecto);
            if ($idioma === '') {
                continue;
            }

            update_post_meta($postId, '_fnh_pagina_auto_lang', $idioma);
            $mapa[$idioma] = $postId;
        }

        $idiomaOriginal = self::idiomaOriginalTraduccionesWpml($mapa);
        $idOriginal = $mapa[$idiomaOriginal] ?? 0;
        foreach ($mapa as $idioma => $postId) {
            self::asignarIdiomaWpml($postId, $idioma, $idOriginal, $idiomaOriginal);
        }

        return $mapa;
    }

    private static function idiomaPorDefectoPolylang(): string
    {
        if (function_exists('pll_default_language')) {
            $idioma = pll_default_language('slug');
            if (is_string($idioma)) {
                return $idioma;
            }
        }

        return '';
    }

    private static function idiomaPorDefectoWpml(): string
    {
        $idioma = apply_filters('wpml_default_language', null);
        return is_string($idioma) ? $idioma : '';
    }

    private static function resolverIdiomaPaginaPolylang(int $postId, string $fallback): string
    {
        $meta = (string) get_post_meta($postId, '_fnh_pagina_auto_lang', true);
        if ($meta !== '') {
            return $meta;
        }

        if (function_exists('pll_get_post_language')) {
            $idioma = pll_get_post_language($postId, 'slug');
            if (is_string($idioma) && $idioma !== '') {
                return $idioma;
            }
        }

        return $fallback;
    }

    private static function resolverIdiomaPaginaWpml(int $postId, string $fallback): string
    {
        $meta = (string) get_post_meta($postId, '_fnh_pagina_auto_lang', true);
        if ($meta !== '') {
            return $meta;
        }

        $idioma = apply_filters('wpml_element_language_code', null, [
            'element_id'   => $postId,
            'element_type' => 'page',
        ]);
        if (is_string($idioma) && $idioma !== '') {
            return $idioma;
        }

        return $fallback;
    }

    /**
     * @return list<string>
     */
    private static function idiomasActivosWpml(): array
    {
        $idiomas = [];
        $activos = apply_filters('wpml_active_languages', null, ['skip_missing' => 0, 'orderby' => 'code']);
        if (is_array($activos)) {
            foreach ($activos as $codigo => $datos) {
                if (is_string($codigo) && $codigo !== '') {
                    $idiomas[] = $codigo;
                } elseif (is_array($datos) && is_string($datos['language_code'] ?? null) && $datos['language_code'] !== '') {
                    $idiomas[] = $datos['language_code'];
                }
            }
        }

        if ($idiomas === []) {
            $porDefecto = self::idiomaPorDefectoWpml();
            if ($porDefecto !== '') {
                $idiomas[] = $porDefecto;
            }
        }

        return array_values(array_unique($idiomas));
    }

    /**
     * @param array<string,int> $mapa
     */
    private static function idiomaOriginalTraduccionesWpml(array $mapa): string
    {
        $porDefecto = self::idiomaPorDefectoWpml();
        if ($porDefecto !== '' && isset($mapa[$porDefecto])) {
            return $porDefecto;
        }

        return $mapa === [] ? $porDefecto : (string) array_key_first($mapa);
    }

    private static function asignarIdiomaWpml(int $postId, string $idioma, int $idOriginal, string $idiomaOriginal): void
    {
        $elementType = apply_filters('wpml_element_type', 'page');
        $trid = false;
        $sourceLanguageCode = null;

        if ($idOriginal > 0) {
            $infoOriginal = apply_filters('wpml_element_language_details', null, [
                'element_id'   => $idOriginal,
                'element_type' => 'page',
            ]);
            if (is_object($infoOriginal) && isset($infoOriginal->trid)) {
                $trid = $infoOriginal->trid;
                $sourceLanguageCode = $idioma === $idiomaOriginal ? null : $idiomaOriginal;
            }
        }

        do_action('wpml_set_element_language_details', [
            'element_id'            => $postId,
            'element_type'          => $elementType,
            'trid'                  => $trid,
            'language_code'         => $idioma,
            'source_language_code'  => $sourceLanguageCode,
        ]);
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

    private static function buscarPaginaPorClaveEIdioma(string $clave, string $idioma): int
    {
        $consulta = new \WP_Query([
            'post_type'      => 'page',
            'post_status'    => ['publish', 'draft', 'pending'],
            'posts_per_page' => 1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [
                'relation' => 'AND',
                [
                    'key'   => '_fnh_pagina_auto',
                    'value' => $clave,
                ],
                [
                    'key'   => '_fnh_pagina_auto_lang',
                    'value' => $idioma,
                ],
            ],
        ]);

        return !empty($consulta->posts) ? (int) $consulta->posts[0] : 0;
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
     * @param array{clave:string,titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>} $config
     * @return array{clave:string,titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>}
     */
    private static function normalizarConfigPagina(array $config): array
    {
        $config['titulo'] = self::traducirTituloPagina($config['clave'], $config['titulo']);
        $config['slug'] = self::traducirSlugPagina($config['clave'], $config['slug']);
        self::registrarCadenaTraducible($config['clave'], $config['titulo'], $config['slug']);
        return $config;
    }

    /**
     * @param array{clave:string,titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>} $config
     * @return array{clave:string,titulo:string,slug:string,shortcode:string,preset_vbp:string,secciones_vbp:list<string>}
     */
    private static function normalizarConfigPaginaEnIdioma(array $config, string $idioma): array
    {
        $tituloOriginal = $config['titulo'];
        $slugOriginal = $config['slug'];

        if (function_exists('pll_translate_string')) {
            $config['titulo'] = (string) pll_translate_string($tituloOriginal, $idioma);
            $config['slug'] = sanitize_title((string) pll_translate_string($slugOriginal, $idioma));
        } else {
            $config = self::normalizarConfigPagina($config);
        }

        $config['titulo'] = (string) apply_filters('fnh_page_title_for_language', $config['titulo'], $config['clave'], $idioma);
        $config['slug'] = sanitize_title((string) apply_filters('fnh_page_slug_for_language', $config['slug'], $config['clave'], $idioma));

        return $config;
    }

    private static function traducirTituloPagina(string $clave, string $titulo): string
    {
        $titulo = (string) apply_filters('fnh_page_title', $titulo, $clave);
        if (function_exists('pll__')) {
            $titulo = (string) pll__($titulo);
        }
        return $titulo;
    }

    private static function traducirSlugPagina(string $clave, string $slug): string
    {
        $slug = (string) apply_filters('fnh_page_slug', $slug, $clave);

        if (has_filter('wpml_translate_single_string')) {
            $traducido = apply_filters('wpml_translate_single_string', $slug, 'flavor-news-hub', 'page-slug-' . $clave);
            if (is_string($traducido) && $traducido !== '') {
                $slug = $traducido;
            }
        }

        return sanitize_title($slug);
    }

    private static function registrarCadenaTraducible(string $clave, string $titulo, string $slug): void
    {
        if (function_exists('pll_register_string')) {
            pll_register_string('fnh_page_title_' . $clave, $titulo, 'flavor-news-hub');
            pll_register_string('fnh_page_slug_' . $clave, $slug, 'flavor-news-hub');
        }

        do_action('wpml_register_single_string', 'flavor-news-hub', 'page-title-' . $clave, $titulo);
        do_action('wpml_register_single_string', 'flavor-news-hub', 'page-slug-' . $clave, $slug);
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
