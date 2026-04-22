<?php
declare(strict_types=1);

namespace FlavorNewsHub\Shortcodes;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\ItemTransformer;

/**
 * Shortcodes del plugin: permiten incrustar feeds, radios y vídeos en
 * cualquier página o post de WordPress. Útil para que un colectivo monte
 * su página de "qué leer hoy" sin necesidad de usar bloques Gutenberg
 * complejos.
 *
 * Shortcodes disponibles:
 *  - [flavor_news_feed]      → lista de titulares más recientes
 *  - [flavor_news_radios]    → tarjetas de radios activas
 *  - [flavor_news_videos]    → grid de vídeos recientes
 *  - [flavor_news_source]    → ficha editorial de un medio
 *
 * Todos respetan los filtros de territorio / idioma / topic del feed
 * principal. El markup es HTML semántico + clases CSS sencillas que el
 * tema puede sobreescribir — evitamos JS si no hace falta para no cargar
 * peso innecesario.
 */
final class Shortcodes
{
    public static function registrar(): void
    {
        add_shortcode('flavor_news_feed', [self::class, 'renderFeed']);
        add_shortcode('flavor_news_radios', [self::class, 'renderRadios']);
        add_shortcode('flavor_news_videos', [self::class, 'renderVideos']);
        add_shortcode('flavor_news_source', [self::class, 'renderSource']);
        add_shortcode('flavor_news_landing', [self::class, 'renderLanding']);
        add_action('wp_enqueue_scripts', [self::class, 'cargarEstilos']);
        // Prio 12: después de do_shortcode (11). Cuando la landing vive
        // en una página con bloques alrededor (VBP u otros), WordPress
        // envuelve el shortcode en `<p>...</p>` y shortcode_unautop no
        // lo limpia porque no está solo. Desenvolvemos a posteriori.
        add_filter('the_content', [self::class, 'desenvolverLanding'], 12);
    }

    /**
     * Elimina `<p>` / `</p>` rodeando nuestra landing cuando quedan
     * colgando tras wpautop. La landing es un bloque de nivel block;
     * meterla dentro de un `<p>` produce HTML inválido y rompe
     * layouts.
     */
    public static function desenvolverLanding(string $contenido): string
    {
        $resultado = preg_replace(
            '#<p>(\s*<div class="fnh-landing[^"]*">.*?</div>\s*)</p>#s',
            '$1',
            $contenido
        );
        return $resultado === null ? $contenido : $resultado;
    }

