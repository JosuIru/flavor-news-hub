<?php
/**
 * Plantilla pública de una noticia agregada (CPT `fnh_item`), servida en
 * `/n/{slug}/` como fallback web de los enlaces compartidos desde la app.
 *
 * Incluye el bloque "¿Quién se organiza sobre esto?" con los colectivos
 * publicados y verificados cuyas temáticas coinciden con las del item.
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}

use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\Taxonomy\Topic;

$postItem = get_queried_object();
if (!$postItem instanceof WP_Post) {
    status_header(404);
    nocache_headers();
    require FNH_PLUGIN_DIR . 'templates/partials/head.php';
    echo '<article><h1>' . esc_html__('No encontrado', 'flavor-news-hub') . '</h1></article>';
    require FNH_PLUGIN_DIR . 'templates/partials/foot.php';
    return;
}

$idItem = (int) $postItem->ID;

$idSourceAsociado = (int) get_post_meta($idItem, '_fnh_source_id', true);
$postSource = $idSourceAsociado > 0 ? get_post($idSourceAsociado) : null;
$nombreSource = $postSource instanceof WP_Post ? get_the_title($postSource) : __('medio desconocido', 'flavor-news-hub');
$urlSource = $postSource instanceof WP_Post ? get_permalink($postSource) : '';
$urlWebSource = $postSource instanceof WP_Post ? (string) get_post_meta($postSource->ID, '_fnh_website_url', true) : '';

$urlArticuloOriginal = (string) get_post_meta($idItem, '_fnh_original_url', true);
$fechaPublicacionIso = (string) get_post_meta($idItem, '_fnh_published_at', true);
$urlImagenDestacada = (string) get_post_meta($idItem, '_fnh_media_url', true);

$timestampPublicacion = $fechaPublicacionIso !== '' ? strtotime($fechaPublicacionIso) : false;
if ($timestampPublicacion === false) {
    $timestampPublicacion = (int) get_post_time('U', true, $postItem);
}

$terminosItem = wp_get_object_terms($idItem, Topic::SLUG);
if (is_wp_error($terminosItem)) {
    $terminosItem = [];
}
$idsTerminosItem = array_map(static fn(WP_Term $t): int => (int) $t->term_id, $terminosItem);

// Colectivos relacionados: publicados, verificados, que compartan cualquier topic.
$colectivosRelacionados = [];
if (!empty($idsTerminosItem)) {
    $consultaColectivos = new WP_Query([
        'post_type'      => Collective::SLUG,
        'post_status'    => 'publish',
        'posts_per_page' => 5,
        'no_found_rows'  => true,
        'orderby'        => 'title',
        'order'          => 'ASC',
        'meta_query'     => [
            ['key' => '_fnh_verified', 'value' => '1'],
        ],
        'tax_query'      => [[
            'taxonomy' => Topic::SLUG,
            'field'    => 'term_id',
            'terms'    => $idsTerminosItem,
        ]],
    ]);
    $colectivosRelacionados = $consultaColectivos->posts;
}

// Variables para partials/head.php.
$tituloPagina = get_the_title($postItem);
$descripcionPagina = wp_trim_words(wp_strip_all_tags((string) $postItem->post_content), 35, '…');
$urlCanonica = get_permalink($postItem);
$urlImagenOpenGraph = $urlImagenDestacada;

require FNH_PLUGIN_DIR . 'templates/partials/head.php';
?>

<article>
    <header>
        <h1><?php echo esc_html($tituloPagina); ?></h1>
        <p class="meta">
            <?php if ($urlSource !== '') : ?>
                <a href="<?php echo esc_url($urlSource); ?>"><?php echo esc_html($nombreSource); ?></a>
            <?php else : ?>
                <?php echo esc_html($nombreSource); ?>
            <?php endif; ?>
            <?php if ($timestampPublicacion > 0) : ?>
                <span class="sep">·</span>
                <time datetime="<?php echo esc_attr(gmdate('c', $timestampPublicacion)); ?>">
                    <?php echo esc_html(wp_date(get_option('date_format') . ' ' . get_option('time_format'), $timestampPublicacion)); ?>
                </time>
            <?php endif; ?>
        </p>

        <?php if (!empty($terminosItem)) : ?>
            <ul class="topics" aria-label="<?php esc_attr_e('Temáticas', 'flavor-news-hub'); ?>">
                <?php foreach ($terminosItem as $termino) : ?>
                    <li>
                        <a href="<?php echo esc_url(get_term_link($termino)); ?>">
                            <?php echo esc_html($termino->name); ?>
                        </a>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </header>

    <?php if ($urlImagenDestacada !== '') : ?>
        <p><img src="<?php echo esc_url($urlImagenDestacada); ?>" alt="" loading="lazy" /></p>
    <?php endif; ?>

    <div class="excerpt">
        <?php echo apply_filters('the_content', $postItem->post_content); ?>
    </div>

    <?php if ($urlArticuloOriginal !== '') : ?>
        <p class="cta">
            <a class="btn" href="<?php echo esc_url($urlArticuloOriginal); ?>" rel="noopener noreferrer" target="_blank">
                <?php
                printf(
                    /* translators: %s = nombre del medio */
                    esc_html__('Leer en %s', 'flavor-news-hub'),
                    esc_html($nombreSource)
                );
                ?> →
            </a>
        </p>
    <?php endif; ?>

    <section class="organizing" aria-labelledby="titulo-organizing">
        <h2 id="titulo-organizing"><?php esc_html_e('¿Quién se organiza sobre esto?', 'flavor-news-hub'); ?></h2>

        <?php if (empty($colectivosRelacionados)) : ?>
            <p class="vacio"><?php esc_html_e('Aún no hay colectivos verificados en este directorio para estas temáticas. Si tu colectivo encaja, puedes darlo de alta desde la app.', 'flavor-news-hub'); ?></p>
        <?php else : ?>
            <ul>
                <?php foreach ($colectivosRelacionados as $postColectivo) :
                    $territorioColectivo = (string) get_post_meta($postColectivo->ID, '_fnh_territory', true);
                    $terminosColectivo = wp_get_object_terms($postColectivo->ID, Topic::SLUG, ['fields' => 'names']);
                    if (is_wp_error($terminosColectivo)) {
                        $terminosColectivo = [];
                    }
                    ?>
                    <li>
                        <a href="<?php echo esc_url(get_permalink($postColectivo)); ?>">
                            <strong><?php echo esc_html(get_the_title($postColectivo)); ?></strong>
                            <small>
                                <?php
                                $piezasMeta = array_filter([
                                    $territorioColectivo,
                                    implode(' · ', array_map('strval', $terminosColectivo)),
                                ], static fn(string $p): bool => $p !== '');
                                echo esc_html(implode(' · ', $piezasMeta));
                                ?>
                            </small>
                        </a>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </section>
</article>

<?php require FNH_PLUGIN_DIR . 'templates/partials/foot.php'; ?>
