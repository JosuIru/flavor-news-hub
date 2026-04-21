<?php
/**
 * Cabecera compartida de todas las plantillas públicas del plugin.
 *
 * Espera que la plantilla invocadora haya definido:
 *  - $tituloPagina       string — título <title> y og:title
 *  - $descripcionPagina  string — meta description y og:description
 *  - $urlCanonica        string — URL canónica (get_permalink() típicamente)
 *  - $urlImagenOpenGraph string — opcional; para og:image
 *
 * No depende del tema: imprime <!DOCTYPE>, <html>, <head> y abre <body>/<main>.
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}

$codigoIdiomaSitio = str_replace('_', '-', (string) get_bloginfo('language')) ?: 'es';
$nombreSitio = get_bloginfo('name');
$urlInicio = home_url('/');
$textoTituloEfectivo = $tituloPagina !== '' ? $tituloPagina . ' · ' . $nombreSitio : $nombreSitio;

?><!DOCTYPE html>
<html lang="<?php echo esc_attr($codigoIdiomaSitio); ?>">
<head>
    <meta charset="<?php echo esc_attr(get_bloginfo('charset')); ?>" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title><?php echo esc_html($textoTituloEfectivo); ?></title>
    <?php if ($descripcionPagina !== '') : ?>
        <meta name="description" content="<?php echo esc_attr($descripcionPagina); ?>" />
    <?php endif; ?>
    <link rel="canonical" href="<?php echo esc_url($urlCanonica); ?>" />

    <meta property="og:site_name" content="<?php echo esc_attr($nombreSitio); ?>" />
    <meta property="og:title" content="<?php echo esc_attr($tituloPagina); ?>" />
    <meta property="og:type" content="article" />
    <meta property="og:url" content="<?php echo esc_url($urlCanonica); ?>" />
    <?php if ($descripcionPagina !== '') : ?>
        <meta property="og:description" content="<?php echo esc_attr($descripcionPagina); ?>" />
    <?php endif; ?>
    <?php if ($urlImagenOpenGraph !== '') : ?>
        <meta property="og:image" content="<?php echo esc_url($urlImagenOpenGraph); ?>" />
    <?php endif; ?>
    <meta name="twitter:card" content="summary_large_image" />

    <meta name="robots" content="index, follow" />
    <?php wp_site_icon(); ?>

    <style><?php echo file_get_contents(FNH_PLUGIN_DIR . 'templates/partials/style.css'); ?></style>
    <?php
    /*
     * Omitimos `wp_head()` a propósito: el fallback web debe ser limpio,
     * sin los enqueues de CSS/JS del tema ni de otros plugins. Cualquier
     * meta relevante se imprime arriba a mano.
     */
    ?>
</head>
<body class="fnh-public">
    <a class="skip-link" href="#contenido-principal"><?php esc_html_e('Saltar al contenido', 'flavor-news-hub'); ?></a>

    <header class="site-header">
        <div class="site-header-inner">
            <p class="site-title">
                <a href="<?php echo esc_url($urlInicio); ?>"><?php echo esc_html($nombreSitio); ?></a>
            </p>
            <nav class="site-nav" aria-label="<?php esc_attr_e('Navegación principal', 'flavor-news-hub'); ?>">
                <a href="<?php echo esc_url($urlInicio); ?>"><?php esc_html_e('Inicio', 'flavor-news-hub'); ?></a>
            </nav>
        </div>
    </header>

    <main id="contenido-principal" tabindex="-1">