    /**
     * Encola un CSS ligero con estilos base. Sólo se carga cuando el
     * shortcode se usa en la página (el hook va por post_content).
     */
    public static function cargarEstilos(): void
    {
        if (!is_singular()) {
            return;
        }
        global $post;
        if (!$post || !has_shortcode($post->post_content, 'flavor_news_feed')
            && !has_shortcode($post->post_content, 'flavor_news_radios')
            && !has_shortcode($post->post_content, 'flavor_news_videos')
            && !has_shortcode($post->post_content, 'flavor_news_source')
            && !has_shortcode($post->post_content, 'flavor_news_landing')) {
            return;
        }
        $css = "
        .fnh-feed-lista,.fnh-radios-lista,.fnh-videos-grid{list-style:none;padding:0;margin:0}
        .fnh-feed-lista li{padding:12px 0;border-bottom:1px solid #ececec}
        .fnh-feed-lista h3{margin:0 0 4px;font-size:1.05em;line-height:1.3}
        .fnh-feed-lista .fnh-meta{font-size:.85em;color:#666}
        .fnh-videos-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}
        .fnh-videos-grid .fnh-video{background:#000;border-radius:8px;overflow:hidden;position:relative;aspect-ratio:16/9}
        .fnh-videos-grid .fnh-video img{width:100%;height:100%;object-fit:cover;display:block}
        .fnh-videos-grid .fnh-video .fnh-video-title{position:absolute;bottom:0;left:0;right:0;padding:8px;background:linear-gradient(transparent,rgba(0,0,0,.75));color:#fff;font-size:.9em}
        .fnh-radios-lista{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:10px}
        .fnh-radios-lista .fnh-radio{border:1px solid #ececec;border-radius:8px;padding:10px}
        .fnh-radios-lista .fnh-radio h4{margin:0 0 4px;font-size:.95em}
        .fnh-radios-lista .fnh-radio a.fnh-listen{display:inline-block;margin-top:4px}
        #fnh-landing{display:flex !important;flex-direction:column;gap:3rem;padding:1rem 1.25rem !important;max-width:1100px;margin-inline:auto;font-family:inherit;line-height:1.5;color:#111 !important;background:transparent !important}
        #fnh-landing *{box-sizing:border-box}
        #fnh-landing h1,#fnh-landing h2,#fnh-landing h3{font-family:inherit;color:#111 !important;font-weight:700}
        #fnh-landing a{color:inherit;text-decoration:none}
        #fnh-landing .fnh-hero{text-align:center !important;padding:2rem 0 1rem !important;border-bottom:1px solid #ececec;margin:0 !important;background:transparent !important}
        #fnh-landing .fnh-hero h1{font-size:2.2em !important;margin:0 0 .4em !important;border:0;padding:0 !important;color:#111 !important}
        #fnh-landing .fnh-hero .fnh-lema{font-size:1.15em !important;color:#555 !important;max-width:42ch;margin:0 auto !important}
        #fnh-landing .fnh-bloque{margin:0 !important;padding:0 !important;background:transparent !important}
        #fnh-landing .fnh-bloque h2{margin:0 0 1rem !important;font-size:1.4em !important;border-bottom:2px solid #111 !important;padding-bottom:.3em !important;display:inline-block !important;color:#111 !important;background:transparent !important}
        #fnh-landing .fnh-ver-mas{margin-top:.75rem;text-align:right}
        #fnh-landing .fnh-ver-mas a{color:#555;text-decoration:none;font-size:.92em}
        #fnh-landing .fnh-ver-mas a:hover{color:#000}
        #fnh-landing .fnh-sonando-cols{display:grid;grid-template-columns:1fr 1fr;gap:2rem}
        #fnh-landing .fnh-sonando-col h3{margin:0 0 .6rem;font-size:1em;text-transform:uppercase;letter-spacing:.05em;color:#666}
        @media (max-width:640px){#fnh-landing .fnh-sonando-cols{grid-template-columns:1fr}}
        #fnh-landing .fnh-destacado .fnh-embed-ratio{position:relative;width:100%;aspect-ratio:16/9;background:#000;border-radius:10px;overflow:hidden}
        #fnh-landing .fnh-destacado .fnh-embed-ratio iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
        #fnh-landing .fnh-destacado .fnh-destacado-card{display:block;aspect-ratio:16/9;background:#000;border-radius:10px;overflow:hidden}
        #fnh-landing .fnh-destacado .fnh-destacado-card img{width:100%;height:100%;object-fit:cover;display:block}
        #fnh-landing .fnh-destacado .fnh-destacado-meta{margin-top:.6rem;font-size:.95em;color:#444}
        #fnh-landing .fnh-descarga{background:#0a0a0a !important;color:#fff !important;padding:2rem !important;border-radius:12px !important;text-align:center !important}
        #fnh-landing .fnh-descarga h2{margin-top:0 !important;color:#fff !important;border-color:#3ddc84 !important}
        #fnh-landing .fnh-descarga .fnh-version{font-size:.9em;opacity:.75;margin-bottom:1.2em !important;color:#fff !important}
        #fnh-landing .fnh-boton-descarga{display:inline-block !important;padding:.9rem 2rem !important;background:#3ddc84 !important;color:#0a0a0a !important;border-radius:999px !important;font-weight:700 !important;text-decoration:none !important;font-size:1.05em !important}
        #fnh-landing .fnh-boton-descarga:hover{background:#5ae89a !important}
        #fnh-landing .fnh-repo{text-align:center;font-size:.9em;color:#777}

        /* Noticias dentro de la landing: tarjeta horizontal (imagen izquierda, texto derecha). */
        #fnh-landing .fnh-feed-lista{display:flex !important;flex-direction:column;gap:1.1rem}
        #fnh-landing .fnh-feed-lista li{display:grid !important;grid-template-columns:220px 1fr;gap:1.1rem;padding:0 0 1.1rem !important;border-bottom:1px solid #ececec;align-items:start;background:transparent !important}
        #fnh-landing .fnh-feed-lista li:last-child{border-bottom:0}
        #fnh-landing .fnh-feed-lista .fnh-media{order:-1;margin:0 !important;grid-column:1}
        #fnh-landing .fnh-feed-lista .fnh-media img{width:100% !important;height:140px !important;object-fit:cover;border-radius:8px !important;display:block;margin:0 !important;max-width:100% !important}
        #fnh-landing .fnh-feed-lista h3{margin:0 0 .35em !important;font-size:1.05em !important;line-height:1.3 !important;font-weight:700 !important}
        #fnh-landing .fnh-feed-lista h3 a{color:#111 !important;text-decoration:none !important}
        #fnh-landing .fnh-feed-lista h3 a:hover{text-decoration:underline !important}
        #fnh-landing .fnh-feed-lista .fnh-meta{font-size:.82em !important;color:#777 !important;margin-bottom:.4em}
        #fnh-landing .fnh-feed-lista .fnh-excerpt{font-size:.92em;color:#333;line-height:1.5}
        #fnh-landing .fnh-feed-lista .fnh-excerpt p{margin:.25em 0 !important}

        /* En la columna de Podcasts recientes los items son compactos y sin imagen. */
        #fnh-landing .fnh-sonando-col .fnh-feed-lista li{display:block !important;grid-template-columns:none !important;padding:.7rem 0 !important}
        #fnh-landing .fnh-sonando-col .fnh-feed-lista .fnh-media{display:none !important}
        #fnh-landing .fnh-sonando-col .fnh-feed-lista .fnh-excerpt{display:none !important}
        #fnh-landing .fnh-sonando-col .fnh-feed-lista h3{font-size:.95em !important}

        /* Móvil: noticias a columna única. */
        @media (max-width:640px){
          #fnh-landing .fnh-feed-lista li{grid-template-columns:1fr !important}
          #fnh-landing .fnh-feed-lista .fnh-media img{height:200px !important}
        }

        /* Vídeos: 4 columnas en desktop, 2 en tablet, 1 en móvil. */
        #fnh-landing .fnh-videos-grid{display:grid !important;grid-template-columns:repeat(4,1fr) !important;gap:12px !important}
        @media (max-width:900px){#fnh-landing .fnh-videos-grid{grid-template-columns:repeat(2,1fr) !important}}
        @media (max-width:500px){#fnh-landing .fnh-videos-grid{grid-template-columns:1fr !important}}

        /* Radios: cards con sombra y hover claro. */
        #fnh-landing .fnh-radios-lista{display:grid !important;grid-template-columns:1fr !important;gap:.75rem !important;padding:0 !important;list-style:none !important}
        #fnh-landing .fnh-radios-lista .fnh-radio{padding:1rem !important;border:1px solid #e5e5e5 !important;border-radius:12px !important;background:#fff !important;box-shadow:0 1px 3px rgba(0,0,0,.04) !important;transition:box-shadow .15s,transform .15s;list-style:none !important}
        #fnh-landing .fnh-radios-lista .fnh-radio:hover{box-shadow:0 4px 12px rgba(0,0,0,.08) !important;transform:translateY(-1px)}
        #fnh-landing .fnh-radios-lista .fnh-radio h4{margin:0 0 .25em !important;font-size:1em !important;font-weight:600 !important;color:#111 !important}
        #fnh-landing .fnh-radios-lista .fnh-radio .fnh-meta{font-size:.82em !important;color:#777 !important;margin-bottom:.5em}
        #fnh-landing .fnh-radios-lista .fnh-radio audio{width:100% !important;height:36px;margin:.35em 0 !important;display:block}
        #fnh-landing .fnh-radios-lista .fnh-radio .fnh-listen{display:inline-block;margin-top:.4em !important;font-size:.88em !important;color:#3b7bdb !important;text-decoration:none !important}
        #fnh-landing .fnh-radios-lista .fnh-radio .fnh-listen:hover{text-decoration:underline !important}
        ";
        wp_register_style('flavor-news-hub-shortcodes', false);
        wp_enqueue_style('flavor-news-hub-shortcodes');
        wp_add_inline_style('flavor-news-hub-shortcodes', $css);
    }

    /**
     * [flavor_news_feed limit="10" topic="ecologia" territory="catalunya" source_type="rss" show_excerpt="1"]
     */
    public static function renderFeed($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'limit'          => 10,
            'topic'          => '',
            'territory'      => '',
            'language'       => '',
            'source'         => 0,
            'source_type'    => '',
            'exclude_source_type' => 'video,youtube,podcast',
            'show_excerpt'   => 1,
            'show_media'     => 1,
        ], $atribs);

        $query = [
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => (int) $a['limit'],
            'orderby'        => 'meta_value',
            'meta_key'       => '_fnh_published_at',
            'order'          => 'DESC',
        ];
        if ($a['topic'] !== '') {
            $query['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', explode(',', $a['topic'])),
            ]];
        }
        if ((int) $a['source'] > 0) {
            $query['meta_query'] = [['key' => '_fnh_source_id', 'value' => (int) $a['source']]];
        }
        // Para territory/language/source_type reutilizamos la lógica del
        // endpoint REST para mantener una única verdad.
        if ($a['territory'] !== '' || $a['language'] !== '' || $a['source_type'] !== '' || $a['exclude_source_type'] !== '') {
            $idsSources = self::resolverIdsSources(
                (string) $a['territory'],
                (string) $a['language'],
                (string) $a['source_type'],
                (string) $a['exclude_source_type']
            );
            if (empty($idsSources)) {
                return '<p class="fnh-empty">' . esc_html__('Sin titulares que mostrar.', 'flavor-news-hub') . '</p>';
            }
            $query['meta_query'] = $query['meta_query'] ?? [];
            $query['meta_query'][] = [
                'key'     => '_fnh_source_id',
                'value'   => array_map('strval', $idsSources),
                'compare' => 'IN',
            ];
        }

        $consulta = new \WP_Query($query);
        if (empty($consulta->posts)) {
            return '<p class="fnh-empty">' . esc_html__('Sin titulares que mostrar.', 'flavor-news-hub') . '</p>';
        }

        ob_start();
        echo '<ul class="fnh-feed-lista">';
        foreach ($consulta->posts as $post) {
            $datos = ItemTransformer::transformar($post);
            $fuenteNombre = $datos['source']['name'] ?? '';
            $urlOriginal = $datos['original_url'] ?: $datos['url'];
            printf(
                '<li><h3><a href="%s" target="_blank" rel="noopener">%s</a></h3>',
                esc_url($urlOriginal),
                esc_html($datos['title'])
            );
            echo '<div class="fnh-meta">' . esc_html($fuenteNombre);
            if (!empty($datos['published_at'])) {
                $fecha = date_i18n(get_option('date_format', 'F j, Y'), strtotime($datos['published_at']));
                echo ' · ' . esc_html($fecha);
            }
            echo '</div>';
            if ((int) $a['show_media'] === 1 && !empty($datos['media_url'])) {
                printf(
                    '<div class="fnh-media"><img src="%s" alt="" loading="lazy" /></div>',
                    esc_url($datos['media_url'])
                );
            }
            if ((int) $a['show_excerpt'] === 1 && !empty($datos['excerpt'])) {
                echo '<div class="fnh-excerpt">' . wp_kses_post($datos['excerpt']) . '</div>';
            }
            echo '</li>';
        }
        echo '</ul>';
        return (string) ob_get_clean();
    }

    /**
     * [flavor_news_radios limit="20" territory="euskal herria" language="eu"]
     */
    public static function renderRadios($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'limit'     => 50,
            'territory' => '',
            'language'  => '',
        ], $atribs);

        $query = [
            'post_type'      => Radio::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => (int) $a['limit'],
            'orderby'        => 'title',
            'order'          => 'ASC',
            'meta_query'     => [
                'relation' => 'OR',
                ['key' => '_fnh_active', 'value' => '1', 'compare' => '='],
                ['key' => '_fnh_active', 'compare' => 'NOT EXISTS'],
            ],
        ];
        if ($a['territory'] !== '') {
            $query['meta_query'][] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field((string) $a['territory']),
                'compare' => 'LIKE',
            ];
        }
        if ($a['language'] !== '') {
            $query['meta_query'][] = [
                'key'     => '_fnh_languages',
                'value'   => sanitize_key((string) $a['language']),
                'compare' => 'LIKE',
            ];
        }
        $consulta = new \WP_Query($query);
        if (empty($consulta->posts)) {
            return '<p class="fnh-empty">' . esc_html__('No hay radios activas.', 'flavor-news-hub') . '</p>';
        }
        ob_start();
        echo '<ul class="fnh-radios-lista">';
        foreach ($consulta->posts as $post) {
            $id = (int) $post->ID;
            $stream = (string) get_post_meta($id, '_fnh_stream_url', true);
            $web = (string) get_post_meta($id, '_fnh_website_url', true);
            $territorio = (string) get_post_meta($id, '_fnh_territory', true);
            echo '<li class="fnh-radio">';
            printf('<h4>%s</h4>', esc_html(get_the_title($post)));
            if ($territorio !== '') {
                echo '<div class="fnh-meta">' . esc_html($territorio) . '</div>';
            }
            if ($stream !== '') {
                printf(
                    '<audio controls preload="none" class="fnh-audio"><source src="%s" type="audio/mpeg" /></audio>',
                    esc_url($stream)
                );
            }
            if ($web !== '') {
                printf(
                    '<a href="%s" target="_blank" rel="noopener" class="fnh-listen">%s</a>',
                    esc_url($web),
                    esc_html__('Web', 'flavor-news-hub')
                );
            }
            echo '</li>';
        }
        echo '</ul>';
        return (string) ob_get_clean();
    }

