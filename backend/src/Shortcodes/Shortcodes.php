<?php
declare(strict_types=1);

namespace FlavorNewsHub\Shortcodes;

use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Item;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\REST\Transformers\ItemTransformer;
use FlavorNewsHub\Support\InterleaveSources;

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
        add_shortcode('flavor_news_tv', [self::class, 'renderTv']);
        add_shortcode('flavor_news_podcasts', [self::class, 'renderPodcasts']);
        add_shortcode('flavor_news_sources', [self::class, 'renderSources']);
        add_shortcode('flavor_news_collectives', [self::class, 'renderCollectives']);
        add_shortcode('flavor_news_sobre', [self::class, 'renderSobre']);
        add_action('wp_enqueue_scripts', [self::class, 'cargarEstilos']);
        // Marca las páginas auto con clases específicas en el <body>
        // para poder aplicar reglas CSS por página (p.ej. ocultar
        // el entry-header del tema en la landing, donde sobra).
        add_filter('body_class', [self::class, 'bodyClassPaginaAuto']);
        // Botón flotante de donaciones + modal, inyectado en wp_footer
        // sólo en páginas auto del plugin.
        add_action('wp_footer', [self::class, 'renderPopupDonaciones']);
        // Prio 9 (antes de wpautop en prio 10): anteponemos un menú
        // de navegación entre las 5 páginas auto-generadas del plugin.
        // Antes de wpautop evita que WP envuelva el nav en un <p>.
        add_filter('the_content', [self::class, 'prependMenuPaginasAuto'], 9);
        // Prio 12: después de do_shortcode (11). Cuando la landing vive
        // en una página con bloques alrededor (VBP u otros), WordPress
        // envuelve el shortcode en `<p>...</p>` y shortcode_unautop no
        // lo limpia porque no está solo. Desenvolvemos a posteriori.
        add_filter('the_content', [self::class, 'desenvolverLanding'], 12);
    }

    /**
     * Prepend un menú de navegación a las páginas auto-generadas por
     * CreadorPaginas (marcadas con el meta `_fnh_pagina_auto`). Así
     * Inicio / Noticias / Vídeos / Radios / Colectivos comparten una
     * navegación coherente sin depender del menú del tema.
     */
    /** @var bool Evita reinyectar el menú si algún shortcode (p.ej.
     *  renderSource) vuelve a llamar apply_filters('the_content'),
     *  lo que de otro modo duplica el menú por cada item del feed. */
    private static bool $menuInyectado = false;

    public static function prependMenuPaginasAuto(string $contenido): string
    {
        if (self::$menuInyectado) return $contenido;
        if (!is_singular('page')) return $contenido;
        $idPost = (int) get_the_ID();
        if ($idPost <= 0) return $contenido;
        $clave = (string) get_post_meta($idPost, '_fnh_pagina_auto', true);
        if ($clave === '') return $contenido;
        self::$menuInyectado = true;
        return self::renderMenuPaginasAuto($clave) . $contenido;
    }

    private static function renderMenuPaginasAuto(string $claveActual): string
    {
        $paginas = [
            ['clave' => 'inicio',     'titulo' => __('Inicio', 'flavor-news-hub')],
            ['clave' => 'noticias',   'titulo' => __('Noticias', 'flavor-news-hub')],
            ['clave' => 'tv',         'titulo' => __('TV', 'flavor-news-hub')],
            ['clave' => 'videos',     'titulo' => __('Vídeos', 'flavor-news-hub')],
            ['clave' => 'radios',     'titulo' => __('Radios', 'flavor-news-hub')],
            ['clave' => 'podcasts',   'titulo' => __('Podcasts', 'flavor-news-hub')],
            ['clave' => 'colectivos', 'titulo' => __('Colectivos', 'flavor-news-hub')],
            ['clave' => 'fuentes',    'titulo' => __('Fuentes', 'flavor-news-hub')],
            ['clave' => 'sobre',      'titulo' => __('Sobre', 'flavor-news-hub')],
        ];
        ob_start();
        ?><nav class="fnh-nav-auto" aria-label="<?php esc_attr_e('Secciones del hub', 'flavor-news-hub'); ?>"><ul class="fnh-nav-auto-lista"><?php
        foreach ($paginas as $p) {
            $url = self::urlPaginaAuto($p['clave']);
            if ($url === '') continue;
            $activa = $p['clave'] === $claveActual;
            $clase = 'fnh-nav-auto-item' . ($activa ? ' fnh-nav-auto-item--activo' : '');
            printf(
                '<li class="%s"><a href="%s"%s>%s</a></li>',
                esc_attr($clase),
                esc_url($url),
                $activa ? ' aria-current="page"' : '',
                esc_html($p['titulo'])
            );
        }
        // Entrada especial al final: botón de apoyo al proyecto que
        // abre el modal unificado de donaciones (mismo contenido que
        // el sheet de la app móvil: Ko-fi, PayPal, Bitcoin, compartir).
        printf(
            '<li class="fnh-nav-auto-item fnh-nav-auto-item--cta"><a href="#" role="button" data-fnh-open-dona>♥ %s</a></li>',
            esc_html__('Apoyar', 'flavor-news-hub')
        );
        ?></ul></nav><?php
        return (string) ob_get_clean();
    }

    /**
     * URL de donación del proyecto. Editable desde Ajustes →
     * Flavor News Hub. Fallback al PayPal del proyecto si quedó vacío.
     */
    private static function urlDonaciones(): string
    {
        $url = (string) (\FlavorNewsHub\Options\OptionsRepository::todas()['donation_url'] ?? '');
        return $url !== '' ? $url : \FlavorNewsHub\Options\OptionsRepository::DONATION_URL_DEFAULT;
    }

    /** URLs y direcciones del proyecto compartidas con la app Flutter.
     *  Mantener sincronizado con `app/lib/features/donations/presentation/donaciones_sheet.dart`.
     *  El PayPal es editable desde Ajustes; el resto son constantes. */
    private const KOFI_URL = 'https://ko-fi.com/codigodespierto';
    private const BTC_SEGWIT  = 'bc1qjnva46wy92ldhsv4w0j26jmu8c5wm5cxvgdfd7';
    private const BTC_TAPROOT = 'bc1p29l9vjelerljlwhg6dhr0uldldus4zgn8vjaecer0spj7273d7rss4gnyk';
    private const REPO_URL    = 'https://github.com/JosuIru/flavor-news-hub';
    private const ECOSISTEMA_URL = 'https://coleccion-nuevo-ser.gailu.net/';

    /**
     * FAB + modal de donaciones unificado para toda la web. Cubre las
     * mismas opciones que el bottom sheet de la app móvil: Ko-fi,
     * PayPal, dos direcciones Bitcoin con copiar al portapapeles,
     * compartir, otras formas de ayudar (estrella GitHub, bugs,
     * traducción, código) y ecosistema Colección Nuevo Ser.
     *
     * Antes de este cambio cada punto de donación de la web (FAB,
     * menú, hero landing, sección apoyo de la landing) apuntaba
     * directamente a PayPal con interfaces distintas. Ahora todos
     * esos puntos abren este mismo modal — mensaje unificado
     * app+web.
     */
    public static function renderPopupDonaciones(): void
    {
        if (!is_singular('page')) return;
        $idPost = (int) get_the_ID();
        if ($idPost <= 0) return;
        $clave = (string) get_post_meta($idPost, '_fnh_pagina_auto', true);
        if ($clave === '') return;

        $urlPaypal = self::urlDonaciones();
        ?>
<div class="fnh-dona-fab" id="fnh-dona-fab" role="button" tabindex="0" data-fnh-open-dona aria-label="<?php esc_attr_e('Apoyar el proyecto', 'flavor-news-hub'); ?>" title="<?php esc_attr_e('Apoyar', 'flavor-news-hub'); ?>"><span aria-hidden="true">♥</span></div>
<div class="fnh-dona-modal" id="fnh-dona-modal" role="dialog" aria-hidden="true" aria-labelledby="fnh-dona-modal-titulo">
    <div class="fnh-dona-backdrop" data-fnh-close-dona></div>
    <div class="fnh-dona-dialog" role="document">
        <button class="fnh-dona-cerrar" type="button" aria-label="<?php esc_attr_e('Cerrar', 'flavor-news-hub'); ?>" data-fnh-close-dona>×</button>
        <h2 id="fnh-dona-modal-titulo">♥ <?php esc_html_e('Apoya el proyecto', 'flavor-news-hub'); ?></h2>
        <p class="fnh-dona-intro"><?php esc_html_e('Flavor News Hub es libre y sin publicidad. Si te resulta útil, así puedes sostenerlo.', 'flavor-news-hub'); ?></p>

        <a class="fnh-dona-tarjeta fnh-dona-tarjeta--kofi" href="<?php echo esc_url(self::KOFI_URL); ?>" target="_blank" rel="noopener">
            <span class="fnh-dona-tarjeta-icono" aria-hidden="true">☕</span>
            <span class="fnh-dona-tarjeta-txt">
                <strong>Ko-fi</strong>
                <span><?php esc_html_e('Invita a un café puntual', 'flavor-news-hub'); ?></span>
            </span>
            <span class="fnh-dona-tarjeta-chevron" aria-hidden="true">›</span>
        </a>

        <a class="fnh-dona-tarjeta fnh-dona-tarjeta--paypal" href="<?php echo esc_url($urlPaypal); ?>" target="_blank" rel="noopener">
            <span class="fnh-dona-tarjeta-icono" aria-hidden="true">💳</span>
            <span class="fnh-dona-tarjeta-txt">
                <strong>PayPal</strong>
                <span><?php esc_html_e('Donación directa', 'flavor-news-hub'); ?></span>
            </span>
            <span class="fnh-dona-tarjeta-chevron" aria-hidden="true">›</span>
        </a>

        <div class="fnh-dona-btc">
            <div class="fnh-dona-btc-titulo">
                <span aria-hidden="true">₿</span> Bitcoin <small>(Native SegWit)</small>
            </div>
            <code class="fnh-dona-btc-direccion"><?php echo esc_html(self::BTC_SEGWIT); ?></code>
            <button type="button" class="fnh-dona-btc-copiar" data-fnh-copy-dona="<?php echo esc_attr(self::BTC_SEGWIT); ?>">
                <?php esc_html_e('Copiar dirección', 'flavor-news-hub'); ?>
            </button>
        </div>

        <div class="fnh-dona-btc">
            <div class="fnh-dona-btc-titulo">
                <span aria-hidden="true">₿</span> Bitcoin <small>(Taproot)</small>
            </div>
            <code class="fnh-dona-btc-direccion"><?php echo esc_html(self::BTC_TAPROOT); ?></code>
            <button type="button" class="fnh-dona-btc-copiar" data-fnh-copy-dona="<?php echo esc_attr(self::BTC_TAPROOT); ?>">
                <?php esc_html_e('Copiar dirección', 'flavor-news-hub'); ?>
            </button>
        </div>

        <div class="fnh-dona-compartir">
            <h3><?php esc_html_e('Comparte el proyecto', 'flavor-news-hub'); ?></h3>
            <p><?php esc_html_e('Recomendárselo a alguien también es ayudar — crecemos por humanos, no por algoritmo.', 'flavor-news-hub'); ?></p>
            <div class="fnh-dona-compartir-acciones">
                <a href="<?php echo esc_url('https://t.me/share/url?url=' . rawurlencode(self::REPO_URL) . '&text=' . rawurlencode(__('Flavor News Hub: app de noticias federada, sin algoritmo ni publicidad.', 'flavor-news-hub'))); ?>" target="_blank" rel="noopener">Telegram</a>
                <a href="<?php echo esc_url('https://wa.me/?text=' . rawurlencode(__('Flavor News Hub: app de noticias federada, sin algoritmo ni publicidad.', 'flavor-news-hub') . ' ' . self::REPO_URL)); ?>" target="_blank" rel="noopener">WhatsApp</a>
                <a href="<?php echo esc_url('https://mastodonshare.com/?text=' . rawurlencode(__('Flavor News Hub: app de noticias federada, sin algoritmo ni publicidad.', 'flavor-news-hub')) . '&url=' . rawurlencode(self::REPO_URL)); ?>" target="_blank" rel="noopener">Mastodon</a>
            </div>
        </div>

        <div class="fnh-dona-otras">
            <h3><?php esc_html_e('Otras formas de ayudar', 'flavor-news-hub'); ?></h3>
            <ul>
                <li><span aria-hidden="true">⭐</span> <a href="<?php echo esc_url(self::REPO_URL); ?>" target="_blank" rel="noopener"><?php esc_html_e('Dale una estrella en GitHub', 'flavor-news-hub'); ?></a></li>
                <li><span aria-hidden="true">🐛</span> <a href="<?php echo esc_url(self::REPO_URL . '/issues'); ?>" target="_blank" rel="noopener"><?php esc_html_e('Reporta bugs o sugiere mejoras', 'flavor-news-hub'); ?></a></li>
                <li><span aria-hidden="true">🌐</span> <?php esc_html_e('Ayuda con las traducciones', 'flavor-news-hub'); ?></li>
                <li><span aria-hidden="true">💻</span> <?php esc_html_e('Contribuye con código o documentación', 'flavor-news-hub'); ?></li>
            </ul>
        </div>

        <a class="fnh-dona-ecosistema" href="<?php echo esc_url(self::ECOSISTEMA_URL); ?>" target="_blank" rel="noopener">
            <span class="fnh-dona-eco-icono" aria-hidden="true">✨</span>
            <span class="fnh-dona-eco-txt">
                <strong><?php esc_html_e('Parte de Colección del Nuevo Ser', 'flavor-news-hub'); ?></strong>
                <span>coleccion-nuevo-ser.gailu.net</span>
            </span>
        </a>
    </div>
</div>
<script>
(function(){
    var modal=document.getElementById('fnh-dona-modal');
    if(!modal)return;
    function abrir(){modal.classList.add('fnh-dona-modal--abierto');modal.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';}
    function cerrar(){modal.classList.remove('fnh-dona-modal--abierto');modal.setAttribute('aria-hidden','true');document.body.style.overflow='';}
    // Cualquier elemento con data-fnh-open-dona (FAB, botones del menú,
    // botones de landing…) abre el mismo modal. Delegación global para
    // cubrir elementos inyectados dinámicamente.
    document.addEventListener('click',function(e){
        var t=e.target.closest('[data-fnh-open-dona]');
        if(t){e.preventDefault();abrir();return;}
        if(e.target.hasAttribute('data-fnh-close-dona')){cerrar();return;}
        var copiar=e.target.closest('[data-fnh-copy-dona]');
        if(copiar){
            e.preventDefault();
            var addr=copiar.getAttribute('data-fnh-copy-dona');
            if(navigator.clipboard&&addr){
                navigator.clipboard.writeText(addr).then(function(){
                    var txt=copiar.textContent;
                    copiar.textContent=<?php echo wp_json_encode(__('Copiada', 'flavor-news-hub')); ?>;
                    setTimeout(function(){copiar.textContent=txt;},1400);
                });
            }
        }
    });
    document.addEventListener('keydown',function(e){
        var fab=e.target.closest&&e.target.closest('[data-fnh-open-dona]');
        if(fab&&(e.key==='Enter'||e.key===' ')){e.preventDefault();abrir();return;}
        if(e.key==='Escape'&&modal.classList.contains('fnh-dona-modal--abierto')){cerrar();}
    });
})();
</script>
        <?php
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
     * Añade clases al <body> identificando nuestras páginas auto:
     * `fnh-pagina-auto` (cualquier página auto) y
     * `fnh-pagina-<clave>` (específica). Así el CSS puede aplicar
     * reglas por página sin depender del page-id numérico.
     *
     * @param list<string> $classes
     * @return list<string>
     */
    public static function bodyClassPaginaAuto(array $classes): array
    {
        if (!is_singular('page')) return $classes;
        $idPost = (int) get_the_ID();
        if ($idPost <= 0) return $classes;
        $clave = (string) get_post_meta($idPost, '_fnh_pagina_auto', true);
        if ($clave === '') return $classes;
        $classes[] = 'fnh-pagina-auto';
        $classes[] = 'fnh-pagina-' . sanitize_html_class($clave);
        return $classes;
    }

    private static function paginaAutoActual(): string
    {
        if (!is_singular('page')) {
            return '';
        }

        $idPost = (int) get_the_ID();
        if ($idPost <= 0) {
            return '';
        }

        return (string) get_post_meta($idPost, '_fnh_pagina_auto', true);
    }

    private static function clasePaginaAutoActual(): string
    {
        $clave = self::paginaAutoActual();
        return $clave !== '' ? 'fnh-page-auto fnh-page-auto--' . sanitize_html_class($clave) : '';
    }

    /**
     * @param array<string, mixed> $atributos
     * @param list<string> $permitidos
     * @param list<string> $paginas
     * @return array<string, mixed>
     */
    private static function aplicarFiltrosRequest(array $atributos, array $permitidos, array $paginas): array
    {
        $clavePagina = self::paginaAutoActual();
        if ($clavePagina === '' || !in_array($clavePagina, $paginas, true)) {
            return $atributos;
        }

        foreach ($permitidos as $clave) {
            $param = 'fnh_' . $clave;
            if (!isset($_GET[$param])) {
                continue;
            }
            $atributos[$clave] = self::sanitizarValorFiltro(
                $clave,
                (string) wp_unslash($_GET[$param])
            );
        }

        return $atributos;
    }

    private static function sanitizarValorFiltro(string $clave, string $valor): string
    {
        $valor = trim($valor);
        if ($valor === '') {
            return '';
        }

        return match ($clave) {
            'language', 'source_type' => implode(',', array_filter(array_map(
                'sanitize_key',
                array_map('trim', explode(',', $valor))
            ))),
            'topic' => implode(',', array_filter(array_map(
                'sanitize_title',
                array_map('trim', explode(',', $valor))
            ))),
            default => sanitize_text_field($valor),
        };
    }

    /**
     * @param list<string> $campos
     */
    private static function renderFiltrosPaginaAuto(string $contexto, array $campos): string
    {
        $clavePagina = self::paginaAutoActual();
        if ($clavePagina === '') {
            return '';
        }

        $valores = [];
        foreach ($campos as $campo) {
            $valores[$campo] = self::sanitizarValorFiltro(
                $campo,
                isset($_GET['fnh_' . $campo]) ? (string) wp_unslash($_GET['fnh_' . $campo]) : ''
            );
        }

        $hayFiltros = array_filter($valores, static fn(string $valor): bool => $valor !== '') !== [];
        $action = self::urlActual();
        if ($action === '') {
            return '';
        }

        ob_start();
        ?>
        <form class="fnh-filtros" method="get" action="<?php echo esc_url($action); ?>" data-fnh-contexto="<?php echo esc_attr($contexto); ?>">
            <div class="fnh-filtros-grid">
                <?php if (in_array('topic', $campos, true)) : ?>
                    <label class="fnh-filtro-campo">
                        <span><?php esc_html_e('Temática', 'flavor-news-hub'); ?></span>
                        <select name="fnh_topic">
                            <option value=""><?php esc_html_e('Todas', 'flavor-news-hub'); ?></option>
                            <?php foreach (self::obtenerOpcionesTopics() as $slug => $nombre) : ?>
                                <option value="<?php echo esc_attr($slug); ?>"<?php selected($valores['topic'], $slug); ?>>
                                    <?php echo esc_html($nombre); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                <?php endif; ?>

                <?php if (in_array('territory', $campos, true)) : ?>
                    <label class="fnh-filtro-campo">
                        <span><?php esc_html_e('Territorio', 'flavor-news-hub'); ?></span>
                        <select name="fnh_territory">
                            <option value=""><?php esc_html_e('Todos', 'flavor-news-hub'); ?></option>
                            <?php foreach (self::obtenerOpcionesTerritorios($contexto) as $valor => $label) : ?>
                                <option value="<?php echo esc_attr($valor); ?>"<?php selected($valores['territory'], $valor); ?>>
                                    <?php echo esc_html($label); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                <?php endif; ?>

                <?php if (in_array('language', $campos, true)) : ?>
                    <label class="fnh-filtro-campo">
                        <span><?php esc_html_e('Idioma', 'flavor-news-hub'); ?></span>
                        <select name="fnh_language">
                            <option value=""><?php esc_html_e('Todos', 'flavor-news-hub'); ?></option>
                            <?php foreach (self::obtenerOpcionesIdiomas($contexto) as $valor => $label) : ?>
                                <option value="<?php echo esc_attr($valor); ?>"<?php selected($valores['language'], $valor); ?>>
                                    <?php echo esc_html($label); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                <?php endif; ?>

                <?php if (in_array('source_type', $campos, true)) : ?>
                    <label class="fnh-filtro-campo">
                        <span><?php esc_html_e('Tipo', 'flavor-news-hub'); ?></span>
                        <select name="fnh_source_type">
                            <option value=""><?php esc_html_e('Todos', 'flavor-news-hub'); ?></option>
                            <?php foreach (self::obtenerOpcionesTiposFuente() as $valor => $label) : ?>
                                <option value="<?php echo esc_attr($valor); ?>"<?php selected($valores['source_type'], $valor); ?>>
                                    <?php echo esc_html($label); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                <?php endif; ?>
            </div>

            <div class="fnh-filtros-acciones">
                <button type="submit" class="fnh-filtros-boton"><?php esc_html_e('Aplicar filtros', 'flavor-news-hub'); ?></button>
                <?php if ($hayFiltros) : ?>
                    <a class="fnh-filtros-reset" href="<?php echo esc_url($action); ?>"><?php esc_html_e('Limpiar', 'flavor-news-hub'); ?></a>
                <?php endif; ?>
            </div>
        </form>
        <?php
        return (string) ob_get_clean();
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesTopics(): array
    {
        $terms = get_terms([
            'taxonomy'   => Topic::SLUG,
            'hide_empty' => true,
        ]);
        if (is_wp_error($terms) || empty($terms)) {
            return [];
        }

        $opciones = [];
        foreach ($terms as $term) {
            if (!$term instanceof \WP_Term) {
                continue;
            }
            $opciones[$term->slug] = $term->name;
        }

        return $opciones;
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesTerritorios(string $contexto): array
    {
        return self::obtenerOpcionesMetaTexto(
            $contexto === 'radios' ? Radio::SLUG : Source::SLUG,
            '_fnh_territory'
        );
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesIdiomas(string $contexto): array
    {
        return self::obtenerOpcionesMetaLista(
            $contexto === 'radios' ? Radio::SLUG : Source::SLUG,
            '_fnh_languages'
        );
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesTiposFuente(): array
    {
        return [
            'rss' => 'RSS',
            'podcast' => 'Podcast',
            'youtube' => 'YouTube',
            'video' => __('Vídeo', 'flavor-news-hub'),
            'peertube' => 'PeerTube',
        ];
    }

    /**
     * @param list<\WP_Post> $posts
     * @return list<array{slug:string,nombre:string,cantidad:int,url:string}>
     */
    private static function obtenerTemasDestacadosNoticias(array $posts, int $limite = 4): array
    {
        $conteo = [];
        foreach ($posts as $post) {
            if (!$post instanceof \WP_Post) {
                continue;
            }
            $terms = get_the_terms($post, Topic::SLUG);
            if (empty($terms) || is_wp_error($terms)) {
                continue;
            }
            foreach ($terms as $term) {
                if (!$term instanceof \WP_Term) {
                    continue;
                }
                if (!isset($conteo[$term->slug])) {
                    $conteo[$term->slug] = [
                        'slug' => $term->slug,
                        'nombre' => $term->name,
                        'cantidad' => 0,
                    ];
                }
                $conteo[$term->slug]['cantidad']++;
            }
        }

        if ($conteo === []) {
            return [];
        }

        usort($conteo, static function (array $a, array $b): int {
            return $b['cantidad'] <=> $a['cantidad'] ?: strcasecmp($a['nombre'], $b['nombre']);
        });

        $conteo = array_slice($conteo, 0, $limite);
        $urlBase = self::urlActual();
        foreach ($conteo as &$tema) {
            $tema['url'] = (string) add_query_arg(['fnh_topic' => $tema['slug']], $urlBase);
        }
        unset($tema);

        return $conteo;
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesMetaTexto(string $postType, string $metaKey): array
    {
        $posts = get_posts([
            'post_type'      => $postType,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
        ]);

        $opciones = [];
        foreach ($posts as $postId) {
            $valor = trim((string) get_post_meta((int) $postId, $metaKey, true));
            if ($valor === '') {
                continue;
            }
            $opciones[$valor] = $valor;
        }

        natcasesort($opciones);
        return $opciones;
    }

    /**
     * @return array<string, string>
     */
    private static function obtenerOpcionesMetaLista(string $postType, string $metaKey): array
    {
        $posts = get_posts([
            'post_type'      => $postType,
            'post_status'    => 'publish',
            'posts_per_page' => -1,
            'fields'         => 'ids',
            'no_found_rows'  => true,
        ]);

        $opciones = [];
        foreach ($posts as $postId) {
            $valores = get_post_meta((int) $postId, $metaKey, true);
            if (!is_array($valores)) {
                $valores = [];
            }
            foreach ($valores as $valor) {
                $codigo = sanitize_key((string) $valor);
                if ($codigo === '') {
                    continue;
                }
                $opciones[$codigo] = strtoupper($codigo);
            }
        }

        natcasesort($opciones);
        return $opciones;
    }

    private static function envolverShortcode(string $variant, string $contenido, string $filtros = ''): string
    {
        $clasePagina = self::clasePaginaAutoActual();
        $clasePagina = $clasePagina !== '' ? ' ' . $clasePagina : '';
        return sprintf(
            '<div class="fnh-shortcode-wrap fnh-shortcode-wrap--%1$s%4$s">%2$s<div class="fnh-shortcode-body">%3$s</div></div>',
            esc_attr($variant),
            $filtros,
            $contenido,
            esc_attr($clasePagina)
        );
    }

    /**
     * `_fnh_languages` se guarda como array PHP serializado. Buscamos la
     * secuencia exacta `"xx"` para no confundir `en` con otras cadenas.
     *
     * @return array<string,mixed>
     */
    private static function construirMetaQueryIdiomas(string $idioma): array
    {
        $codigos = array_values(array_filter(array_map(
            'sanitize_key',
            array_map('trim', explode(',', $idioma))
        )));

        if ($codigos === []) {
            return [];
        }

        if (count($codigos) === 1) {
            return [
                'key'     => '_fnh_languages',
                'value'   => '"' . $codigos[0] . '"',
                'compare' => 'LIKE',
            ];
        }

        $orQuery = ['relation' => 'OR'];
        foreach ($codigos as $codigo) {
            $orQuery[] = [
                'key'     => '_fnh_languages',
                'value'   => '"' . $codigo . '"',
                'compare' => 'LIKE',
            ];
        }

        return $orQuery;
    }

    /**
     * Sentinel para el scroll infinito: un `<div>` oculto al final de la
     * lista con data-atributos que el JS lee para pedir la siguiente
     * página al endpoint REST. Si sólo hay una página, no se renderiza.
     *
     * @param array<string,mixed> $filtros
     */
    private static function renderSentinelScrollInfinito(
        string $contexto,
        int $perPage,
        int $totalPaginas,
        array $filtros
    ): string {
        if ($totalPaginas <= 1 || $perPage <= 0) {
            return '';
        }
        $atributos = [
            'class'             => 'fnh-infinite-sentinel',
            'data-context'      => $contexto,
            'data-per-page'     => (string) $perPage,
            'data-current-page' => '1',
            'data-total-pages'  => (string) $totalPaginas,
        ];
        foreach ($filtros as $clave => $valor) {
            if ($valor === '' || $valor === 0 || $valor === null) {
                continue;
            }
            $atributos['data-' . $clave] = (string) $valor;
        }
        $html = '<div';
        foreach ($atributos as $clave => $valor) {
            $html .= ' ' . esc_attr($clave) . '="' . esc_attr($valor) . '"';
        }
        $html .= ' aria-hidden="true">';
        $html .= '<span class="fnh-infinite-spinner" role="status">' . esc_html__('Cargando más…', 'flavor-news-hub') . '</span>';
        $html .= '</div>';
        return $html;
    }

    /**
     * Renderiza una card de noticia (`<li class="fnh-feed-item">…</li>`)
     * como string. Extraído del bucle de renderFeed para reutilizarlo
     * desde el endpoint REST de scroll infinito.
     */
    public static function renderFeedItemHtml(
        \WP_Post $post,
        bool $esPaginaNoticias,
        bool $esDestacado,
        bool $mostrarMedia,
        bool $mostrarExcerpt
    ): string {
        $datos = ItemTransformer::transformar($post);
        $fuenteNombre = $datos['source']['name'] ?? '';
        $urlOriginal = $datos['original_url'] ?: $datos['url'];
        $clasesItem = 'fnh-feed-item';
        if ($esPaginaNoticias && $esDestacado) {
            $clasesItem .= ' fnh-feed-item--destacado';
        }
        ob_start();
        printf('<li class="%s">', esc_attr($clasesItem));
        if ($esPaginaNoticias && $mostrarMedia && !empty($datos['media_url'])) {
            printf('<div class="fnh-media"><img src="%s" alt="" loading="lazy" /></div>', esc_url($datos['media_url']));
        }
        printf('<h3><a href="%s" target="_blank" rel="noopener">%s</a></h3>', esc_url($urlOriginal), esc_html((string) $datos['title']));
        echo '<div class="fnh-meta">' . esc_html($fuenteNombre);
        if (!empty($datos['published_at'])) {
            $fecha = date_i18n(get_option('date_format', 'F j, Y'), strtotime((string) $datos['published_at']));
            echo ' · ' . esc_html($fecha);
        }
        echo '</div>';
        if (!$esPaginaNoticias && $mostrarMedia && !empty($datos['media_url'])) {
            printf('<div class="fnh-media"><img src="%s" alt="" loading="lazy" /></div>', esc_url($datos['media_url']));
        }
        if ($mostrarExcerpt && !empty($datos['excerpt'])) {
            echo '<div class="fnh-excerpt">' . wp_kses_post((string) $datos['excerpt']) . '</div>';
        }
        echo self::renderBotonesCompartir((string) $urlOriginal, (string) $datos['title']);
        echo '</li>';
        return (string) ob_get_clean();
    }

    /**
     * Renderiza una card de vídeo (`<article class="fnh-video-card">…</article>`)
     * como string, incluyendo miniatura + meta (fuente · fecha) + título +
     * excerpt + botones de compartir. Reutilizado por el endpoint REST.
     */
    public static function renderVideoCardHtml(\WP_Post $post): string
    {
        $datos = ItemTransformer::transformar($post);
        $url = $datos['original_url'] ?: $datos['url'];
        $fuenteNombre = $datos['source']['name'] ?? '';
        $meta = $fuenteNombre;
        if (!empty($datos['published_at'])) {
            $fecha = date_i18n(get_option('date_format', 'F j, Y'), strtotime((string) $datos['published_at']));
            $meta = trim($meta . ($meta !== '' ? ' · ' : '') . $fecha);
        }

        // Embebido inline sólo para YouTube, Vimeo y PeerTube: son
        // plataformas cuyo iframe oficial está diseñado y permitido por
        // ToS para embebido en terceros, atribuyendo al canal y
        // respetando monetización. Para cualquier otra URL mantenemos
        // el click a pestaña externa. `construirDatosEmbed` devuelve
        // null si la URL no es de ninguna de esas 3.
        $datosEmbed = self::construirDatosEmbed((string) $url);

        ob_start();
        echo '<article class="fnh-video-card">';
        if ($datosEmbed !== null) {
            printf(
                '<a class="fnh-video fnh-video--embebible" href="%s" target="_blank" rel="noopener" data-fnh-embed-url="%s" data-fnh-embed-type="%s" aria-label="%s">',
                esc_url($url),
                esc_attr($datosEmbed['embedUrl']),
                esc_attr($datosEmbed['tipo']),
                esc_attr__('Reproducir', 'flavor-news-hub')
            );
            if (!empty($datos['media_url'])) {
                printf('<img src="%s" alt="" loading="lazy" />', esc_url($datos['media_url']));
            }
            echo '<span class="fnh-video-play" aria-hidden="true">&#9654;</span>';
            echo '</a>';
        } else {
            printf('<a class="fnh-video" href="%s" target="_blank" rel="noopener">', esc_url($url));
            if (!empty($datos['media_url'])) {
                printf('<img src="%s" alt="" loading="lazy" />', esc_url($datos['media_url']));
            }
            echo '</a>';
        }
        echo '<div class="fnh-video-contenido">';
        if ($meta !== '') {
            echo '<div class="fnh-video-meta">' . esc_html($meta) . '</div>';
        }
        printf('<h3 class="fnh-video-titulo"><a href="%s" target="_blank" rel="noopener">%s</a></h3>', esc_url($url), esc_html((string) $datos['title']));
        if (!empty($datos['excerpt'])) {
            echo '<div class="fnh-video-excerpt">' . wp_kses_post((string) $datos['excerpt']) . '</div>';
        }
        echo '</div>';
        echo self::renderBotonesCompartir((string) $url, (string) $datos['title']);
        echo '</article>';
        return (string) ob_get_clean();
    }

    /**
     * Detecta si la URL del vídeo corresponde a YouTube, PeerTube o
     * Vimeo y devuelve la URL canónica del iframe de embed, o null si
     * el tipo no es reconocido.
     *
     * YouTube usa `youtube-nocookie.com` para no sembrar cookies hasta
     * que el usuario pulse play — más respetuoso con la privacidad y
     * compatible con la política del proyecto.
     *
     * @return array{embedUrl:string,tipo:string}|null
     */
    private static function construirDatosEmbed(string $urlVideo): ?array
    {
        $partes = wp_parse_url($urlVideo);
        if (!is_array($partes) || empty($partes['host'])) {
            return null;
        }
        $host = strtolower((string) $partes['host']);
        $path = (string) ($partes['path'] ?? '');
        $query = [];
        if (!empty($partes['query'])) {
            parse_str((string) $partes['query'], $query);
        }

        // YouTube: watch?v=ID  |  youtu.be/ID  |  shorts/ID
        if (str_ends_with($host, 'youtube.com') || str_ends_with($host, 'youtu.be')) {
            $videoId = '';
            if ($host === 'youtu.be' || str_ends_with($host, '.youtu.be')) {
                $videoId = ltrim($path, '/');
            } elseif (isset($query['v'])) {
                $videoId = (string) $query['v'];
            } elseif (preg_match('#/(embed|shorts|v)/([A-Za-z0-9_-]+)#', $path, $m) === 1) {
                $videoId = $m[2];
            }
            $videoId = preg_replace('/[^A-Za-z0-9_-]/', '', $videoId) ?? '';
            if ($videoId === '') {
                return null;
            }
            return [
                'embedUrl' => 'https://www.youtube-nocookie.com/embed/' . $videoId . '?rel=0',
                'tipo'     => 'youtube',
            ];
        }

        // Vimeo: vimeo.com/ID
        if ($host === 'vimeo.com' || str_ends_with($host, '.vimeo.com')) {
            if (preg_match('#^/(\d+)#', $path, $m) === 1) {
                return [
                    'embedUrl' => 'https://player.vimeo.com/video/' . $m[1],
                    'tipo'     => 'vimeo',
                ];
            }
        }

        // PeerTube: /videos/watch/UUID  →  /videos/embed/UUID
        // Hay muchas instancias, así que confiamos en el patrón del path
        // en lugar de un allow-list de hosts.
        if (preg_match('#^/videos/(?:watch|embed)/([A-Za-z0-9-]+)#', $path, $m) === 1) {
            return [
                'embedUrl' => $partes['scheme'] . '://' . $partes['host'] . '/videos/embed/' . $m[1],
                'tipo'     => 'peertube',
            ];
        }

        return null;
    }

    private static function renderBotonesCompartir(string $url, string $titulo): string
    {
        if ($url === '') {
            return '';
        }

        $urlEncoded = rawurlencode($url);
        $tituloEncoded = rawurlencode($titulo);

        ob_start();
        ?>
        <div class="fnh-share" aria-label="<?php esc_attr_e('Compartir', 'flavor-news-hub'); ?>">
            <a class="fnh-share-link" href="<?php echo esc_url('https://t.me/share/url?url=' . $urlEncoded . '&text=' . $tituloEncoded); ?>" target="_blank" rel="noopener">
                <?php esc_html_e('Telegram', 'flavor-news-hub'); ?>
            </a>
            <a class="fnh-share-link" href="<?php echo esc_url('https://wa.me/?text=' . $tituloEncoded . '%20' . $urlEncoded); ?>" target="_blank" rel="noopener">
                <?php esc_html_e('WhatsApp', 'flavor-news-hub'); ?>
            </a>
            <a class="fnh-share-link" href="<?php echo esc_url('https://mastodonshare.com/?text=' . $tituloEncoded . '&url=' . $urlEncoded); ?>" target="_blank" rel="noopener">
                <?php esc_html_e('Mastodon', 'flavor-news-hub'); ?>
            </a>
            <a class="fnh-share-link" href="<?php echo esc_url($url); ?>" data-fnh-copy-url="<?php echo esc_attr($url); ?>">
                <?php esc_html_e('Copiar enlace', 'flavor-news-hub'); ?>
            </a>
        </div>
        <?php
        return (string) ob_get_clean();
    }

    private static function idiomaActual(): string
    {
        if (function_exists('pll_current_language')) {
            $idioma = pll_current_language('slug');
            return is_string($idioma) ? $idioma : '';
        }

        if (defined('ICL_LANGUAGE_CODE') && is_string(ICL_LANGUAGE_CODE)) {
            return ICL_LANGUAGE_CODE;
        }

        $idioma = apply_filters('wpml_current_language', null);
        return is_string($idioma) ? $idioma : '';
    }

    private static function urlActual(): string
    {
        $url = get_permalink(get_the_ID()) ?: '';
        return is_string($url) ? $url : '';
    }

    private static function traducirPostId(int $postId): int
    {
        if ($postId <= 0) {
            return 0;
        }

        $idioma = self::idiomaActual();
        if ($idioma === '') {
            return $postId;
        }

        if (function_exists('pll_get_post')) {
            $traducido = pll_get_post($postId, $idioma);
            if (is_int($traducido) && $traducido > 0) {
                return $traducido;
            }
        }

        $traducido = apply_filters('wpml_object_id', $postId, 'page', true, $idioma);
        if (is_int($traducido) && $traducido > 0) {
            return $traducido;
        }

        return $postId;
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
        $tieneShortcode = $post && (
            has_shortcode($post->post_content, 'flavor_news_feed')
            || has_shortcode($post->post_content, 'flavor_news_radios')
            || has_shortcode($post->post_content, 'flavor_news_videos')
            || has_shortcode($post->post_content, 'flavor_news_source')
            || has_shortcode($post->post_content, 'flavor_news_landing')
            || has_shortcode($post->post_content, 'flavor_news_tv')
            || has_shortcode($post->post_content, 'flavor_news_podcasts')
            || has_shortcode($post->post_content, 'flavor_news_sources')
            || has_shortcode($post->post_content, 'flavor_news_sobre')
        );
        $esPaginaAuto = $post && (string) get_post_meta($post->ID, '_fnh_pagina_auto', true) !== '';
        if (!$tieneShortcode && !$esPaginaAuto) {
            return;
        }
        $css = "
        .fnh-shortcode-wrap{--fnh-color-text:var(--flavor-text,#111);--fnh-color-text-soft:var(--flavor-text-muted,#666);--fnh-color-border:var(--flavor-border,#e5e7eb);--fnh-color-surface:var(--flavor-surface,#fff);--fnh-color-surface-alt:var(--flavor-surface-alt,#f7f7f9);--fnh-color-accent:var(--flavor-primary,#111);--fnh-color-accent-contrast:var(--flavor-primary-contrast,#fff);display:grid;gap:1rem;color:var(--fnh-color-text);font:inherit;max-width:100%}
        .fnh-shortcode-wrap,.fnh-shortcode-wrap *{box-sizing:border-box}
        .fnh-shortcode-wrap .fnh-shortcode-body{min-width:0}
        .fnh-shortcode-wrap :where(h2,h3,h4,p,ul,ol){margin-block-start:0}
        .fnh-shortcode-wrap :where(ul,ol){padding-left:0}
        .fnh-shortcode-wrap :where(a){color:inherit}
        .fnh-shortcode-wrap .fnh-empty,.fnh-shortcode-wrap .fnh-vacio{text-align:center;padding:2rem;color:var(--fnh-color-text-soft);font-style:italic;background:var(--fnh-color-surface);border:1px solid var(--fnh-color-border);border-radius:14px}
        .fnh-filtros{display:grid;gap:.9rem;padding:1rem 1.05rem;border:1px solid var(--fnh-color-border);border-radius:14px;background:var(--fnh-color-surface);box-shadow:0 1px 2px rgba(0,0,0,.03)}
        .fnh-filtros-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:.85rem}
        .fnh-filtro-campo{display:grid;gap:.35rem;font-size:.92rem;color:var(--fnh-color-text)}
        .fnh-filtro-campo span{font-weight:600}
        .fnh-filtro-campo select{width:100%;min-height:42px;padding:.65rem .8rem;border:1px solid var(--fnh-color-border);border-radius:10px;background:var(--fnh-color-surface-alt);color:var(--fnh-color-text);font:inherit}
        .fnh-filtros-acciones{display:flex;flex-wrap:wrap;gap:.75rem;align-items:center}
        .fnh-filtros-boton,.fnh-filtros-reset{display:inline-flex;align-items:center;justify-content:center;min-height:40px;padding:.65rem 1rem;border-radius:999px;text-decoration:none;font:inherit;font-weight:600}
        .fnh-filtros-boton{border:0;background:var(--fnh-color-accent);color:var(--fnh-color-accent-contrast);cursor:pointer}
        .fnh-filtros-reset{border:1px solid var(--fnh-color-border);background:transparent;color:var(--fnh-color-text)}
        .fnh-infinite-sentinel{display:flex;justify-content:center;align-items:center;padding:1.5rem 0;min-height:60px}
        .fnh-infinite-sentinel.fnh-infinite-sentinel--done{display:none}
        .fnh-infinite-spinner{font-size:.85rem;color:var(--fnh-color-text-soft);opacity:.7}
        .fnh-shortcode-wrap .fnh-share{display:flex;flex-wrap:wrap;gap:.3rem;margin-top:.45rem}
        .fnh-shortcode-wrap .fnh-share-link{display:inline-flex;align-items:center;justify-content:center;min-height:22px;padding:.15rem .5rem;border:1px solid var(--fnh-color-border);border-radius:999px;background:var(--fnh-color-surface);font-size:.68rem;line-height:1.1;text-decoration:none;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap .fnh-share-link:hover{background:var(--fnh-color-surface-alt);color:var(--fnh-color-text)}
        @media (max-width:640px){.fnh-filtros{padding:.9rem}.fnh-filtros-grid{grid-template-columns:1fr}}

        /* FAB y modal de donaciones (como el bottom sheet de la app). */
        .fnh-dona-fab{position:fixed;bottom:1.5rem;right:1.5rem;width:56px;height:56px;border-radius:50%;background:#ff4d6d;color:#fff;font-size:1.6em;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 6px 20px rgba(255,77,109,.4);z-index:9998;user-select:none;transition:transform .15s,box-shadow .15s;line-height:1}
        .fnh-dona-fab:hover,.fnh-dona-fab:focus{transform:scale(1.08);box-shadow:0 10px 30px rgba(255,77,109,.5);outline:none}
        @media (max-width:640px){.fnh-dona-fab{bottom:1rem;right:1rem;width:52px;height:52px}}
        .fnh-dona-modal{position:fixed;inset:0;z-index:10000;display:none;align-items:center;justify-content:center;padding:1rem}
        .fnh-dona-modal--abierto{display:flex !important}
        .fnh-dona-backdrop{position:absolute;inset:0;background:rgba(0,0,0,.55);backdrop-filter:blur(2px);cursor:pointer}
        .fnh-dona-dialog{position:relative;background:#fff;padding:2rem 1.6rem 1.6rem;border-radius:20px;max-width:480px;width:100%;max-height:90vh;overflow-y:auto;box-shadow:0 20px 60px rgba(0,0,0,.3);text-align:left;animation:fnh-dona-in .2s ease-out}
        @keyframes fnh-dona-in{from{opacity:0;transform:translateY(10px) scale(.96)}to{opacity:1;transform:none}}
        .fnh-dona-cerrar{position:absolute;top:.5rem;right:.6rem;background:transparent;border:0;font-size:1.8em;line-height:1;cursor:pointer;color:#888;width:36px;height:36px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;padding:0;z-index:2}
        .fnh-dona-cerrar:hover{background:#f0f0f0;color:#000}
        .fnh-dona-dialog h2{margin:0 0 .4em !important;color:#b5193a !important;font-size:1.4em !important;border:0 !important;padding:0 !important;font-weight:800;text-align:center}
        .fnh-dona-intro{margin:0 0 1.2em !important;color:#555 !important;line-height:1.45;font-size:.95em;text-align:center}
        .fnh-dona-tarjeta{display:flex !important;align-items:center;gap:.9rem;padding:.9rem 1rem;border-radius:12px;text-decoration:none !important;color:#fff !important;margin:0 0 .6rem !important;transition:transform .12s,box-shadow .12s}
        .fnh-dona-tarjeta:hover{transform:translateY(-1px);box-shadow:0 6px 18px rgba(0,0,0,.15)}
        .fnh-dona-tarjeta--kofi{background:#c06a34 !important}
        .fnh-dona-tarjeta--paypal{background:#2e5cb8 !important}
        .fnh-dona-tarjeta-icono{font-size:1.7em;flex:0 0 auto}
        .fnh-dona-tarjeta-txt{flex:1;display:flex;flex-direction:column;min-width:0;color:#fff !important}
        .fnh-dona-tarjeta-txt strong{font-size:1.05em;font-weight:700;color:#fff !important}
        .fnh-dona-tarjeta-txt span{font-size:.82em;color:rgba(255,255,255,.88) !important}
        .fnh-dona-tarjeta-chevron{font-size:1.6em;opacity:.8;color:#fff}
        .fnh-dona-btc{background:linear-gradient(135deg,#b26b19,#a07818);color:#fff;padding:.85rem 1rem;border-radius:12px;margin:0 0 .6rem}
        .fnh-dona-btc-titulo{color:#fff;font-weight:700;margin-bottom:.45em;font-size:.95em}
        .fnh-dona-btc-titulo small{opacity:.85;font-weight:500;font-size:.82em}
        .fnh-dona-btc-direccion{display:block;font-family:monospace;font-size:.7rem;line-height:1.35;word-break:break-all;color:#fff;background:rgba(0,0,0,.18);padding:.4em .55em;border-radius:6px;margin-bottom:.55em}
        .fnh-dona-btc-copiar{background:rgba(255,255,255,.22);color:#fff;border:0;padding:.45rem .9rem;border-radius:999px;font-weight:600;cursor:pointer;font-size:.85em;transition:background .15s}
        .fnh-dona-btc-copiar:hover{background:rgba(255,255,255,.35)}
        .fnh-dona-compartir{margin-top:1.3rem;padding-top:1rem;border-top:1px solid #eee}
        .fnh-dona-compartir h3{margin:0 0 .3em !important;font-size:.95em;font-weight:700;color:#333}
        .fnh-dona-compartir p{margin:0 0 .7em !important;font-size:.85em;color:#666 !important;line-height:1.45}
        .fnh-dona-compartir-acciones{display:flex;gap:.45rem;flex-wrap:wrap}
        .fnh-dona-compartir-acciones a{padding:.35rem .85rem;border-radius:999px;background:#f3f4f6;color:#333 !important;font-size:.82em;text-decoration:none !important;font-weight:600}
        .fnh-dona-compartir-acciones a:hover{background:#e5e7eb}
        .fnh-dona-otras{margin-top:1.2rem;padding:.9rem 1rem;background:#f7f7f9;border-radius:12px}
        .fnh-dona-otras h3{margin:0 0 .45em !important;font-size:.9em;font-weight:700;color:#333}
        .fnh-dona-otras ul{list-style:none !important;padding:0 !important;margin:0 !important}
        .fnh-dona-otras li{padding:.25em 0;font-size:.86em;color:#555;line-height:1.5}
        .fnh-dona-otras li span{margin-right:.45em}
        .fnh-dona-otras a{color:#333 !important;text-decoration:none !important;font-weight:500}
        .fnh-dona-otras a:hover{text-decoration:underline !important}
        .fnh-dona-ecosistema{display:flex !important;align-items:center;gap:.8rem;margin-top:1rem;padding:.85rem 1rem;background:#fff7e6;border:1px solid #ffe4b3;border-radius:12px;text-decoration:none !important;color:#5c3e00 !important}
        .fnh-dona-ecosistema:hover{background:#ffefd1}
        .fnh-dona-eco-icono{font-size:1.5em}
        .fnh-dona-eco-txt{display:flex;flex-direction:column;color:#5c3e00 !important}
        .fnh-dona-eco-txt strong{font-weight:700;font-size:.95em}
        .fnh-dona-eco-txt span{font-size:.8em;opacity:.8}

        /* En la landing (Inicio) ocultamos el entry-header del tema:
           el hero ya tiene su propio título grande y el tema añade un
           <h1>Inicio</h1> redundante encima. Sólo aplica a /inicio —
           las otras páginas auto mantienen el título del tema. */
        body.fnh-pagina-inicio .entry-header,
        body.fnh-pagina-inicio article > div > header:first-child,
        body.fnh-pagina-inicio article > header:first-child{display:none !important}

        /* Menú de navegación entre las páginas auto (Inicio/Noticias/...). */
        .fnh-nav-auto{max-width:1200px;margin:1rem auto 1.5rem;padding:0 1.25rem}
        .fnh-nav-auto-lista{display:flex;list-style:none;gap:.35rem;padding:.4rem;margin:0;background:#f1f1f4;border-radius:999px;overflow-x:auto;scrollbar-width:none}
        .fnh-nav-auto-lista::-webkit-scrollbar{display:none}
        .fnh-nav-auto-item{list-style:none;margin:0}
        .fnh-nav-auto-item a{display:inline-block;padding:.55rem 1.2rem;border-radius:999px;color:#555;font-weight:600;font-size:.95em;white-space:nowrap;text-decoration:none;transition:background .15s,color .15s,transform .15s}
        .fnh-nav-auto-item a:hover{background:#e4e4ea;color:#111;transform:translateY(-1px)}
        .fnh-nav-auto-item--activo a{background:#111;color:#fff}
        .fnh-nav-auto-item--activo a:hover{background:#000;color:#fff;transform:none}
        .fnh-nav-auto-item--cta a{background:#ff4d6d;color:#fff}
        .fnh-nav-auto-item--cta a:hover{background:#e0334e;color:#fff}

        /* Página TV: grid de canales */
        .fnh-shortcode-wrap .fnh-tv-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:14px;padding:0}
        .fnh-shortcode-wrap .fnh-tv-card{display:block;padding:1.25rem;border:1px solid var(--fnh-color-border);border-radius:12px;background:var(--fnh-color-surface);text-decoration:none;color:inherit;transition:box-shadow .15s,transform .15s}
        .fnh-tv-card:hover{box-shadow:0 8px 20px rgba(0,0,0,.08);transform:translateY(-2px)}
        .fnh-shortcode-wrap .fnh-tv-card h3{margin:0 0 .5em;font-size:1.05em;color:var(--fnh-color-text);font-weight:700}
        .fnh-shortcode-wrap .fnh-tv-terr,.fnh-shortcode-wrap .fnh-tv-idiomas,.fnh-shortcode-wrap .fnh-tv-cc{display:inline-block;margin-right:.4em;margin-bottom:.3em;padding:.15em .6em;background:var(--fnh-color-surface-alt);border-radius:999px;font-size:.78em;color:var(--fnh-color-text-soft)}
        .fnh-tv-cc{background:#dcfce7;color:#166534;font-weight:600}

        /* Página Fuentes: directorio agrupado por territorio */
        .fnh-shortcode-wrap .fnh-sources-directorio{padding:0}
        .fnh-shortcode-wrap .fnh-sources-territorio{margin:1.5rem 0 .5rem;font-size:1.1em;color:var(--fnh-color-text);font-weight:700;border-bottom:2px solid var(--fnh-color-text);padding-bottom:.2em;display:inline-block}
        .fnh-shortcode-wrap .fnh-sources-total{color:var(--fnh-color-text-soft);font-weight:400;font-size:.88em}
        .fnh-shortcode-wrap .fnh-sources-lista{list-style:none;padding:0;margin:0 0 1.5rem;display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:.4rem}
        .fnh-shortcode-wrap .fnh-source-item a{display:flex;align-items:center;gap:.5rem;padding:.6rem .85rem;border:1px solid var(--fnh-color-border);border-radius:8px;text-decoration:none;color:inherit;background:var(--fnh-color-surface-alt);transition:background .15s}
        .fnh-source-item a:hover{background:#f0f0f2}
        .fnh-shortcode-wrap .fnh-source-nombre{flex:1;font-weight:600;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap .fnh-source-idiomas,.fnh-shortcode-wrap .fnh-source-tipo{font-size:.75em;color:var(--fnh-color-text-soft);background:var(--fnh-color-surface);padding:.1em .5em;border-radius:4px}

        /* Directorio de colectivos — mismo patrón visual que el de fuentes. */
        .fnh-shortcode-wrap .fnh-collectives-directorio{padding:0}
        .fnh-shortcode-wrap .fnh-collectives-territorio{margin:1.5rem 0 .5rem;font-size:1.1em;color:var(--fnh-color-text);font-weight:700;border-bottom:2px solid var(--fnh-color-text);padding-bottom:.2em;display:inline-block}
        .fnh-shortcode-wrap .fnh-collectives-total{color:var(--fnh-color-text-soft);font-weight:400;font-size:.88em}
        .fnh-shortcode-wrap .fnh-collectives-lista{list-style:none;padding:0;margin:0 0 1.5rem;display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:.4rem}
        .fnh-shortcode-wrap .fnh-collective-item a{display:flex;flex-direction:column;gap:.2rem;padding:.7rem .9rem;border:1px solid var(--fnh-color-border);border-radius:10px;text-decoration:none;color:inherit;background:var(--fnh-color-surface-alt);transition:background .15s,transform .1s}
        .fnh-collective-item a:hover{background:#f0f0f2;transform:translateY(-1px)}
        .fnh-shortcode-wrap .fnh-collective-nombre{font-weight:600;color:var(--fnh-color-text);line-height:1.3}
        .fnh-shortcode-wrap .fnh-collective-topics{font-size:.78em;color:var(--fnh-color-text-soft);line-height:1.3}
        .fnh-shortcode-wrap .fnh-collective-web{font-size:.72em;color:var(--fnh-color-accent);font-weight:500;word-break:break-all}

        /* Página Sobre */
        .fnh-shortcode-wrap .fnh-sobre{max-width:760px;margin:0 auto;line-height:1.6}
        .fnh-shortcode-wrap .fnh-sobre-hero{padding:1.5rem 0;border-bottom:1px solid var(--fnh-color-border);margin-bottom:1.5rem}
        .fnh-shortcode-wrap .fnh-sobre-hero h2{margin:0 0 .4em;font-size:1.7em;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap .fnh-sobre-hero p{font-size:1.1em;color:#444;margin:0}
        .fnh-shortcode-wrap .fnh-sobre-bloque{margin:2rem 0}
        .fnh-shortcode-wrap .fnh-sobre-bloque h3{margin:0 0 .8em;font-size:1.2em;color:var(--fnh-color-text);border-left:4px solid #3ddc84;padding-left:.6em}
        .fnh-shortcode-wrap .fnh-sobre-principios{padding-left:1.3em;margin:0}
        .fnh-shortcode-wrap .fnh-sobre-principios li{margin:.7em 0;color:#333}
        .fnh-shortcode-wrap .fnh-sobre-lista-plana{list-style:none;padding:0;margin:0}
        .fnh-shortcode-wrap .fnh-sobre-lista-plana li{padding:.4em 0 .4em 1.2em;position:relative;color:#444}
        .fnh-sobre-lista-plana li::before{content:\"·\";position:absolute;left:0;color:#3ddc84;font-size:1.4em;top:-.15em}
        .fnh-sobre-cta{display:inline-block;padding:.6rem 1.25rem;background:#111;color:#fff !important;border-radius:999px;text-decoration:none;font-weight:600;margin-top:.4em}
        .fnh-sobre-cta:hover{background:#000}

        .fnh-shortcode-wrap .fnh-feed-lista,.fnh-shortcode-wrap .fnh-radios-lista,.fnh-shortcode-wrap .fnh-videos-grid{list-style:none;padding:0;margin:0}
        .fnh-shortcode-wrap .fnh-feed-lista li{padding:12px 0;border-bottom:1px solid var(--fnh-color-border)}
        .fnh-shortcode-wrap .fnh-feed-lista h3{margin:0 0 4px;font-size:1.05em;line-height:1.3}
        .fnh-shortcode-wrap .fnh-feed-lista .fnh-meta{font-size:.85em;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap .fnh-feed-lista .fnh-excerpt{margin-top:.45rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero{display:grid;grid-template-columns:1fr;gap:1rem;align-items:stretch;padding:1.25rem 1.25rem 1.4rem;margin-bottom:.25rem;border:1px solid var(--fnh-color-border);border-radius:22px;background:linear-gradient(135deg,var(--fnh-color-surface) 0%,var(--fnh-color-surface-alt) 100%);box-shadow:0 12px 30px rgba(0,0,0,.05);position:relative;overflow:hidden}
        .fnh-shortcode-wrap--feed .fnh-feed-hero::before{content:\"\";position:absolute;inset:0;background:radial-gradient(circle at 14% 18%,rgba(255,255,255,.7),transparent 32%),radial-gradient(circle at 86% 10%,rgba(255,255,255,.4),transparent 22%);pointer-events:none}
        .fnh-shortcode-wrap--feed .fnh-feed-hero > *{position:relative;z-index:1}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-titular{display:grid;gap:.55rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-kicker{display:inline-flex;align-items:center;gap:.45rem;font-size:.74rem;letter-spacing:.08em;text-transform:uppercase;font-weight:700;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-kicker::before{content:\"\";width:.55rem;height:.55rem;border-radius:999px;background:var(--fnh-color-accent);opacity:.9;flex:0 0 auto}
        .fnh-shortcode-wrap--feed .fnh-feed-hero h2{margin:0;font-size:1.95rem;line-height:1.02;letter-spacing:-.04em;color:var(--fnh-color-text);max-width:18ch}
        .fnh-shortcode-wrap--feed .fnh-feed-hero p{margin:0;color:var(--fnh-color-text-soft);max-width:62ch}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-estadistica{justify-self:stretch;align-self:end;display:flex;flex-direction:row;align-items:center;gap:1.25rem;flex-wrap:wrap;min-width:0;width:100%;padding:.8rem 1.05rem;border-radius:14px;background:rgba(255,255,255,.72);border:1px solid rgba(255,255,255,.45);backdrop-filter:blur(8px);order:2}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-estadistica > div:first-child{display:flex;align-items:baseline;gap:.5rem;min-width:0}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-numero{font-size:1.5rem;font-weight:800;line-height:1;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-etiqueta{font-size:.82rem;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal{display:grid;grid-template-columns:1fr;gap:1rem;align-items:stretch;padding:1rem;border-radius:18px;background:rgba(255,255,255,.68);border:1px solid rgba(255,255,255,.4);box-shadow:0 10px 26px rgba(0,0,0,.05)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal--sin-media{grid-template-columns:1fr}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-media{display:block;border-radius:14px;overflow:hidden;min-height:220px;max-height:360px;aspect-ratio:16/10;align-self:start;background:var(--fnh-color-surface-alt);text-decoration:none}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-media img{width:100% !important;height:100% !important;object-fit:cover;display:block}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-contenido{display:grid;gap:.65rem;align-content:start;padding:.15rem .15rem .1rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-badge{display:inline-flex;align-items:center;justify-content:center;min-height:30px;width:max-content;padding:.2rem .65rem;border-radius:999px;background:rgba(0,0,0,.08);font-size:.72rem;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-meta{font-size:.82rem;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal h3{margin:0;font-size:1.34rem;line-height:1.13;letter-spacing:-.03em;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt{color:var(--fnh-color-text-soft);line-height:1.55;font-size:.95rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-cta{display:inline-flex;align-items:center;justify-content:center;min-height:36px;padding:.45rem .85rem;border-radius:999px;background:var(--fnh-color-accent);color:var(--fnh-color-accent-contrast);text-decoration:none;font-size:.82rem;font-weight:700;justify-self:start}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-cta:hover{filter:brightness(.95)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-mosaico{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:1rem;margin-top:1rem;align-items:start}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundarias{display:grid;gap:.9rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria{display:grid;grid-template-columns:92px minmax(0,1fr);gap:.7rem;padding:.7rem;border-radius:14px;background:rgba(255,255,255,.68);border:1px solid rgba(255,255,255,.32);box-shadow:0 4px 12px rgba(0,0,0,.03);align-items:start;align-content:start}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria--sin-media{grid-template-columns:1fr}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-media{display:block;border-radius:12px;overflow:hidden;width:92px;height:92px;flex:0 0 92px;aspect-ratio:1;align-self:start;background:var(--fnh-color-surface-alt);text-decoration:none}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-media img{width:100% !important;height:100% !important;object-fit:cover;display:block;max-height:100%}
        /* Algunos feeds (Zuzeu y similares) vienen con <img> embebidas
           dentro del excerpt. Las escondemos para no duplicar la
           portada y evitar desbordes del float:left inline. Además
           neutralizamos float: por si el excerpt usa otro selector. */
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt img,
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-excerpt img,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt img,
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt [style*=float],
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt [style*=float]{display:none !important;float:none !important}
        /* Truncar excerpts largos (algunos feeds meten el artículo
           entero) a 3 líneas para que las cards no se estiren en
           vertical y rompan el grid. */
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt,
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-excerpt,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;max-height:5em}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt{-webkit-line-clamp:4;max-height:6.5em}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-excerpt p,
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-excerpt p,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt p{display:inline;margin:0}
        /* Títulos largos a 3 líneas máximo. */
        .fnh-shortcode-wrap--feed .fnh-feed-hero-principal h3,
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria h4,
        .fnh-shortcode-wrap--feed .fnh-feed-item h3{display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-contenido{display:grid;gap:.28rem;align-content:start}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-meta{font-size:.7rem;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria h4{margin:0;font-size:.92rem;line-height:1.22;letter-spacing:-.01em;color:var(--fnh-color-text)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-excerpt{font-size:.8rem;line-height:1.35;color:var(--fnh-color-text-soft)}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-cta{font-size:.72rem;font-weight:700;text-decoration:none;color:var(--fnh-color-accent);justify-self:start}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria-cta:hover{text-decoration:underline}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-temas{display:flex;flex-wrap:wrap;gap:.45rem;margin-top:.25rem}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-tema{display:inline-flex;align-items:center;gap:.35rem;min-height:32px;padding:.3rem .7rem;border-radius:999px;background:rgba(255,255,255,.78);border:1px solid rgba(255,255,255,.4);text-decoration:none;font-size:.82rem;font-weight:600;color:var(--fnh-color-text);transition:transform .15s,background .15s,box-shadow .15s}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-tema span{opacity:.68;font-weight:700}
        .fnh-shortcode-wrap--feed .fnh-feed-hero-tema:hover{background:rgba(255,255,255,.95);transform:translateY(-1px);box-shadow:0 4px 12px rgba(0,0,0,.06)}
        @media (max-width:760px){
          .fnh-shortcode-wrap--feed .fnh-feed-hero{grid-template-columns:1fr;align-items:start}
          .fnh-shortcode-wrap--feed .fnh-feed-hero-estadistica{justify-self:start;min-width:0;width:100%}
          .fnh-shortcode-wrap--feed .fnh-feed-hero h2{font-size:1.55rem}
          .fnh-shortcode-wrap--feed .fnh-feed-hero-principal{grid-template-columns:1fr}
          .fnh-shortcode-wrap--feed .fnh-feed-hero-principal-media{min-height:180px}
          .fnh-shortcode-wrap--feed .fnh-feed-hero-mosaico{grid-template-columns:1fr}
          .fnh-shortcode-wrap--feed .fnh-feed-hero-secundaria{grid-template-columns:84px minmax(0,1fr)}
        }
        .fnh-shortcode-wrap--feed .fnh-feed-lista{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:1rem;align-items:start;grid-auto-rows:max-content}
        .fnh-shortcode-wrap--feed .fnh-feed-item{display:flex;flex-direction:column;gap:.75rem;padding:0;border:1px solid var(--fnh-color-border);border-radius:18px;overflow:hidden;background:var(--fnh-color-surface);box-shadow:0 1px 2px rgba(0,0,0,.03);min-width:0;width:100%}
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-media{order:-1;margin:0;aspect-ratio:16/10;overflow:hidden;background:var(--fnh-color-surface-alt)}
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-media img{width:100% !important;height:100% !important;object-fit:cover;display:block;max-height:100% !important;min-height:0}
        .fnh-shortcode-wrap--feed .fnh-feed-item h3{font-size:1.04em;line-height:1.25;margin:0;word-wrap:break-word;overflow-wrap:break-word;hyphens:auto}
        .fnh-shortcode-wrap--feed .fnh-feed-item p,.fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt{word-wrap:break-word;overflow-wrap:break-word;min-width:0}
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-meta,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-share{padding:0 1rem}
        .fnh-shortcode-wrap--feed .fnh-feed-item h3,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-media,
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-meta{padding-left:1rem;padding-right:1rem}
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-meta{margin-top:-.15rem}
        .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-excerpt{padding-bottom:.25rem}
        /* El destacado ya no ocupa 2x2 — todas las cards son iguales
           para evitar layouts con filas desalineadas cuando el texto
           de una card es mucho más largo que las otras. */
        .fnh-shortcode-wrap--feed .fnh-feed-item--destacado{grid-column:auto;grid-row:auto}
        .fnh-shortcode-wrap--feed .fnh-feed-item--destacado .fnh-media{aspect-ratio:16/10}
        .fnh-shortcode-wrap--feed .fnh-feed-item--destacado h3{font-size:1.25em}
        .fnh-shortcode-wrap--feed .fnh-feed-item--destacado .fnh-excerpt{font-size:.98em}
        @media (max-width:960px){
          .fnh-shortcode-wrap--feed .fnh-feed-lista{grid-template-columns:repeat(2,minmax(0,1fr))}
          .fnh-shortcode-wrap--feed .fnh-feed-item--destacado{grid-column:1/-1;grid-row:auto}
        }
        @media (max-width:640px){
          .fnh-shortcode-wrap--feed .fnh-feed-lista{grid-template-columns:1fr}
          .fnh-shortcode-wrap--feed .fnh-feed-item .fnh-media{aspect-ratio:16/9}
        }
        .fnh-shortcode-wrap .fnh-videos-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:1rem;list-style:none;padding:0;margin:0}
        .fnh-shortcode-wrap .fnh-video-card{display:flex;flex-direction:column;gap:.55rem;background:var(--fnh-color-surface);border:1px solid var(--fnh-color-border);border-radius:14px;overflow:hidden;box-shadow:0 1px 2px rgba(0,0,0,.03);min-width:0}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video{display:block;position:relative;background:#000;overflow:hidden;aspect-ratio:16/9;text-decoration:none}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .2s}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video--embebible:hover img{transform:scale(1.02)}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-play{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:2.6rem;color:#fff;text-shadow:0 2px 10px rgba(0,0,0,.6);pointer-events:none;opacity:.92;transition:opacity .15s}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video--embebible:hover .fnh-video-play{opacity:1}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-iframe-wrap{position:relative;aspect-ratio:16/9;background:#000}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-iframe-wrap iframe{position:absolute;inset:0;width:100%;height:100%;border:0;display:block}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-contenido{display:flex;flex-direction:column;gap:.35rem;padding:.15rem 1rem 0}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-meta{font-size:.78rem;color:var(--fnh-color-text-soft);font-weight:600}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-titulo{margin:0;font-size:1rem;line-height:1.3;font-weight:700;word-wrap:break-word;overflow-wrap:break-word}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-titulo a{color:var(--fnh-color-text) !important;text-decoration:none}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-titulo a:hover{text-decoration:underline}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-excerpt{font-size:.85rem;color:var(--fnh-color-text-soft);line-height:1.4;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;margin:0}
        .fnh-shortcode-wrap .fnh-video-card .fnh-video-excerpt p{margin:0 !important}
        .fnh-shortcode-wrap .fnh-video-card .fnh-share{padding:0 1rem 1rem}
        .fnh-shortcode-wrap .fnh-radios-lista{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:.8rem;padding:0;list-style:none}
        .fnh-shortcode-wrap .fnh-radios-lista .fnh-radio{border:1px solid var(--fnh-color-border);border-radius:12px;padding:1rem;background:var(--fnh-color-surface);display:flex;flex-direction:column;gap:.4rem;min-width:0;box-shadow:0 1px 2px rgba(0,0,0,.03);list-style:none}
        .fnh-shortcode-wrap .fnh-radios-lista .fnh-radio h4{margin:0 !important;font-size:1em;font-weight:600;color:var(--fnh-color-text) !important}
        .fnh-shortcode-wrap .fnh-radios-lista .fnh-radio .fnh-meta{font-size:.82em;color:var(--fnh-color-text-soft) !important}
        .fnh-shortcode-wrap .fnh-radios-lista .fnh-radio a.fnh-listen{display:inline-block;margin-top:.2em;font-size:.88em;color:var(--fnh-color-accent) !important;text-decoration:none}
        .fnh-shortcode-wrap .fnh-radios-lista .fnh-radio a.fnh-listen:hover{text-decoration:underline}
        /* Audio player: width:100% evita que el control nativo (~300px)
           se salga del contenedor y rompa el grid en móvil. */
        .fnh-shortcode-wrap audio{width:100% !important;max-width:100% !important;min-width:0;display:block;margin:.3em 0}
        /* Blindaje tipográfico y de listas contra Tailwind prose / temas
           que aplican reglas genéricas a `.prose h2`, `.prose ul`, etc.
           y pisan nuestros shortcodes. Especificidad subida y !important
           en propiedades de layout clave. */
        .fnh-shortcode-wrap h2{font-size:1.45em !important;font-weight:700 !important;margin:0 0 1rem !important;line-height:1.25 !important;color:var(--fnh-color-text) !important}
        .fnh-shortcode-wrap h3{font-size:1.1em !important;font-weight:700 !important;margin:0 0 .4em !important;line-height:1.3 !important;color:var(--fnh-color-text) !important}
        .fnh-shortcode-wrap h4{font-size:1em !important;font-weight:600 !important;margin:0 0 .35em !important;color:var(--fnh-color-text) !important}
        .fnh-shortcode-wrap ul,.fnh-shortcode-wrap ol{padding-left:0 !important;margin:0 !important;list-style:none !important}
        /* ELIMINADO: regla .fnh-feed-lista li con grid 200px 1fr — pisaba
           a .fnh-feed-item (que define la card real) por mayor
           especificidad, dejando h3/meta/media/excerpt/share en 2
           columnas descuadradas. Los estilos de card ya viven en
           .fnh-shortcode-wrap--feed .fnh-feed-item. */
        .fnh-shortcode-wrap .fnh-feed-lista h3 a{color:var(--fnh-color-text) !important;text-decoration:none}
        .fnh-shortcode-wrap .fnh-feed-lista h3 a:hover{text-decoration:underline}
        .fnh-shortcode-wrap .fnh-feed-lista .fnh-excerpt p{margin:.25em 0 !important;font-size:.93em;color:var(--fnh-color-text-soft)}
        @media (max-width:640px){
          .fnh-shortcode-wrap .fnh-radios-lista{grid-template-columns:1fr}
        }
        #fnh-landing{display:flex !important;flex-direction:column;gap:2.5rem;padding:0 !important;max-width:1200px;margin-inline:auto;font-family:inherit;line-height:1.5;color:#111 !important;background:transparent !important}
        #fnh-landing *{box-sizing:border-box}
        #fnh-landing h1,#fnh-landing h2,#fnh-landing h3,#fnh-landing h4{font-family:inherit;color:#111 !important;font-weight:700}
        #fnh-landing a{color:inherit;text-decoration:none}

        /* HERO con gradiente oscuro. */
        #fnh-landing .fnh-hero{background:linear-gradient(135deg,#1a2332 0%,#2d1b4e 60%,#4a1d3e 100%) !important;color:#fff !important;padding:5rem 2rem !important;border-radius:20px !important;border:0 !important;text-align:center !important;margin:0 !important;position:relative;overflow:hidden}
        #fnh-landing .fnh-hero::before{content:\"\";position:absolute;inset:0;background:radial-gradient(circle at 30% 40%,rgba(61,220,132,.15),transparent 60%),radial-gradient(circle at 75% 60%,rgba(147,80,220,.2),transparent 55%);pointer-events:none}
        #fnh-landing .fnh-hero-inner{position:relative;max-width:780px;margin:0 auto}
        #fnh-landing .fnh-hero h1{color:#fff !important;font-size:clamp(2.2em,5vw,3.4em) !important;margin:0 0 .3em !important;border:0;padding:0 !important;line-height:1.1 !important;letter-spacing:-.01em}
        #fnh-landing .fnh-hero .fnh-lema{font-size:clamp(1.05em,2vw,1.3em) !important;color:rgba(255,255,255,.85) !important;max-width:52ch;margin:0 auto 1.8em !important;line-height:1.45}
        #fnh-landing .fnh-hero-ctas{display:flex !important;gap:.8rem;flex-wrap:wrap;justify-content:center}
        #fnh-landing .fnh-btn{display:inline-flex !important;align-items:center;padding:.85rem 1.75rem !important;border-radius:999px !important;font-weight:600 !important;font-size:1em !important;text-decoration:none !important;transition:transform .15s,box-shadow .15s;border:2px solid transparent}
        #fnh-landing .fnh-btn-primary{background:#3ddc84 !important;color:#0a0a0a !important}
        #fnh-landing .fnh-btn-primary:hover{transform:translateY(-1px);box-shadow:0 6px 18px rgba(61,220,132,.35)}
        #fnh-landing .fnh-btn-ghost{background:transparent !important;color:#fff !important;border-color:rgba(255,255,255,.35) !important}
        #fnh-landing .fnh-btn-ghost:hover{background:rgba(255,255,255,.08) !important;border-color:#fff !important}
        #fnh-landing .fnh-bloque{margin:0 !important;padding:.5rem 1rem !important;background:transparent !important}
        #fnh-landing .fnh-bloque-alt{background:#f7f7f9 !important;padding:2.5rem 1.5rem !important;border-radius:16px !important;margin:0 !important}
        #fnh-landing .fnh-seccion-titulo{margin:0 0 1.25rem !important;font-size:1.55em !important;font-weight:800 !important;letter-spacing:-.01em;color:#111 !important;background:transparent !important;border:0 !important;padding:0 !important;display:flex !important;align-items:center;gap:.6rem}
        #fnh-landing .fnh-seccion-ico{font-size:.95em;display:inline-flex;align-items:center;justify-content:center;width:2rem;height:2rem;background:#111;color:#fff;border-radius:8px}
        #fnh-landing .fnh-bloque h2{margin:0 0 1rem !important;font-size:1.4em !important;color:#111 !important;background:transparent !important;border:0 !important;padding:0 !important}
        #fnh-landing .fnh-subseccion{margin:0 0 .75rem !important;font-size:.78em !important;text-transform:uppercase !important;letter-spacing:.08em !important;color:#666 !important;font-weight:600 !important;border:0 !important;padding:0 !important}

        /* PORTADA EDITORIAL: una destacada grande + 4 mini en grid 2fr 1fr 1fr. */
        #fnh-landing .fnh-portada-grid{display:grid !important;grid-template-columns:2fr 1fr 1fr;grid-template-rows:auto auto;gap:1rem !important}
        #fnh-landing .fnh-portada-card{display:flex !important;flex-direction:column;text-decoration:none !important;border-radius:12px !important;overflow:hidden;background:#fff !important;border:1px solid #eee;transition:transform .15s,box-shadow .15s;color:inherit !important}
        #fnh-landing .fnh-portada-card:hover{transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,0,0,.08)}
        #fnh-landing .fnh-portada-destacada{grid-column:1;grid-row:1/span 2}
        #fnh-landing .fnh-portada-destacada .fnh-portada-imagen{aspect-ratio:16/9}
        #fnh-landing .fnh-portada-destacada .fnh-portada-imagen img{width:100% !important;height:100% !important;object-fit:cover;display:block}
        #fnh-landing .fnh-portada-destacada .fnh-portada-titulo{font-size:1.6em !important;line-height:1.2 !important}
        #fnh-landing .fnh-portada-mini .fnh-portada-imagen{aspect-ratio:16/10}
        #fnh-landing .fnh-portada-mini .fnh-portada-imagen img{width:100% !important;height:100% !important;object-fit:cover;display:block}
        #fnh-landing .fnh-portada-mini .fnh-portada-titulo{font-size:1em !important;line-height:1.3 !important}
        #fnh-landing .fnh-portada-texto{padding:.85rem 1rem 1rem !important;flex:1;display:flex;flex-direction:column;gap:.35rem}
        #fnh-landing .fnh-portada-fuente{font-size:.7em !important;text-transform:uppercase !important;letter-spacing:.08em;color:#c32e2e !important;font-weight:700}
        #fnh-landing .fnh-portada-titulo{margin:0 !important;color:#111 !important;font-weight:700}
        @media (max-width:900px){
          #fnh-landing .fnh-portada-grid{grid-template-columns:1fr 1fr;grid-template-rows:auto}
          #fnh-landing .fnh-portada-destacada{grid-column:1/-1;grid-row:auto}
        }
        @media (max-width:560px){
          #fnh-landing .fnh-portada-grid{grid-template-columns:1fr}
          #fnh-landing .fnh-portada-destacada{grid-column:auto}
        }
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
        /* CTA descarga con carácter: fondo oscuro, ilustración tipográfica. */
        #fnh-landing .fnh-descarga{background:radial-gradient(ellipse at top,#1a1a1a 0%,#0a0a0a 100%) !important;color:#fff !important;padding:3.5rem 2rem !important;border-radius:20px !important;text-align:center !important;border:0 !important;position:relative;overflow:hidden}
        #fnh-landing .fnh-descarga::after{content:\"\";position:absolute;inset:0;background:radial-gradient(circle at 70% 30%,rgba(61,220,132,.18),transparent 50%);pointer-events:none}
        #fnh-landing .fnh-descarga-inner{position:relative;max-width:560px;margin:0 auto}
        #fnh-landing .fnh-descarga .fnh-descarga-titulo{margin:0 0 .5em !important;font-size:clamp(1.7em,3.5vw,2.4em) !important;color:#fff !important;border:0 !important;padding:0 !important;font-weight:800;letter-spacing:-.01em}
        #fnh-landing .fnh-descarga-copy{color:rgba(255,255,255,.78) !important;font-size:1.05em;margin:0 0 1.6em !important;line-height:1.55}
        #fnh-landing .fnh-descarga .fnh-version{font-size:.85em;opacity:.6;margin:1em 0 0 !important;color:#fff !important;letter-spacing:.02em}
        #fnh-landing .fnh-boton-descarga{display:inline-flex !important;align-items:center;gap:.5rem;padding:1rem 2.2rem !important;background:#3ddc84 !important;color:#0a0a0a !important;border-radius:999px !important;font-weight:700 !important;text-decoration:none !important;font-size:1.1em !important;transition:transform .15s,box-shadow .2s}
        #fnh-landing .fnh-boton-descarga:hover{background:#5ae89a !important;transform:translateY(-2px);box-shadow:0 10px 25px rgba(61,220,132,.4)}
        #fnh-landing .fnh-boton-descarga-ico{font-size:.85em}
        #fnh-landing .fnh-repo{text-align:center;font-size:.9em;color:#777}
        #fnh-landing .fnh-apoyo{background:linear-gradient(135deg,#fff1f3 0%,#ffe4e9 100%) !important;padding:2.5rem 1.5rem !important;border-radius:16px !important;border:1px solid #ffc3cf !important;text-align:center !important;margin:0 !important}
        #fnh-landing .fnh-apoyo-inner{max-width:560px;margin:0 auto}
        #fnh-landing .fnh-apoyo-titulo{margin:0 0 .5em !important;font-size:1.6em !important;color:#b5193a !important;border:0 !important;padding:0 !important;font-weight:800}
        #fnh-landing .fnh-apoyo-copy{color:#4a1020 !important;font-size:1em;margin:0 0 1.2em !important;line-height:1.55}
        #fnh-landing .fnh-boton-apoyo{display:inline-block !important;padding:.85rem 2rem !important;background:#ff4d6d !important;color:#fff !important;border:0 !important;border-radius:999px !important;font-weight:700 !important;text-decoration:none !important;font-size:1.05em !important;cursor:pointer;font-family:inherit;transition:transform .15s,box-shadow .2s}
        #fnh-landing .fnh-boton-apoyo:hover{background:#e0334e !important;transform:translateY(-1px);box-shadow:0 8px 20px rgba(255,77,109,.4)}

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

        $restBase = esc_url_raw(rest_url('flavor-news/v1/feed-html'));
        $js = <<<JS
(function () {
    document.addEventListener('click', function (event) {
        var trigger = event.target.closest('[data-fnh-copy-url]');
        if (!trigger) {
            return;
        }
        event.preventDefault();
        var url = trigger.getAttribute('data-fnh-copy-url');
        if (!url || !navigator.clipboard || !navigator.clipboard.writeText) {
            return;
        }
        navigator.clipboard.writeText(url).then(function () {
            var original = trigger.textContent;
            trigger.textContent = 'Copiado';
            window.setTimeout(function () {
                trigger.textContent = original;
            }, 1400);
        });
    });

    // Reproducción inline de vídeos CC: al pulsar sobre una thumbnail
    // marcada como embebible (data-fnh-embed-url) sustituimos el enlace
    // por un iframe con autoplay. Ctrl/cmd/shift-click abre en pestaña
    // externa como siempre, respetando la expectativa del usuario.
    document.addEventListener('click', function (event) {
        var video = event.target.closest('.fnh-video--embebible');
        if (!video) return;
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.button === 1) {
            return;
        }
        var embedUrl = video.getAttribute('data-fnh-embed-url');
        if (!embedUrl) return;
        event.preventDefault();

        var contenedor = document.createElement('div');
        contenedor.className = 'fnh-video-iframe-wrap';
        var iframe = document.createElement('iframe');
        // Añadimos autoplay=1 a la URL de embed. En YouTube/Vimeo/
        // PeerTube el parámetro es el mismo.
        var separador = embedUrl.indexOf('?') === -1 ? '?' : '&';
        iframe.src = embedUrl + separador + 'autoplay=1';
        iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen';
        iframe.setAttribute('allowfullscreen', '');
        iframe.setAttribute('loading', 'lazy');
        iframe.referrerPolicy = 'strict-origin-when-cross-origin';
        contenedor.appendChild(iframe);
        video.replaceWith(contenedor);
    });

    // Scroll infinito: observa cada sentinel y pide la siguiente página
    // al endpoint REST /feed-html. Añade los items al destino correcto
    // (ul.fnh-feed-lista o div.fnh-videos-grid) y actualiza data-current-page.
    var REST_URL = '$restBase';
    var sentinelesBloqueados = new WeakSet();
    function destinoDeSentinel(sentinel) {
        var ctx = sentinel.getAttribute('data-context') || '';
        var wrap = sentinel.closest('.fnh-shortcode-wrap');
        if (!wrap) return null;
        if (ctx === 'videos') {
            return wrap.querySelector('.fnh-videos-grid');
        }
        return wrap.querySelector('.fnh-feed-lista');
    }
    function cargarSiguientePagina(sentinel) {
        if (sentinelesBloqueados.has(sentinel)) return;
        var actual = parseInt(sentinel.getAttribute('data-current-page') || '1', 10);
        var total = parseInt(sentinel.getAttribute('data-total-pages') || '1', 10);
        if (actual >= total) {
            sentinel.classList.add('fnh-infinite-sentinel--done');
            return;
        }
        sentinelesBloqueados.add(sentinel);
        var proximaPagina = actual + 1;
        var params = new URLSearchParams();
        params.set('context', sentinel.getAttribute('data-context') || 'feed');
        params.set('page', String(proximaPagina));
        params.set('per_page', sentinel.getAttribute('data-per-page') || '10');
        ['topic','territory','language','source_type','exclude_source_type','show_excerpt','show_media'].forEach(function (clave) {
            var valor = sentinel.getAttribute('data-' + clave);
            if (valor !== null && valor !== '') {
                params.set(clave, valor);
            }
        });
        fetch(REST_URL + '?' + params.toString(), { credentials: 'same-origin' })
            .then(function (res) { return res.ok ? res.json() : Promise.reject(res.status); })
            .then(function (data) {
                var destino = destinoDeSentinel(sentinel);
                if (destino && data && typeof data.html === 'string' && data.html.length > 0) {
                    destino.insertAdjacentHTML('beforeend', data.html);
                }
                sentinel.setAttribute('data-current-page', String(proximaPagina));
                if (!data || !data.has_more) {
                    sentinel.classList.add('fnh-infinite-sentinel--done');
                } else {
                    sentinelesBloqueados.delete(sentinel);
                }
            })
            .catch(function () {
                // En caso de error liberamos el lock para permitir reintento
                // cuando el usuario siga bajando.
                sentinelesBloqueados.delete(sentinel);
            });
    }
    function inicializarSentineles() {
        var sentineles = document.querySelectorAll('.fnh-infinite-sentinel:not([data-fnh-observado])');
        if (sentineles.length === 0) return;
        if (!('IntersectionObserver' in window)) {
            // Fallback: carga todas las páginas de golpe en navegadores
            // viejos. Raro hoy, pero evita dejar la lista coja.
            sentineles.forEach(function (s) {
                s.setAttribute('data-fnh-observado', '1');
                var step = function () {
                    cargarSiguientePagina(s);
                    if (!s.classList.contains('fnh-infinite-sentinel--done')) {
                        window.setTimeout(step, 400);
                    }
                };
                step();
            });
            return;
        }
        var observador = new IntersectionObserver(function (entradas) {
            entradas.forEach(function (entrada) {
                if (entrada.isIntersecting) {
                    cargarSiguientePagina(entrada.target);
                }
            });
        }, { rootMargin: '400px 0px' });
        sentineles.forEach(function (s) {
            s.setAttribute('data-fnh-observado', '1');
            observador.observe(s);
        });
    }
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', inicializarSentineles);
    } else {
        inicializarSentineles();
    }
})();
JS;
        wp_register_script('flavor-news-hub-shortcodes', '', [], false, true);
        wp_enqueue_script('flavor-news-hub-shortcodes');
        wp_add_inline_script('flavor-news-hub-shortcodes', $js);
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
            'exclude_source_type' => 'video,youtube,peertube,podcast',
            'show_excerpt'   => 1,
            'show_media'     => 1,
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory', 'language'], ['noticias', 'colectivos', 'podcasts']);

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
                'terms'    => array_map('sanitize_title', explode(',', (string) $a['topic'])),
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
            $filtros = self::renderFiltrosPaginaAuto(self::paginaAutoActual(), ['topic', 'territory', 'language']);
            if (empty($idsSources)) {
                return self::envolverShortcode('feed', '<p class="fnh-empty">' . esc_html__('Sin titulares que mostrar.', 'flavor-news-hub') . '</p>', $filtros);
            }
            $query['meta_query'] = $query['meta_query'] ?? [];
            $query['meta_query'][] = [
                'key'     => '_fnh_source_id',
                'value'   => array_map('strval', $idsSources),
                'compare' => 'IN',
            ];
        }

        $consulta = new \WP_Query($query);
        $filtros = self::renderFiltrosPaginaAuto(self::paginaAutoActual(), ['topic', 'territory', 'language']);
        if (empty($consulta->posts)) {
            return self::envolverShortcode('feed', '<p class="fnh-empty">' . esc_html__('Sin titulares que mostrar.', 'flavor-news-hub') . '</p>', $filtros);
        }

        // Des-apelmazar medios: si un source acaba de publicar varias
        // piezas seguidas no queremos mostrarlas apiñadas. El hero
        // elige los 3 primeros tras el reorden, así que los destacados
        // tampoco salen siempre del mismo medio.
        $postsReordenados = InterleaveSources::aplicar($consulta->posts);

        $esPaginaNoticias = self::paginaAutoActual() === 'noticias';
        $temasDestacados = $esPaginaNoticias ? self::obtenerTemasDestacadosNoticias($postsReordenados, 4) : [];
        $postPrincipal = null;
        $postsSecundarios = [];
        $postsListado = $postsReordenados;
        if ($esPaginaNoticias && !empty($postsListado)) {
            $postPrincipal = array_shift($postsListado);
            $postsSecundarios = array_slice($postsListado, 0, 2);
            $postsListado = array_slice($postsReordenados, 3);
        }
        ob_start();
        if ($esPaginaNoticias) :
            $numeroDestacado = count($consulta->posts);
            $datosPrincipal = $postPrincipal instanceof \WP_Post ? ItemTransformer::transformar($postPrincipal) : [];
            $metaPrincipal = '';
            if ($datosPrincipal !== []) {
                $metaPrincipal = $datosPrincipal['source']['name'] ?? '';
                if (!empty($datosPrincipal['published_at'])) {
                    $fechaPrincipal = date_i18n(get_option('date_format', 'F j, Y'), strtotime($datosPrincipal['published_at']));
                    $metaPrincipal = trim($metaPrincipal . ($metaPrincipal !== '' ? ' · ' : '') . $fechaPrincipal);
                }
            }
            ?>
            <section class="fnh-feed-hero" aria-label="<?php esc_attr_e('Resumen de noticias', 'flavor-news-hub'); ?>">
                <div class="fnh-feed-hero-titular">
                    <span class="fnh-feed-hero-kicker"><?php esc_html_e('Noticias', 'flavor-news-hub'); ?></span>
                    <h2><?php esc_html_e('La actualidad del ecosistema alternativo, sin ruido y por orden cronológico.', 'flavor-news-hub'); ?></h2>
                    <?php if ($temasDestacados !== []) : ?>
                        <div class="fnh-feed-hero-temas" aria-label="<?php esc_attr_e('Temáticas destacadas', 'flavor-news-hub'); ?>">
                            <?php foreach ($temasDestacados as $tema) : ?>
                                <a class="fnh-feed-hero-tema" href="<?php echo esc_url((string) $tema['url']); ?>">
                                    <?php echo esc_html((string) $tema['nombre']); ?>
                                    <span><?php echo esc_html((string) $tema['cantidad']); ?></span>
                                </a>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                    <?php if ($datosPrincipal !== []) : ?>
                        <div class="fnh-feed-hero-mosaico">
                            <article class="fnh-feed-hero-principal<?php echo empty($datosPrincipal['media_url']) ? ' fnh-feed-hero-principal--sin-media' : ''; ?>">
                                <?php if (!empty($datosPrincipal['media_url'])) : ?>
                                    <a class="fnh-feed-hero-principal-media" href="<?php echo esc_url((string) ($datosPrincipal['original_url'] ?: $datosPrincipal['url'])); ?>" target="_blank" rel="noopener">
                                        <img src="<?php echo esc_url((string) $datosPrincipal['media_url']); ?>" alt="" loading="lazy" />
                                    </a>
                                <?php endif; ?>
                                <div class="fnh-feed-hero-principal-contenido">
                                    <div class="fnh-feed-hero-principal-badge"><?php esc_html_e('Portada', 'flavor-news-hub'); ?></div>
                                    <?php if ($metaPrincipal !== '') : ?>
                                        <div class="fnh-feed-hero-principal-meta"><?php echo esc_html($metaPrincipal); ?></div>
                                    <?php endif; ?>
                                    <h3>
                                        <a href="<?php echo esc_url((string) ($datosPrincipal['original_url'] ?: $datosPrincipal['url'])); ?>" target="_blank" rel="noopener">
                                            <?php echo esc_html((string) $datosPrincipal['title']); ?>
                                        </a>
                                    </h3>
                                    <?php if ((int) $a['show_excerpt'] === 1 && !empty($datosPrincipal['excerpt'])) : ?>
                                        <div class="fnh-feed-hero-principal-excerpt"><?php echo wp_kses_post((string) $datosPrincipal['excerpt']); ?></div>
                                    <?php endif; ?>
                                    <a class="fnh-feed-hero-principal-cta" href="<?php echo esc_url((string) ($datosPrincipal['original_url'] ?: $datosPrincipal['url'])); ?>" target="_blank" rel="noopener">
                                        <?php esc_html_e('Leer noticia', 'flavor-news-hub'); ?>
                                    </a>
                                </div>
                            </article>
                            <?php if ($postsSecundarios !== []) : ?>
                                <div class="fnh-feed-hero-secundarias">
                                    <?php foreach ($postsSecundarios as $postSecundario) : ?>
                                        <?php
                                        $datosSecundario = ItemTransformer::transformar($postSecundario);
                                        $urlSecundario = $datosSecundario['original_url'] ?: $datosSecundario['url'];
                                        $metaSecundario = $datosSecundario['source']['name'] ?? '';
                                        if (!empty($datosSecundario['published_at'])) {
                                            $fechaSecundaria = date_i18n(get_option('date_format', 'F j, Y'), strtotime($datosSecundario['published_at']));
                                            $metaSecundario = trim($metaSecundario . ($metaSecundario !== '' ? ' · ' : '') . $fechaSecundaria);
                                        }
                                        ?>
                                        <article class="fnh-feed-hero-secundaria<?php echo empty($datosSecundario['media_url']) ? ' fnh-feed-hero-secundaria--sin-media' : ''; ?>">
                                            <?php if (!empty($datosSecundario['media_url'])) : ?>
                                                <a class="fnh-feed-hero-secundaria-media" href="<?php echo esc_url((string) $urlSecundario); ?>" target="_blank" rel="noopener">
                                                    <img src="<?php echo esc_url((string) $datosSecundario['media_url']); ?>" alt="" loading="lazy" />
                                                </a>
                                            <?php endif; ?>
                                            <div class="fnh-feed-hero-secundaria-contenido">
                                                <?php if ($metaSecundario !== '') : ?>
                                                    <div class="fnh-feed-hero-secundaria-meta"><?php echo esc_html($metaSecundario); ?></div>
                                                <?php endif; ?>
                                                <h4><a href="<?php echo esc_url((string) $urlSecundario); ?>" target="_blank" rel="noopener"><?php echo esc_html((string) $datosSecundario['title']); ?></a></h4>
                                                <?php if ((int) $a['show_excerpt'] === 1 && !empty($datosSecundario['excerpt'])) : ?>
                                                    <div class="fnh-feed-hero-secundaria-excerpt"><?php echo wp_kses_post((string) $datosSecundario['excerpt']); ?></div>
                                                <?php endif; ?>
                                                <a class="fnh-feed-hero-secundaria-cta" href="<?php echo esc_url((string) $urlSecundario); ?>" target="_blank" rel="noopener">
                                                    <?php esc_html_e('Abrir', 'flavor-news-hub'); ?>
                                                </a>
                                            </div>
                                        </article>
                                    <?php endforeach; ?>
                                </div>
                            <?php endif; ?>
                        </div>
                    <?php endif; ?>
                </div>
                <div class="fnh-feed-hero-estadistica">
                    <div>
                        <div class="fnh-feed-hero-numero"><?php echo esc_html((string) $numeroDestacado); ?></div>
                        <div class="fnh-feed-hero-etiqueta"><?php esc_html_e('Entradas recientes cargadas', 'flavor-news-hub'); ?></div>
                    </div>
                </div>
            </section>
        <?php
        endif;
        if ($postsListado !== []) {
            printf(
                '<ul class="fnh-feed-lista%s">',
                $esPaginaNoticias ? ' fnh-feed-lista--noticias' : ''
            );
            foreach ($postsListado as $indice => $post) {
                echo self::renderFeedItemHtml(
                    $post,
                    $esPaginaNoticias,
                    $indice === 0,
                    (int) $a['show_media'] === 1,
                    (int) $a['show_excerpt'] === 1
                );
            }
            echo '</ul>';
        }
        echo self::renderSentinelScrollInfinito(
            $esPaginaNoticias ? 'noticias' : (self::paginaAutoActual() === 'podcasts' ? 'podcasts' : 'feed'),
            (int) $a['limit'],
            $consulta->max_num_pages,
            [
                'topic'               => (string) $a['topic'],
                'territory'           => (string) $a['territory'],
                'language'            => (string) $a['language'],
                'source_type'         => (string) $a['source_type'],
                'exclude_source_type' => (string) $a['exclude_source_type'],
                'show_excerpt'        => (int) $a['show_excerpt'],
                'show_media'          => (int) $a['show_media'],
            ]
        );
        return self::envolverShortcode('feed', (string) ob_get_clean(), $filtros);
    }

    /**
     * [flavor_news_radios limit="20" territory="euskal herria" language="eu"]
     */
    public static function renderRadios($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'limit'     => 50,
            'topic'     => '',
            'territory' => '',
            'language'  => '',
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory', 'language'], ['radios']);

        $query = [
            'post_type'      => Radio::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => (int) $a['limit'],
            'orderby'        => 'title',
            'order'          => 'ASC',
            'meta_query'     => [
                'relation' => 'AND',
                [
                    'relation' => 'OR',
                    ['key' => '_fnh_active', 'value' => '1', 'compare' => '='],
                    ['key' => '_fnh_active', 'compare' => 'NOT EXISTS'],
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
        if ($a['territory'] !== '') {
            $query['meta_query'][] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field((string) $a['territory']),
                'compare' => 'LIKE',
            ];
        }
        if ($a['language'] !== '') {
            $queryIdiomas = self::construirMetaQueryIdiomas((string) $a['language']);
            if ($queryIdiomas !== []) {
                $query['meta_query'][] = $queryIdiomas;
            }
        }
        $consulta = new \WP_Query($query);
        $filtros = self::renderFiltrosPaginaAuto('radios', ['topic', 'territory', 'language']);
        if (empty($consulta->posts)) {
            return self::envolverShortcode('radios', '<p class="fnh-empty">' . esc_html__('No hay radios activas.', 'flavor-news-hub') . '</p>', $filtros);
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
        return self::envolverShortcode('radios', (string) ob_get_clean(), $filtros);
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
            'territory' => '',
            'language' => '',
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory', 'language'], ['videos']);

        $idsSourcesVideo = self::resolverIdsSources((string) $a['territory'], (string) $a['language'], 'youtube,video,peertube', '');
        $filtros = self::renderFiltrosPaginaAuto('videos', ['topic', 'territory', 'language']);
        if (empty($idsSourcesVideo)) {
            return self::envolverShortcode('videos', '<p class="fnh-empty">' . esc_html__('Sin canales de vídeo configurados.', 'flavor-news-hub') . '</p>', $filtros);
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
            return self::envolverShortcode('videos', '<p class="fnh-empty">' . esc_html__('Sin vídeos que mostrar.', 'flavor-news-hub') . '</p>', $filtros);
        }
        $postsReordenados = InterleaveSources::aplicar($consulta->posts);
        ob_start();
        echo '<div class="fnh-videos-grid">';
        foreach ($postsReordenados as $post) {
            echo self::renderVideoCardHtml($post);
        }
        echo '</div>';
        echo self::renderSentinelScrollInfinito(
            'videos',
            (int) $a['limit'],
            $consulta->max_num_pages,
            [
                'topic'     => (string) $a['topic'],
                'territory' => (string) $a['territory'],
                'language'  => (string) $a['language'],
            ]
        );
        return self::envolverShortcode('videos', (string) ob_get_clean(), $filtros);
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
        $permalinkFuente = get_permalink(self::traducirPostId((int) $post->ID));
        echo self::renderBotonesCompartir(is_string($permalinkFuente) ? $permalinkFuente : '', (string) get_the_title($post));
        echo '</section>';
        return self::envolverShortcode('source', (string) ob_get_clean());
    }

    /**
     * Resuelve IDs de sources con los mismos filtros que usa el endpoint
     * REST — evita duplicar lógica. Devuelve la intersección de todos los
     * criterios que lleguen no vacíos.
     *
     * @return list<int>
     */
    public static function resolverIdsSources(
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
            $queryIdiomas = self::construirMetaQueryIdiomas($idioma);
            if ($queryIdiomas !== []) {
                $metaQuery[] = $queryIdiomas;
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
        $noticiasPortada = self::obtenerItemsRecientes(5);
        $urlNoticias = self::urlPaginaAuto('noticias');
        $urlVideos = self::urlPaginaAuto('videos');
        $urlRadios = self::urlPaginaAuto('radios');

        ob_start();
        ?><div id="fnh-landing" class="fnh-landing not-prose">
            <!-- HERO con gradiente oscuro -->
            <section class="fnh-hero">
                <div class="fnh-hero-inner">
                    <h1><?php esc_html_e('Flavor News Hub', 'flavor-news-hub'); ?></h1>
                    <p class="fnh-lema"><?php esc_html_e('Medios alternativos y colectivos organizados. Informarte y actuar, en un solo sitio.', 'flavor-news-hub'); ?></p>
                    <div class="fnh-hero-ctas">
                        <?php if ($urlNoticias !== '') : ?>
                            <a class="fnh-btn fnh-btn-primary" href="<?php echo esc_url($urlNoticias); ?>">
                                <?php esc_html_e('Explora noticias', 'flavor-news-hub'); ?>
                            </a>
                        <?php endif; ?>
                        <a class="fnh-btn fnh-btn-ghost" href="#fnh-descarga">
                            <?php esc_html_e('Descargar app', 'flavor-news-hub'); ?>
                        </a>
                    </div>
                </div>
            </section>

            <!-- PORTADA EDITORIAL: 1 noticia destacada + 4 mini -->
            <?php if (!empty($noticiasPortada)) : ?>
            <section class="fnh-bloque fnh-portada">
                <h2 class="fnh-seccion-titulo"><span class="fnh-seccion-ico" aria-hidden="true">📰</span><?php esc_html_e('Actualidad', 'flavor-news-hub'); ?></h2>
                <div class="fnh-portada-grid">
                    <?php foreach ($noticiasPortada as $idx => $noticia) :
                        $claseCard = $idx === 0
                            ? 'fnh-portada-card fnh-portada-destacada'
                            : 'fnh-portada-card fnh-portada-mini';
                    ?>
                        <a class="<?php echo esc_attr($claseCard); ?>" href="<?php echo esc_url($noticia['url']); ?>" target="_blank" rel="noopener">
                            <?php if ($noticia['image'] !== '') : ?>
                                <div class="fnh-portada-imagen">
                                    <img src="<?php echo esc_url($noticia['image']); ?>" alt="" loading="lazy" />
                                </div>
                            <?php endif; ?>
                            <div class="fnh-portada-texto">
                                <?php if ($noticia['source_name'] !== '') : ?>
                                    <span class="fnh-portada-fuente"><?php echo esc_html($noticia['source_name']); ?></span>
                                <?php endif; ?>
                                <h3 class="fnh-portada-titulo"><?php echo esc_html($noticia['title']); ?></h3>
                            </div>
                        </a>
                    <?php endforeach; ?>
                </div>
                <?php if ($urlNoticias !== '') : ?>
                    <p class="fnh-ver-mas"><a href="<?php echo esc_url($urlNoticias); ?>"><?php esc_html_e('Todas las noticias', 'flavor-news-hub'); ?> →</a></p>
                <?php endif; ?>
            </section>
            <?php endif; ?>

            <!-- VÍDEOS (fondo alternado) -->
            <section class="fnh-bloque fnh-bloque-alt">
                <h2 class="fnh-seccion-titulo"><span class="fnh-seccion-ico" aria-hidden="true">🎬</span><?php esc_html_e('Últimos vídeos', 'flavor-news-hub'); ?></h2>
                <?php echo self::renderVideos(['limit' => 4]); ?>
                <?php if ($urlVideos !== '') : ?>
                    <p class="fnh-ver-mas"><a href="<?php echo esc_url($urlVideos); ?>"><?php esc_html_e('Ver todos', 'flavor-news-hub'); ?> →</a></p>
                <?php endif; ?>
            </section>

            <!-- SONANDO AHORA: radios + podcasts -->
            <section class="fnh-bloque">
                <h2 class="fnh-seccion-titulo"><span class="fnh-seccion-ico" aria-hidden="true">🎧</span><?php esc_html_e('Escucha en directo', 'flavor-news-hub'); ?></h2>
                <div class="fnh-sonando-cols">
                    <div class="fnh-sonando-col">
                        <h3 class="fnh-subseccion"><?php esc_html_e('Radios libres', 'flavor-news-hub'); ?></h3>
                        <?php echo self::renderRadios(['limit' => 4]); ?>
                    </div>
                    <div class="fnh-sonando-col">
                        <h3 class="fnh-subseccion"><?php esc_html_e('Podcasts recientes', 'flavor-news-hub'); ?></h3>
                        <?php echo self::renderFeed([
                            'limit'               => 5,
                            'show_excerpt'        => 0,
                            'show_media'          => 0,
                            'source_type'         => 'podcast',
                            'exclude_source_type' => '',
                        ]); ?>
                    </div>
                </div>
                <?php if ($urlRadios !== '') : ?>
                    <p class="fnh-ver-mas"><a href="<?php echo esc_url($urlRadios); ?>"><?php esc_html_e('Ver todo', 'flavor-news-hub'); ?> →</a></p>
                <?php endif; ?>
            </section>

            <!-- VÍDEO DESTACADO (ancho completo, fondo alternado) -->
            <?php if ($videoDestacado !== null) :
                $embed = self::peertubeEmbedUrl($videoDestacado['url']);
            ?>
            <section class="fnh-bloque fnh-bloque-alt fnh-destacado">
                <h2 class="fnh-seccion-titulo"><span class="fnh-seccion-ico" aria-hidden="true">✨</span><?php esc_html_e('Vídeo destacado', 'flavor-news-hub'); ?></h2>
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

            <!-- CTA DESCARGA APP -->
            <section class="fnh-descarga" id="fnh-descarga">
                <div class="fnh-descarga-inner">
                    <h2 class="fnh-descarga-titulo"><?php esc_html_e('Llévatela contigo', 'flavor-news-hub'); ?></h2>
                    <p class="fnh-descarga-copy"><?php esc_html_e('Lee, escucha y mantente conectado sin salir de la app. Android, código abierto, sin anuncios.', 'flavor-news-hub'); ?></p>
                    <a class="fnh-boton-descarga"
                       href="<?php echo esc_url($urlDescarga); ?>"
                       <?php echo str_ends_with($urlDescarga, '.apk') ? 'download' : 'target="_blank" rel="noopener"'; ?>>
                        <span class="fnh-boton-descarga-ico" aria-hidden="true">▶</span>
                        <?php esc_html_e('Descargar APK', 'flavor-news-hub'); ?>
                    </a>
                    <?php if ($version !== '') : ?>
                        <div class="fnh-version"><?php
                            echo esc_html(sprintf(
                                /* translators: %s: número de versión publicado */
                                __('Versión %s', 'flavor-news-hub'),
                                $version
                            ));
                        ?></div>
                    <?php endif; ?>
                </div>
            </section>

            <!-- APOYO AL PROYECTO: botón abre el modal unificado
                 de donaciones (Ko-fi, PayPal, Bitcoin, compartir),
                 mismo contenido que el sheet de la app móvil. -->
            <section class="fnh-apoyo">
                <div class="fnh-apoyo-inner">
                    <h2 class="fnh-apoyo-titulo">♥ <?php esc_html_e('Apoya el proyecto', 'flavor-news-hub'); ?></h2>
                    <p class="fnh-apoyo-copy"><?php esc_html_e('Sin publicidad, sin tracking, sin fondos opacos. Si lo que hacemos te sirve y puedes, una donación ayuda a mantenerlo y crecer.', 'flavor-news-hub'); ?></p>
                    <button type="button" class="fnh-boton-apoyo" data-fnh-open-dona>
                        ♥ <?php esc_html_e('Apoyar el proyecto', 'flavor-news-hub'); ?>
                    </button>
                </div>
            </section>

            <!-- FIRMA -->
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
     * Devuelve los N items más recientes como arrays listos para
     * renderizar en la portada editorial. Distinto de renderFeed
     * porque necesitamos control granular del markup (card destacada
     * vs mini).
     *
     * @return list<array{title:string,url:string,image:string,source_name:string,published_at:string}>
     */
    private static function obtenerItemsRecientes(int $cuantos): array
    {
        $consulta = new \WP_Query([
            'post_type'      => Item::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => $cuantos,
            'orderby'        => 'meta_value',
            'meta_key'       => '_fnh_published_at',
            'order'          => 'DESC',
            'no_found_rows'  => true,
        ]);
        $resultado = [];
        foreach ($consulta->posts as $post) {
            $idSource = (int) get_post_meta($post->ID, '_fnh_source_id', true);
            $sourceName = $idSource > 0 ? (string) get_the_title($idSource) : '';
            $resultado[] = [
                'title'        => (string) get_the_title($post),
                'url'          => (string) get_post_meta($post->ID, '_fnh_original_url', true),
                'image'        => (string) get_post_meta($post->ID, '_fnh_media_url', true),
                'source_name'  => $sourceName,
                'published_at' => (string) get_post_meta($post->ID, '_fnh_published_at', true),
            ];
        }
        return $resultado;
    }

    /**
     * URL pública de una página auto-generada por clave, o cadena vacía.
     */
    private static function urlPaginaAuto(string $clave): string
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
        $postId = self::traducirPostId((int) $consulta->posts[0]->ID);
        return (string) get_permalink($postId);
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
        $url = (string) get_permalink(self::traducirPostId((int) $consulta->posts[0]->ID));
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

    /**
     * Página TV: grid de canales (sources con medium_type=tv_station o
     * feed_type en [youtube,video,peertube] como fallback para fuentes
     * preexistentes sin medium_type migrado).
     */
    public static function renderTv($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'topic' => '',
            'territory' => '',
            'language' => '',
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory', 'language'], ['tv']);

        $consulta = new \WP_Query([
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => 100,
            'no_found_rows'  => true,
            'meta_query'     => [
                ['key' => '_fnh_active', 'value' => '1'],
            ],
        ]);
        $idsFiltrados = [];
        if ($a['territory'] !== '' || $a['language'] !== '') {
            $idsFiltrados = self::resolverIdsSources((string) $a['territory'], (string) $a['language'], '', '');
        }
        $tvStations = [];
        foreach ($consulta->posts as $post) {
            if (!empty($idsFiltrados) && !in_array((int) $post->ID, $idsFiltrados, true)) {
                continue;
            }
            if ($a['topic'] !== '' && !has_term(
                array_map('sanitize_title', explode(',', (string) $a['topic'])),
                Topic::SLUG,
                $post
            )) {
                continue;
            }
            $medio = (string) get_post_meta($post->ID, '_fnh_medium_type', true);
            $tipo  = (string) get_post_meta($post->ID, '_fnh_feed_type', true);
            $esTv  = $medio === 'tv_station'
                  || in_array($tipo, ['youtube', 'video', 'peertube'], true);
            if ($esTv) $tvStations[] = $post;
        }
        $filtros = self::renderFiltrosPaginaAuto('tv', ['topic', 'territory', 'language']);
        if (empty($tvStations)) {
            return self::envolverShortcode('tv', '<p class="fnh-vacio">' . esc_html__('Todavía no hay canales de TV en el catálogo.', 'flavor-news-hub') . '</p>', $filtros);
        }
        ob_start();
        ?><div class="fnh-tv-grid"><?php
        foreach ($tvStations as $post) {
            $territ = (string) get_post_meta($post->ID, '_fnh_territory', true);
            $licencia = (string) get_post_meta($post->ID, '_fnh_content_license', true);
            $idiomas = get_post_meta($post->ID, '_fnh_languages', true);
            if (!is_array($idiomas)) $idiomas = [];
            printf(
                '<a class="fnh-tv-card" href="%s"><div class="fnh-tv-card-cuerpo"><h3>%s</h3>%s%s%s</div></a>',
                esc_url((string) get_permalink(self::traducirPostId((int) $post->ID))),
                esc_html((string) get_the_title($post)),
                $territ !== '' ? '<span class="fnh-tv-terr">' . esc_html($territ) . '</span>' : '',
                !empty($idiomas) ? '<span class="fnh-tv-idiomas">' . esc_html(implode(', ', array_map('strval', $idiomas))) . '</span>' : '',
                strpos($licencia, 'cc-') === 0 ? '<span class="fnh-tv-cc">CC</span>' : ''
            );
        }
        ?></div><?php
        return self::envolverShortcode('tv', (string) ob_get_clean(), $filtros);
    }

    /**
     * Página Podcasts: delega a renderFeed con filtro por
     * feed_type=podcast y sin exclusión, para que los episodios
     * aparezcan aunque el feed general los excluya de titulares.
     */
    public static function renderPodcasts($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts(['limit' => 30], $atribs);
        return self::renderFeed([
            'limit'               => (int) $a['limit'],
            'show_excerpt'        => 1,
            'show_media'          => 1,
            'source_type'         => 'podcast',
            'exclude_source_type' => '',
        ]);
    }

    /**
     * Página Fuentes: directorio de todas las fuentes activas con
     * ficha editorial mínima. Ordenadas por nombre alfabético.
     */
    public static function renderSources($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'territory' => '',
            'language' => '',
            'topic' => '',
            'source_type' => '',
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory', 'language', 'source_type'], ['fuentes']);

        $metaQuery = [
            ['key' => '_fnh_active', 'value' => '1'],
        ];
        if ($a['territory'] !== '') {
            $metaQuery[] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field((string) $a['territory']),
                'compare' => 'LIKE',
            ];
        }
        if ($a['language'] !== '') {
            $queryIdiomas = self::construirMetaQueryIdiomas((string) $a['language']);
            if ($queryIdiomas !== []) {
                $metaQuery[] = $queryIdiomas;
            }
        }
        if ($a['source_type'] !== '') {
            $metaQuery[] = [
                'key'     => '_fnh_feed_type',
                'value'   => sanitize_key((string) $a['source_type']),
                'compare' => '=',
            ];
        }

        $query = [
            'post_type'      => Source::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => 200,
            'orderby'        => 'title',
            'order'          => 'ASC',
            'no_found_rows'  => true,
            'meta_query'     => $metaQuery,
        ];
        if ($a['topic'] !== '') {
            $query['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', explode(',', (string) $a['topic'])),
            ]];
        }
        $consulta = new \WP_Query($query);
        $filtros = self::renderFiltrosPaginaAuto('fuentes', ['topic', 'territory', 'language', 'source_type']);
        if (empty($consulta->posts)) {
            return self::envolverShortcode('sources', '<p class="fnh-vacio">' . esc_html__('Todavía no hay fuentes en el catálogo.', 'flavor-news-hub') . '</p>', $filtros);
        }
        // Agrupar por territorio para dar estructura.
        $porTerritorio = [];
        foreach ($consulta->posts as $post) {
            $t = (string) get_post_meta($post->ID, '_fnh_territory', true);
            $t = $t === '' ? __('Sin territorio', 'flavor-news-hub') : $t;
            $porTerritorio[$t] ??= [];
            $porTerritorio[$t][] = $post;
        }
        ksort($porTerritorio);
        ob_start();
        ?><div class="fnh-sources-directorio"><?php
        foreach ($porTerritorio as $terr => $posts) {
            printf('<h3 class="fnh-sources-territorio">%s <span class="fnh-sources-total">(%d)</span></h3>', esc_html($terr), count($posts));
            echo '<ul class="fnh-sources-lista">';
            foreach ($posts as $post) {
                $idiomas = get_post_meta($post->ID, '_fnh_languages', true);
                if (!is_array($idiomas)) $idiomas = [];
                $tipo = (string) get_post_meta($post->ID, '_fnh_feed_type', true);
                printf(
                    '<li class="fnh-source-item"><a href="%s"><span class="fnh-source-nombre">%s</span>%s%s</a></li>',
                    esc_url((string) get_permalink(self::traducirPostId((int) $post->ID))),
                    esc_html((string) get_the_title($post)),
                    !empty($idiomas) ? '<span class="fnh-source-idiomas">' . esc_html(implode(', ', array_map('strval', $idiomas))) . '</span>' : '',
                    $tipo !== '' ? '<span class="fnh-source-tipo">' . esc_html($tipo) . '</span>' : ''
                );
            }
            echo '</ul>';
        }
        ?></div><?php
        return self::envolverShortcode('sources', (string) ob_get_clean(), $filtros);
    }

    /**
     * Página Colectivos: directorio de colectivos organizados (`fnh_collective`)
     * agrupados por territorio. Sólo se muestran los publicados (status
     * `publish`) — los pending de la cola de envíos públicos quedan fuera
     * hasta que admin los verifique.
     *
     * [flavor_news_collectives territory="" topic=""]
     */
    public static function renderCollectives($atribs = [], $contenido = null): string
    {
        $a = shortcode_atts([
            'territory' => '',
            'topic'     => '',
        ], $atribs);
        $a = self::aplicarFiltrosRequest($a, ['topic', 'territory'], ['colectivos']);

        $metaQuery = [];
        if ($a['territory'] !== '') {
            $metaQuery[] = [
                'key'     => '_fnh_territory',
                'value'   => sanitize_text_field((string) $a['territory']),
                'compare' => 'LIKE',
            ];
        }

        $query = [
            'post_type'      => Collective::SLUG,
            'post_status'    => 'publish',
            'posts_per_page' => 200,
            'orderby'        => 'title',
            'order'          => 'ASC',
            'no_found_rows'  => true,
        ];
        if ($metaQuery !== []) {
            $query['meta_query'] = $metaQuery;
        }
        if ($a['topic'] !== '') {
            $query['tax_query'] = [[
                'taxonomy' => Topic::SLUG,
                'field'    => 'slug',
                'terms'    => array_map('sanitize_title', explode(',', (string) $a['topic'])),
            ]];
        }
        $consulta = new \WP_Query($query);
        $filtros = self::renderFiltrosPaginaAuto('colectivos', ['topic', 'territory']);
        if (empty($consulta->posts)) {
            return self::envolverShortcode('collectives', '<p class="fnh-vacio">' . esc_html__('Todavía no hay colectivos publicados en el directorio.', 'flavor-news-hub') . '</p>', $filtros);
        }

        $porTerritorio = [];
        foreach ($consulta->posts as $post) {
            $terr = (string) get_post_meta($post->ID, '_fnh_territory', true);
            $terr = $terr === '' ? __('Sin territorio', 'flavor-news-hub') : $terr;
            $porTerritorio[$terr] ??= [];
            $porTerritorio[$terr][] = $post;
        }
        ksort($porTerritorio);

        ob_start();
        ?><div class="fnh-collectives-directorio"><?php
        foreach ($porTerritorio as $terr => $posts) {
            printf(
                '<h3 class="fnh-collectives-territorio">%s <span class="fnh-collectives-total">(%d)</span></h3>',
                esc_html($terr),
                count($posts)
            );
            echo '<ul class="fnh-collectives-lista">';
            foreach ($posts as $post) {
                $idPost = (int) $post->ID;
                $web = (string) get_post_meta($idPost, '_fnh_website_url', true);
                $flavorUrl = (string) get_post_meta($idPost, '_fnh_flavor_url', true);
                $enlacePrincipal = $flavorUrl !== '' ? $flavorUrl : ($web !== '' ? $web : (string) get_permalink(self::traducirPostId($idPost)));
                $topics = wp_get_post_terms($idPost, Topic::SLUG, ['fields' => 'names']);
                if (is_wp_error($topics)) $topics = [];
                $topicsLimitados = array_slice(is_array($topics) ? $topics : [], 0, 4);
                $esExterno = $enlacePrincipal !== '' && $enlacePrincipal !== (string) get_permalink(self::traducirPostId($idPost));
                printf(
                    '<li class="fnh-collective-item"><a href="%s"%s><span class="fnh-collective-nombre">%s</span>%s%s</a></li>',
                    esc_url($enlacePrincipal),
                    $esExterno ? ' target="_blank" rel="noopener"' : '',
                    esc_html((string) get_the_title($post)),
                    $topicsLimitados !== []
                        ? '<span class="fnh-collective-topics">' . esc_html(implode(' · ', $topicsLimitados)) . '</span>'
                        : '',
                    $web !== '' && $flavorUrl === ''
                        ? '<span class="fnh-collective-web">' . esc_html(preg_replace('#^https?://(www\.)?#', '', $web) ?? $web) . '</span>'
                        : ''
                );
            }
            echo '</ul>';
        }
        ?></div><?php
        return self::envolverShortcode('collectives', (string) ob_get_clean(), $filtros);
    }

    /**
     * Página Sobre: presentación del proyecto con los principios
     * irrenunciables del manifiesto. Texto estático, editable desde
     * WP admin si hace falta retoque puntual.
     */
    public static function renderSobre($atribs = [], $contenido = null): string
    {
        ob_start();
        ?><div class="fnh-sobre">
            <section class="fnh-sobre-hero">
                <h2><?php esc_html_e('Puerta de entrada común', 'flavor-news-hub'); ?></h2>
                <p><?php esc_html_e('Flavor News Hub es un agregador de medios alternativos y un directorio de colectivos organizados. Dos cosas que suelen vivir en pestañas distintas del navegador y que aquí conviven en la misma app: informarte y actuar.', 'flavor-news-hub'); ?></p>
            </section>

            <section class="fnh-sobre-bloque">
                <h3><?php esc_html_e('Principios irrenunciables', 'flavor-news-hub'); ?></h3>
                <ol class="fnh-sobre-principios">
                    <li><strong><?php esc_html_e('Sin algoritmo de engagement.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('El orden es cronológico. Nunca un feed optimizado para que te quedes más.', 'flavor-news-hub'); ?></li>
                    <li><strong><?php esc_html_e('Sin tracking, sin publicidad, sin telemetría.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('Ni propia ni de terceros. Ni Analytics, ni Crashlytics, ni píxeles.', 'flavor-news-hub'); ?></li>
                    <li><strong><?php esc_html_e('Sin dark patterns.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('La app debería poder no abrirse en una semana y seguir siendo útil cuando vuelvas.', 'flavor-news-hub'); ?></li>
                    <li><strong><?php esc_html_e('Transparencia editorial.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('Cada medio expone quién lo posee, cómo se financia y qué línea editorial declara.', 'flavor-news-hub'); ?></li>
                    <li><strong><?php esc_html_e('Apropiabilidad.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('AGPL-3.0. Cualquier colectivo puede autohospedar su instancia sin pedir permiso.', 'flavor-news-hub'); ?></li>
                    <li><strong><?php esc_html_e('Multilingüe desde el día 1.', 'flavor-news-hub'); ?></strong> <?php esc_html_e('Castellano, catalán, euskera y gallego como idiomas de primera clase. Inglés como cuarto.', 'flavor-news-hub'); ?></li>
                </ol>
            </section>

            <section class="fnh-sobre-bloque">
                <h3><?php esc_html_e('Qué no es', 'flavor-news-hub'); ?></h3>
                <ul class="fnh-sobre-lista-plana">
                    <li><?php esc_html_e('Una red social. No hay perfiles, ni likes, ni comentarios.', 'flavor-news-hub'); ?></li>
                    <li><?php esc_html_e('Un negocio publicitario. No hay anuncios, ni hoy ni nunca.', 'flavor-news-hub'); ?></li>
                    <li><?php esc_html_e('Un monopolio. Cualquiera puede hacer fork y montar su propia instancia.', 'flavor-news-hub'); ?></li>
                </ul>
            </section>

            <section class="fnh-sobre-bloque">
                <h3><?php esc_html_e('Cómo colaborar', 'flavor-news-hub'); ?></h3>
                <p><?php esc_html_e('El código es libre y está en GitHub. Cualquier aportación —proponer nuevas fuentes, reportar bugs, traducir, documentar— se hace desde allí.', 'flavor-news-hub'); ?></p>
                <p><a class="fnh-sobre-cta" href="https://github.com/JosuIru/flavor-news-hub" target="_blank" rel="noopener"><?php esc_html_e('Repositorio en GitHub', 'flavor-news-hub'); ?> →</a></p>
            </section>
        </div><?php
        return self::envolverShortcode('sobre', (string) ob_get_clean());
    }
}
