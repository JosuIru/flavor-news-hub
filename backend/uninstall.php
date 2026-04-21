<?php
/**
 * Hook de desinstalación.
 *
 * Respeta el flag `delete_on_uninstall` de la opción `fnh_settings`:
 *  - false (default): no borra nada. El usuario puede reinstalar el plugin
 *    y recuperar todos sus medios, colectivos y log de ingesta.
 *  - true: borra CPTs, términos de la taxonomía, tabla propia y el option.
 *
 * @package FlavorNewsHub
 */

declare(strict_types=1);

if (!defined('WP_UNINSTALL_PLUGIN')) {
    exit;
}

$ajustesPlugin = get_option('fnh_settings', []);
if (!is_array($ajustesPlugin) || empty($ajustesPlugin['delete_on_uninstall'])) {
    return;
}

global $wpdb;

// Borrar todos los posts de los 3 CPTs.
foreach (['fnh_source', 'fnh_item', 'fnh_collective'] as $tipoPost) {
    $idsPosts = get_posts([
        'post_type'      => $tipoPost,
        'post_status'    => 'any',
        'numberposts'    => -1,
        'fields'         => 'ids',
        'suppress_filters' => true,
    ]);
    foreach ($idsPosts as $idPost) {
        wp_delete_post((int) $idPost, true);
    }
}

// Borrar términos de la taxonomía.
$terminos = get_terms([
    'taxonomy'   => 'fnh_topic',
    'hide_empty' => false,
]);
if (!is_wp_error($terminos)) {
    foreach ($terminos as $termino) {
        wp_delete_term($termino->term_id, 'fnh_topic');
    }
}

// Borrar tabla propia de logs.
$nombreTablaLog = $wpdb->prefix . 'fnh_ingest_log';
$wpdb->query("DROP TABLE IF EXISTS {$nombreTablaLog}");

// Borrar option de ajustes.
delete_option('fnh_settings');

// Limpiar transients del rate limiter (por si quedan sin expirar).
$patronTransient = $wpdb->esc_like('_transient_fnh_rl_') . '%';
$wpdb->query($wpdb->prepare(
    "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s",
    $patronTransient
));
$patronTransientTimeout = $wpdb->esc_like('_transient_timeout_fnh_rl_') . '%';
$wpdb->query($wpdb->prepare(
    "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s",
    $patronTransientTimeout
));
