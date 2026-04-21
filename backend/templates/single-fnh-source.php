<?php
/**
 * Plantilla pública de un medio (CPT `fnh_source`), servida en `/f/{slug}/`.
 *
 * Muestra la ficha editorial completa: propiedad/financiación, línea
 * editorial, territorio, idiomas y temáticas. Esa transparencia es parte
 * del contenido del proyecto, no un extra.
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}

use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\CPT\Item;

$postSource = get_queried_object();
if (!$postSource instanceof WP_Post) {
    status_header(404);
    nocache_headers();
    require FNH_PLUGIN_DIR . 'templates/partials/head.php';
    echo '<article><h1>' . esc_html__('No encontrado', 'flavor-news-hub') . '</h1></article>';
    require FNH_PLUGIN_DIR . 'templates/partials/foot.php';
    return;
}
$idSource = (int) $postSource->ID;

$urlSitioWebMedio = (string) get_post_meta($idSource, '_fnh_website_url', true);
$tipoFeed = (string) get_post_meta($idSource, '_fnh_feed_type', true) ?: 'rss';
$propiedadMedio = (string) get_post_meta($idSource, '_fnh_ownership', true);
$lineaEditorial = (string) get_post_meta($idSource, '_fnh_editorial_note', true);
$territorioMedio = (string) get_post_meta($idSource, '_fnh_territory', true);
$idiomasMedio = get_post_meta($idSource, '_fnh_languages', true);
if (!is_array($idiomasMedio)) {
    $idiomasMedio = [];
}

$terminosSource = wp_get_object_terms($idSource, Topic::SLUG);
if (is_wp_error($terminosSource)) {
    $terminosSource = [];
}

$urlListadoNoticiasDelMedio = add_query_arg(
    ['post_type' => Item::SLUG, 'source' => $idSource],
    home_url('/')
);

$tituloPagina = get_the_title($postSource);
$descripcionPagina = wp_trim_words(wp_strip_all_tags((string) $postSource->post_content), 30, '…');
$urlCanonica = get_permalink($postSource);
$urlImagenOpenGraph = '';

require FNH_PLUGIN_DIR . 'templates/partials/head.php';
?>

<article class="source-page">
    <header>
        <h1><?php echo esc_html($tituloPagina); ?></h1>
        <p class="meta">
            <?php
            $piezasMetaSource = array_filter([
                $territorioMedio,
                strtoupper($tipoFeed),
            ], static fn(string $p): bool => $p !== '');
            echo esc_html(implode(' · ', $piezasMetaSource));
            ?>
        </p>

        <?php if (!empty($terminosSource)) : ?>
            <ul class="topics" aria-label="<?php esc_attr_e('Temáticas', 'flavor-news-hub'); ?>">
                <?php foreach ($terminosSource as $termino) : ?>
                    <li><a href="<?php echo esc_url(get_term_link($termino)); ?>"><?php echo esc_html($termino->name); ?></a></li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </header>

    <?php if (trim((string) $postSource->post_content) !== '') : ?>
        <div class="excerpt">
            <?php echo apply_filters('the_content', $postSource->post_content); ?>
        </div>
    <?php endif; ?>

    <section class="ficha-source" aria-labelledby="titulo-ficha-editorial">
        <h2 id="titulo-ficha-editorial"><?php esc_html_e('Ficha editorial', 'flavor-news-hub'); ?></h2>
        <dl>
            <?php if ($urlSitioWebMedio !== '') : ?>
                <dt><?php esc_html_e('Web', 'flavor-news-hub'); ?></dt>
                <dd><a href="<?php echo esc_url($urlSitioWebMedio); ?>" rel="noopener" target="_blank"><?php echo esc_html($urlSitioWebMedio); ?></a></dd>
            <?php endif; ?>

            <?php if ($propiedadMedio !== '') : ?>
                <dt><?php esc_html_e('Propiedad y financiación', 'flavor-news-hub'); ?></dt>
                <dd><?php echo wp_kses_post($propiedadMedio); ?></dd>
            <?php endif; ?>

            <?php if ($lineaEditorial !== '') : ?>
                <dt><?php esc_html_e('Línea editorial declarada', 'flavor-news-hub'); ?></dt>
                <dd><?php echo wp_kses_post($lineaEditorial); ?></dd>
            <?php endif; ?>

            <?php if ($territorioMedio !== '') : ?>
                <dt><?php esc_html_e('Territorio', 'flavor-news-hub'); ?></dt>
                <dd><?php echo esc_html($territorioMedio); ?></dd>
            <?php endif; ?>

            <?php if (!empty($idiomasMedio)) : ?>
                <dt><?php esc_html_e('Idiomas', 'flavor-news-hub'); ?></dt>
                <dd><?php echo esc_html(implode(', ', array_map('strval', $idiomasMedio))); ?></dd>
            <?php endif; ?>
        </dl>
    </section>

    <p class="cta">
        <a class="btn btn-secundario" href="<?php echo esc_url($urlListadoNoticiasDelMedio); ?>">
            <?php esc_html_e('Ver noticias de este medio', 'flavor-news-hub'); ?> →
        </a>
    </p>
</article>

<?php require FNH_PLUGIN_DIR . 'templates/partials/foot.php'; ?>
