<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\MetaBoxes;

use FlavorNewsHub\CPT\Collective;

/**
 * Metabox de edición para el CPT `fnh_collective`.
 *
 * Distingue entre los datos públicos (website, territorio, URL Flavor) y
 * los internos (email de contacto, verified, email del remitente de un
 * alta pública). Los internos nunca se exponen en la API pública.
 */
final class CollectiveMetaBox
{
    public const ID_METABOX = 'fnh_collective_datos';
    public const NONCE_NAME = 'fnh_collective_metabox_nonce';
    public const NONCE_ACTION = 'fnh_collective_metabox_save';

    public static function registrar(): void
    {
        add_meta_box(
            self::ID_METABOX,
            __('Datos del colectivo', 'flavor-news-hub'),
            [self::class, 'render'],
            Collective::SLUG,
            'normal',
            'high'
        );
    }

    public static function render(\WP_Post $post): void
    {
        wp_nonce_field(self::NONCE_ACTION, self::NONCE_NAME);

        $urlWeb = (string) get_post_meta($post->ID, '_fnh_website_url', true);
        $emailContacto = (string) get_post_meta($post->ID, '_fnh_contact_email', true);
        $territorio = (string) get_post_meta($post->ID, '_fnh_territory', true);
        $urlFlavor = (string) get_post_meta($post->ID, '_fnh_flavor_url', true);
        $verificado = (bool) get_post_meta($post->ID, '_fnh_verified', true);
        $emailRemitente = (string) get_post_meta($post->ID, '_fnh_submitted_by_email', true);

        ?>
        <table class="form-table">
            <tr>
                <th><label for="fnh_website_url"><?php esc_html_e('Web', 'flavor-news-hub'); ?></label></th>
                <td><input type="url" id="fnh_website_url" name="fnh_website_url" value="<?php echo esc_attr($urlWeb); ?>" class="large-text" /></td>
            </tr>
            <tr>
                <th><label for="fnh_contact_email"><?php esc_html_e('Email de contacto (interno)', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="email" id="fnh_contact_email" name="fnh_contact_email" value="<?php echo esc_attr($emailContacto); ?>" class="regular-text" />
                    <p class="description"><?php esc_html_e('Nunca se expone en la API pública.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_territory"><?php esc_html_e('Territorio', 'flavor-news-hub'); ?></label></th>
                <td><input type="text" id="fnh_territory" name="fnh_territory" value="<?php echo esc_attr($territorio); ?>" class="regular-text" /></td>
            </tr>
            <tr>
                <th><label for="fnh_flavor_url"><?php esc_html_e('URL Flavor (opcional)', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="url" id="fnh_flavor_url" name="fnh_flavor_url" value="<?php echo esc_attr($urlFlavor); ?>" class="large-text" />
                    <p class="description"><?php esc_html_e('Enlace a la instancia Flavor del colectivo, si la tienen.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><?php esc_html_e('Verificado', 'flavor-news-hub'); ?></th>
                <td>
                    <label>
                        <input type="checkbox" name="fnh_verified" value="1" <?php checked($verificado, true); ?> />
                        <?php esc_html_e('Sí, el colectivo ha sido verificado y puede aparecer en el directorio público.', 'flavor-news-hub'); ?>
                    </label>
                </td>
            </tr>
            <?php if ($emailRemitente !== '') : ?>
                <tr>
                    <th><?php esc_html_e('Email del remitente (alta pública)', 'flavor-news-hub'); ?></th>
                    <td>
                        <code><?php echo esc_html($emailRemitente); ?></code>
                        <p class="description"><?php esc_html_e('Registro interno de auditoría. No editable.', 'flavor-news-hub'); ?></p>
                    </td>
                </tr>
            <?php endif; ?>
        </table>
        <?php
    }

    public static function guardar(int $idPost, \WP_Post $post): void
    {
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }
        if ($post->post_type !== Collective::SLUG) {
            return;
        }
        if (!current_user_can('edit_post', $idPost)) {
            return;
        }
        if (!isset($_POST[self::NONCE_NAME]) || !wp_verify_nonce((string) wp_unslash($_POST[self::NONCE_NAME]), self::NONCE_ACTION)) {
            return;
        }

        $urlWeb = isset($_POST['fnh_website_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_website_url'])) : '';
        $emailContacto = isset($_POST['fnh_contact_email']) ? sanitize_email((string) wp_unslash($_POST['fnh_contact_email'])) : '';
        $territorio = isset($_POST['fnh_territory']) ? sanitize_text_field((string) wp_unslash($_POST['fnh_territory'])) : '';
        $urlFlavor = isset($_POST['fnh_flavor_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_flavor_url'])) : '';
        $verificado = !empty($_POST['fnh_verified']);

        update_post_meta($idPost, '_fnh_website_url', $urlWeb);
        update_post_meta($idPost, '_fnh_contact_email', $emailContacto);
        update_post_meta($idPost, '_fnh_territory', $territorio);
        update_post_meta($idPost, '_fnh_flavor_url', $urlFlavor);
        update_post_meta($idPost, '_fnh_verified', $verificado);
    }
}