    /**
     * [flavor_news_videos limit="12" topic="ecologia"]
     * Muestra items de sources cuyo feed_type sea youtube o video.
     */
    public static function renderVideos($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'limit' => 12,
            'topic' => '',
        ], $atribs);

        $idsSourcesVideo = self::resolverIdsSources('', '', 'youtube,video', '');
        if (empty($idsSourcesVideo)) {
            return '<p class="fnh-empty">' . esc_html__('Sin canales de vídeo configurados.', 'flavor-news-hub') . '</p>';
        }
        $query = [
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => (int) $a['limit'],
            'orderby'        => 'meta_value',
            'meta_key'       => '_fnh_published_at',
            'order'          => 'DESC',
            'meta_query'     => [
                [
                    'key'     => '_fnh_source_id',
                    'value'   => array_map('strval', $idsSourcesVideo),
                    'compare' => 'IN',
                ],
            ],
        ];
        if ($a['topic'] !== '') {
            $query['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', explode(',', (string) $a['topic'])),
            ]];
        }
        $consulta = new \WP_Query($query);
        if (empty($consulta->posts)) {
            return '<p class="fnh-empty">' . esc_html__('Sin vídeos que mostrar.', 'flavor-news-hub') . '</p>';
        }
        ob_start();
        echo '<div class="fnh-videos-grid">';
        foreach ($consulta->posts as $post) {
            $datos = ItemTransformer::transformar($post);
            $url = $datos['original_url'] ?: $datos['url'];
            printf('<a class="fnh-video" href="%s" target="_blank" rel="noopener">', esc_url($url));
            if (!empty($datos['media_url'])) {
                printf('<img src="%s" alt="" loading="lazy" />', esc_url($datos['media_url']));
            }
            printf('<div class="fnh-video-title">%s</div>', esc_html($datos['title']));
            echo '</a>';
        }
        echo '</div>';
        return (string) ob_get_clean();
    }

    /**
     * [flavor_news_source id="123"]
     */
    public static function renderSource($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts(['id' => 0], $atribs);
        $idSource = (int) $a['id'];
        if ($idSource <= 0) {
            return '';
        }
        $post = get_post($idSource);
        if (!$post || $post->post_type !== Source::SLUG) {
            return '';
        }
        $web = (string) get_post_meta($idSource, '_fnh_website_url', true);
        $ownership = (string) get_post_meta($idSource, '_fnh_ownership', true);
        ob_start();
        echo '<section class="fnh-source-ficha">';
        printf('<h3>%s</h3>', esc_html(get_the_title($post)));
        echo '<div class="fnh-desc">' . apply_filters('the_content', $post->post_content) . '</div>';
        if ($ownership !== '') {
            echo '<h4>' . esc_html__('Propiedad y financiación', 'flavor-news-hub') . '</h4>';
            echo '<div class="fnh-ownership">' . wp_kses_post($ownership) . '</div>';
        }
        if ($web !== '') {
            printf(
                '<p><a href="%s" target="_blank" rel="noopener">%s</a></p>',
                esc_url($web),
                esc_html__('Visitar web', 'flavor-news-hub')
            );
        }
        echo '</section>';
        return (string) ob_get_clean();
    }

    /**
     * Resuelve IDs de sources con los mismos filtros que usa el endpoint
     * REST — evita duplicar lógica. Devuelve la intersección de todos los
     * criterios que lleguen no vacíos.
     *
     * @return list<int>
     */
    private static function resolverIdsSources(
        string $territorio,
        string $idioma,
        string $tiposSource,
        string $tiposSourceExcluidos
    ): array {
        $metaQuery = [];
        if ($territorio !== '') {
            $metaQuery[] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field($territorio),
                'compare' => 'LIKE',
            ];
        }
        if ($idioma !== '') {
            $codigos = array_filter(array_map('sanitize_key', array_map('trim', explode(',', $idioma))));
            if (count($codigos) === 1) {
                $metaQuery[] = [
                    'key'     => '_fnh_languages',
                    'value'   => reset($codigos),
                    'compare' => 'LIKE',
                ];
            } elseif (count($codigos) > 1) {
                $orQuery = ['relation' => 'OR'];
                foreach ($codigos as $codigo) {
                    $orQuery[] = [
                        'key'     => '_fnh_languages',
                        'value'   => $codigo,
                        'compare' => 'LIKE',
                    ];
                }
                $metaQuery[] = $orQuery;
            }
        }
        if ($tiposSource !== '') {
            $piezas = array_map('sanitize_key', array_filter(array_map('trim', explode(',', $tiposSource))));
            if (!empty($piezas)) {
                $metaQuery[] = [
                    'key'     => '_fnh_feed_type',
                    'value'   => array_values($piezas),
                    'compare' => 'IN',
                ];
            }
        }
        if ($tiposSourceExcluidos !== '') {
            $piezas = array_map('sanitize_key', array_filter(array_map('trim', explode(',', $tiposSourceExcluidos))));
            if (!empty($piezas)) {
                $metaQuery[] = [
                    'relation' => 'OR',
                    [
                        'key'     => '_fnh_feed_type',
                        'value'   => array_values($piezas),
                        'compare' => 'NOT IN',
                    ],
                    [
                        'key'     => '_fnh_feed_type',
                        'compare' => 'NOT EXISTS',
                    ],
                ];
            }
        }
        $consulta = new \WP_Query([
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => $metaQuery,
        ]);
        return array_map('intval', $consulta->posts);
    }

    /**
     * Landing pública del proyecto — pensada como home editorial real,
     * no como página de descarga. Combina:
     *  - Hero compacto con lema.
     *  - Últimas noticias (reutiliza renderFeed).
     *  - Últimos vídeos (reutiliza renderVideos).
     *  - "Sonando ahora": radios libres + últimos episodios de podcast.
     *  - Vídeo destacado aleatorio, sólo de fuentes con licencia CC
     *    (coherencia con la política de embed: no reproducimos
     *    contenido ajeno sin licencia libre). Si es PeerTube usamos
     *    iframe embed; si no, card con miniatura y enlace al original.
     *  - CTA de descarga de la app Android (URL dinámica via cache OTA).
     *
     * La URL de descarga sale del transient que alimenta
     * `AppUpdateEndpoint`. Si no está poblado todavía, caemos al
     * `releases/latest` de GitHub.
     */
    public static function renderLanding($atribs = [], $contenido = null): string
    {
        $cache       = get_transient('fnh_app_update_cache');
        $urlDescarga = is_array($cache) && !empty($cache['download_url'])
            ? (string) $cache['download_url']
            : 'https://github.com/JosuIru/flavor-news-hub/releases/latest';
        $version = is_array($cache) && !empty($cache['version'])
            ? (string) $cache['version']
            : '';

        $videoDestacado = self::obtenerItemVideoCCAleatorio();

        ob_start();
        // `not-prose` neutraliza los estilos de Tailwind Typography que
        // aplican algunos temas (Flavor Starter, p.ej.) sobre
        // `.entry-content`, y que machacarían nuestros tamaños/márgenes.
        // Sin whitespace antes del primer tag para que wpautop no meta
        // un `<p>` alrededor que rompa el HTML.
        ?><div id="fnh-landing" class="fnh-landing not-prose">
            <section class="fnh-hero">
                <h1><?php esc_html_e('Flavor News Hub', 'flavor-news-hub'); ?></h1>
                <p class="fnh-lema"><?php esc_html_e('Puerta de entrada común entre informarse (medios alternativos) y actuar (colectivos organizados).', 'flavor-news-hub'); ?></p>
            </section>

            <section class="fnh-bloque">
                <h2><?php esc_html_e('Últimas noticias', 'flavor-news-hub'); ?></h2>
                <?php echo self::renderFeed(['limit' => 6, 'show_excerpt' => 1, 'show_media' => 1]); ?>
                <?php echo self::enlaceVerMas('noticias'); ?>
            </section>

            <section class="fnh-bloque">
                <h2><?php esc_html_e('Últimos vídeos', 'flavor-news-hub'); ?></h2>
                <?php echo self::renderVideos(['limit' => 4]); ?>
                <?php echo self::enlaceVerMas('videos'); ?>
            </section>

            <section class="fnh-bloque">
                <h2><?php esc_html_e('Sonando ahora', 'flavor-news-hub'); ?></h2>
                <div class="fnh-sonando-cols">
                    <div class="fnh-sonando-col">
                        <h3><?php esc_html_e('Radios libres', 'flavor-news-hub'); ?></h3>
                        <?php echo self::renderRadios(['limit' => 4]); ?>
                    </div>
                    <div class="fnh-sonando-col">
                        <h3><?php esc_html_e('Podcasts recientes', 'flavor-news-hub'); ?></h3>
                        <?php echo self::renderFeed([
                            'limit'               => 5,
                            'show_excerpt'        => 0,
                            'show_media'          => 0,
                            'source_type'         => 'podcast',
                            'exclude_source_type' => '',
                        ]); ?>
                    </div>
                </div>
                <?php echo self::enlaceVerMas('radios'); ?>
            </section>

            <?php if ($videoDestacado !== null) :
                $embed = self::peertubeEmbedUrl($videoDestacado['url']);
            ?>
            <section class="fnh-bloque fnh-destacado">
                <h2><?php esc_html_e('Vídeo destacado', 'flavor-news-hub'); ?></h2>
                <?php if ($embed !== null) : ?>
                    <div class="fnh-embed-ratio">
                        <iframe src="<?php echo esc_url($embed); ?>"
                                title="<?php echo esc_attr($videoDestacado['title']); ?>"
                                frameborder="0"
                                allow="autoplay; fullscreen; picture-in-picture"
                                allowfullscreen></iframe>
                    </div>
                <?php elseif ($videoDestacado['media_url'] !== '') : ?>
                    <a class="fnh-destacado-card" href="<?php echo esc_url($videoDestacado['url']); ?>" target="_blank" rel="noopener">
                        <img src="<?php echo esc_url($videoDestacado['media_url']); ?>" alt="" loading="lazy" />
                    </a>
                <?php endif; ?>
                <p class="fnh-destacado-meta">
                    <strong><?php echo esc_html($videoDestacado['title']); ?></strong>
                    <?php if ($videoDestacado['source_name'] !== '') : ?>
                        · <?php echo esc_html($videoDestacado['source_name']); ?>
                    <?php endif; ?>
                </p>
            </section>
            <?php endif; ?>

            <section class="fnh-descarga">
                <h2><?php esc_html_e('Descarga la app Android', 'flavor-news-hub'); ?></h2>
                <?php if ($version !== '') : ?>
                    <div class="fnh-version"><?php
                        echo esc_html(sprintf(
                            /* translators: %s: número de versión publicado */
                            __('Versión %s', 'flavor-news-hub'),
                            $version
                        ));
                    ?></div>
                <?php endif; ?>
                <a class="fnh-boton-descarga"
                   href="<?php echo esc_url($urlDescarga); ?>"
                   <?php echo str_ends_with($urlDescarga, '.apk') ? 'download' : 'target="_blank" rel="noopener"'; ?>>
                    <?php esc_html_e('Descargar APK', 'flavor-news-hub'); ?>
                </a>
            </section>

            <section class="fnh-repo">
                <p>
                    <a href="https://github.com/JosuIru/flavor-news-hub" target="_blank" rel="noopener">
                        <?php esc_html_e('Código fuente en GitHub', 'flavor-news-hub'); ?>
                    </a>
                    &nbsp;·&nbsp; <?php esc_html_e('Licencia AGPL 3.0', 'flavor-news-hub'); ?>
                </p>
            </section>
        </div><?php
        return (string) ob_get_clean();
    }

    /**
     * Enlace "Ver más" a la página auto-generada indicada, si existe.
     */
    private static function enlaceVerMas(string $clave): string
    {
        $consulta = new \WP_Query([
            'post_type'      => 'page',
            'post_status'    => 'publish',
            'posts_per_page' => 1,
            'no_found_rows'  => true,
            'meta_key'       => '_fnh_pagina_auto',
            'meta_value'     => $clave,
        ]);
        if (empty($consulta->posts)) return '';
        $url = (string) get_permalink($consulta->posts[0]->ID);
        return '<p class="fnh-ver-mas"><a href="' . esc_url($url) . '">' . esc_html__('Ver todo', 'flavor-news-hub') . ' →</a></p>';
    }

    /**
     * Busca un item aleatorio proveniente de fuentes con licencia CC
     * (incluye `mixed` porque las instancias PeerTube declaran así a
     * pesar de que la mayoría de vídeos sí son CC). Filtra por sources
     * activas y medium_type=video.
     *
     * @return array{title:string,url:string,media_url:string,source_name:string}|null
     */
    private static function obtenerItemVideoCCAleatorio(): ?array
    {
        $sources = get_posts([
            'post_type'      => 'fnh_source',
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'meta_query'     => [
                'relation' => 'AND',
                ['key' => '_fnh_medium_type', 'value' => 'video'],
                [
                    'relation' => 'OR',
                    ['key' => '_fnh_content_license', 'value' => 'cc-', 'compare' => 'LIKE'],
                    ['key' => '_fnh_content_license', 'value' => 'public-domain'],
                    ['key' => '_fnh_content_license', 'value' => 'mixed'],
                ],
            ],
        ]);
        if (empty($sources)) return null;

        $item = get_posts([
            'post_type'      => 'fnh_item',
            'post_status'    => 'publish',
            'posts_per_page' => 1,
            'orderby'        => 'rand',
            'no_found_rows'  => true,
            'meta_query'     => [
                [
                    'key'     => '_fnh_source_id',
                    'value'   => array_map('strval', $sources),
                    'compare' => 'IN',
                ],
            ],
        ]);
        if (empty($item)) return null;
        $post = $item[0];
        $idPost = (int) $post->ID;
        $idSource = (int) get_post_meta($idPost, '_fnh_source_id', true);
        return [
            'title'       => (string) get_the_title($post),
            'url'         => (string) get_post_meta($idPost, '_fnh_original_url', true),
            'media_url'   => (string) get_post_meta($idPost, '_fnh_media_url', true),
            'source_name' => $idSource > 0 ? (string) get_the_title($idSource) : '',
        ];
    }

    /**
     * Convierte una URL pública de PeerTube (`/w/<id>` o
     * `/videos/watch/<uuid>`) a la variante `/videos/embed/<id>` que
     * PeerTube sirve sin auth y embeddable por iframe. Devuelve null
     * si no reconoce el patrón — el llamante degrada a enlace externo.
     */
    private static function peertubeEmbedUrl(string $url): ?string
    {
        if ($url === '') return null;
        if (preg_match('#^(https?://[^/]+)/(?:w|videos/watch)/([A-Za-z0-9_-]+)#', $url, $m)) {
            return $m[1] . '/videos/embed/' . $m[2];
        }
        return null;
    }
}
