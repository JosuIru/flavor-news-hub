<?php
/**
 * Pie compartido: cierra <main>, imprime <footer> y cierra <body>/<html>.
 */

declare(strict_types=1);

if (!defined('ABSPATH')) {
    exit;
}
?>
    </main>

    <footer class="site-footer" role="contentinfo">
        <div class="site-footer-inner">
            <p>
                <?php
                printf(
                    /* translators: %s = nombre del sitio */
                    esc_html__('%s — herramienta de comunicación para la autoorganización social.', 'flavor-news-hub'),
                    esc_html(get_bloginfo('name'))
                );
                ?>
            </p>
            <p>
                <?php esc_html_e('Sin algoritmo de engagement. Sin tracking. Sin publicidad. AGPL-3.0.', 'flavor-news-hub'); ?>
            </p>
        </div>
    </footer>
    <?php
    /*
     * `wp_footer()` también se omite a propósito: mantiene la página sin
     * JS y sin enqueues del tema. Si en algún punto hiciera falta una
     * admin bar para usuarios logueados, se añade aquí con una condición
     * explícita (`is_admin_bar_showing()` + `wp_admin_bar_render`).
     */
    ?>
</body>
</html>
