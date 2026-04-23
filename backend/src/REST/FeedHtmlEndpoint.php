<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Shortcodes\Shortcodes;
use FlavorNewsHub\Support\InterleaveSources;

/**
 * Endpoint que devuelve HTML pre-renderizado de la siguiente página de
 * items, para alimentar el scroll infinito de los shortcodes
 * `flavor_news_feed` y `flavor_news_videos`.
 *
 * No usa transformers JSON: reutiliza directamente los helpers públicos
 * `Shortcodes::renderFeedItemHtml` / `Shortcodes::renderVideoCardHtml`
 * para garantizar que los items añadidos vía AJAX sean idénticos a los
 * renderizados en la primera página.
 *
 * GET /wp-json/flavor-news/v1/feed-html
 *  ?context=noticias|feed|podcasts|videos
 *  &page=2
 *  &per_page=10
 *  &topic= &territory= &language=
 *  &source_type= &exclude_source_type=
 *  &show_excerpt=1 &show_media=1
 *
 * Respuesta: { html: string, has_more: bool, next_page: int|null }
 */
final class FeedHtmlEndpoint
{
    private const CONTEXTOS_VALIDOS = ['noticias', 'feed', 'podcasts', 'videos'];

    public static function registrarRutas(): void
    {
        register_rest_route(RestController::NAMESPACE_REST, '/feed-html', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [self::class, 'cargar'],
                'permission_callback' => '__return_true',
                'args'                => self::esquemaArgs(),
            ],
        ]);
    }

    /** @return array<string,array<string,mixed>> */
    private static function esquemaArgs(): array
    {
        return [
            'context'             => ['type' => 'string', 'required' => true],
            'page'                => ['type' => 'integer', 'default' => 2, 'minimum' => 2, 'maximum' => 50],
            'per_page'            => ['type' => 'integer', 'default' => 10, 'minimum' => 1, 'maximum' => 30],
            'topic'               => ['type' => 'string', 'default' => ''],
            'territory'           => ['type' => 'string', 'default' => ''],
            'language'            => ['type' => 'string', 'default' => ''],
            'source_type'         => ['type' => 'string', 'default' => ''],
            'exclude_source_type' => ['type' => 'string', 'default' => ''],
            'show_excerpt'        => ['type' => 'integer', 'default' => 1],
            'show_media'          => ['type' => 'integer', 'default' => 1],
        ];
    }

    public static function cargar(\WP_REST_Request $request): \WP_REST_Response
    {
        $contexto = (string) $request->get_param('context');
        if (!in_array($contexto, self::CONTEXTOS_VALIDOS, true)) {
            return new \WP_REST_Response(['html' => '', 'has_more' => false, 'next_page' => null], 200);
        }
        $pagina = max(2, (int) $request->get_param('page'));
        $porPagina = min(30, max(1, (int) $request->get_param('per_page')));

        $esVideos = $contexto === 'videos';
        $esNoticias = $contexto === 'noticias';
        $mostrarMedia = (int) $request->get_param('show_media') === 1;
        $mostrarExcerpt = (int) $request->get_param('show_excerpt') === 1;

        $query = [
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'paged'          => $pagina,
            'posts_per_page' => $porPagina,
            'orderby'        => 'meta_value',
            'meta_key'       => '_fnh_published_at',
            'order'          => 'DESC',
        ];

        $topic = (string) $request->get_param('topic');
        if ($topic !== '') {
            $query['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', explode(',', $topic)),
            ]];
        }

        $territorio = (string) $request->get_param('territory');
        $idioma = (string) $request->get_param('language');
        $sourceType = (string) $request->get_param('source_type');
        $excludeSourceType = (string) $request->get_param('exclude_source_type');

        // Para videos forzamos los feed_types de vídeo — coincide con la
        // lógica de Shortcodes::renderVideos para mantener la simetría
        // entre página 1 y siguientes.
        if ($esVideos && $sourceType === '') {
            $sourceType = 'youtube,video,peertube';
        }

        if ($territorio !== '' || $idioma !== '' || $sourceType !== '' || $excludeSourceType !== '') {
            $idsSources = Shortcodes::resolverIdsSources($territorio, $idioma, $sourceType, $excludeSourceType);
            if (empty($idsSources)) {
                return new \WP_REST_Response(['html' => '', 'has_more' => false, 'next_page' => null], 200);
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
            return new \WP_REST_Response(['html' => '', 'has_more' => false, 'next_page' => null], 200);
        }

        $posts = InterleaveSources::aplicar($consulta->posts);

        $html = '';
        if ($esVideos) {
            foreach ($posts as $post) {
                $html .= Shortcodes::renderVideoCardHtml($post);
            }
        } else {
            foreach ($posts as $post) {
                $html .= Shortcodes::renderFeedItemHtml(
                    $post,
                    $esNoticias,
                    false,
                    $mostrarMedia,
                    $mostrarExcerpt
                );
            }
        }

        $hayMas = $pagina < (int) $consulta->max_num_pages;

        return new \WP_REST_Response([
            'html'      => $html,
            'has_more'  => $hayMas,
            'next_page' => $hayMas ? $pagina + 1 : null,
        ], 200);
    }
}
