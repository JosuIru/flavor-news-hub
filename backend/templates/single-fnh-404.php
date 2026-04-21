<?php
/**
 * Plantilla 404 propia del plugin. Se incluye desde TemplateRouter cuando
 * el recurso existe en BD pero no debe mostrarse públicamente (p. ej. un
 * colectivo aún no verificado).
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}

$tituloPagina = __('No encontrado', 'flavor-news-hub');
$descripcionPagina = '';
$urlCanonica = home_url();
$urlImagenOpenGraph = '';

require FNH_PLUGIN_DIR . 'templates/partials/head.php';
?>

<article>
    <h1>404 — <?php esc_html_e('No encontrado', 'flavor-news-hub'); ?></h1>
    <p><?php esc_html_e('El recurso que buscas no existe o ya no está disponible.', 'flavor-news-hub'); ?></p>
    <p class="cta">
        <a class="btn btn-secundario" href="<?php echo esc_url(home_url('/')); ?>">
            <?php esc_html_e('Volver al inicio', 'flavor-news-hub'); ?>
        </a>
    </p>
</article>

<?php require FNH_PLUGIN_DIR . 'templates/partials/foot.php'; ?>
