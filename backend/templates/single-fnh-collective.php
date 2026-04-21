<?php
/**
 * Plantilla pública de un colectivo (CPT `fnh_collective`), servida en
 * `/c/{slug}/` sólo si está `publish` y `_fnh_verified=true`.
 *
 * Política: el email de contacto es un registro interno (admin/auditoría)
 * y NO se expone en la web pública. El contacto público va siempre por la
 * web del colectivo o por su instancia Flavor (si la tiene).
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}

use FlavorNewsHub\Taxonomy\Topic;

$postColectivo = get_queried_object();
if (!$postColectivo instanceof WP_Post) {
    status_header(404);
    nocache_headers();
    require FNH_PLUGIN_DIR . 'templates/partials/head.php';
    echo '<article><h1>' . esc_html__('No encontrado', 'flavor-news-hub') . '</h1></article>';
    require FNH_PLUGIN_DIR . 'templates/partials/foot.php';
    return;
}
$idColectivo = (int) $postColectivo->ID;

$urlWebColectivo = (string) get_post_meta($idColectivo, '_fnh_website_url', true);
$urlFlavorColectivo = (string) get_post_meta($idColectivo, '_fnh_flavor_url', true);
$territorioColectivo = (string) get_post_meta($idColectivo, '_fnh_territory', true);

$terminosColectivo = wp_get_object_terms($idColectivo, Topic::SLUG);
if (is_wp_error($terminosColectivo)) {
    $terminosColectivo = [];
}

$tituloPagina = get_the_title($postColectivo);
$descripcionPagina = wp_trim_words(wp_strip_all_tags((string) $postColectivo->post_content), 30, '…');
$urlCanonica = get_permalink($postColectivo);
$urlImagenOpenGraph = '';

require FNH_PLUGIN_DIR . 'templates/partials/head.php';
?>

<article class="collective-page">
    <header>
        <h1><?php echo esc_html($tituloPagina); ?></h1>
        <?php if ($territorioColectivo !== '') : ?>
            <p class="meta"><?php echo esc_html($territorioColectivo); ?></p>
        <?php endif; ?>

        <?php if (!empty($terminosColectivo)) : ?>
            <ul class="topics" aria-label="<?php esc_attr_e('Temáticas', 'flavor-news-hub'); ?>">
                <?php foreach ($terminosColectivo as $termino) : ?>
                    <li><a href="<?php echo esc_url(get_term_link($termino)); ?>"><?php echo esc_html($termino->name); ?></a></li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </header>

    <?php if (trim((string) $postColectivo->post_content) !== '') : ?>
        <div class="excerpt">
            <?php echo apply_filters('the_content', $postColectivo->post_content); ?>
        </div>
    <?php endif; ?>

    <div class="actions-row">
        <?php if ($urlWebColectivo !== '') : ?>
            <a class="btn btn-secundario" href="<?php echo esc_url($urlWebColectivo); ?>" rel="noopener" target="_blank">
                <?php esc_html_e('Visitar web', 'flavor-news-hub'); ?> →
            </a>
        <?php endif; ?>
        <?php if ($urlFlavorColectivo !== '') : ?>
            <a class="btn" href="<?php echo esc_url($urlFlavorColectivo); ?>" rel="noopener" target="_blank">
                <?php esc_html_e('Comunidad en Flavor', 'flavor-news-hub'); ?> →
            </a>
        <?php endif; ?>
    </div>
</article>

<?php require FNH_PLUGIN_DIR . 'templates/partials/foot.php'; ?>
