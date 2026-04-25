<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\MetaBoxes;

use FlavorNewsHub\CPT\Source;

/**
 * Metabox de edición para el CPT `fnh_source`.
 *
 * Expone los meta fields editables (feed_url, feed_type, website_url,
 * languages, territory, ownership, editorial_note, active) más un botón
 * "Ingest now" que redirige a `admin-post.php` con nonce propio.
 */
final class SourceMetaBox
{
    public const ID_METABOX_DATOS = 'fnh_source_datos';
    public const ID_METABOX_INGESTA = 'fnh_source_ingesta';
    public const NONCE_NAME = 'fnh_source_metabox_nonce';
    public const NONCE_ACTION = 'fnh_source_metabox_save';

    /** Tipos de feed soportados por la ingesta (coherente con MetaRegistrar). */
    public const TIPOS_FEED_DISPONIBLES = [
        'rss'             => 'RSS',
        'atom'            => 'Atom',
        'youtube'         => 'YouTube',
        'video'           => 'Vídeo (PeerTube/MP4/HLS)',
        'mastodon'        => 'Mastodon',
        'podcast'         => 'Podcast',
        'flavor_platform' => 'Flavor Platform',
    ];

    public static function registrar(): void
    {
        add_meta_box(
            self::ID_METABOX_DATOS,
            __('Datos editoriales y feed', 'flavor-news-hub'),
            [self::class, 'renderDatos'],
            Source::SLUG,
            'normal',
            'high'
        );

        add_meta_box(
            self::ID_METABOX_INGESTA,
            __('Ingesta manual', 'flavor-news-hub'),
            [self::class, 'renderIngesta'],
            Source::SLUG,
            'side',
            'default'
        );
    }

    public static function renderDatos(\WP_Post $post): void
    {
        wp_nonce_field(self::NONCE_ACTION, self::NONCE_NAME);

        $urlFeed = (string) get_post_meta($post->ID, '_fnh_feed_url', true);
        $tipoFeed = (string) get_post_meta($post->ID, '_fnh_feed_type', true) ?: 'rss';
        $urlSitio = (string) get_post_meta($post->ID, '_fnh_website_url', true);
        $idiomas = get_post_meta($post->ID, '_fnh_languages', true);
        if (!is_array($idiomas)) {
            $idiomas = [];
        }
        $territorio = (string) get_post_meta($post->ID, '_fnh_territory', true);
        $propiedad = (string) get_post_meta($post->ID, '_fnh_ownership', true);
        $lineaEditorial = (string) get_post_meta($post->ID, '_fnh_editorial_note', true);
        $activo = (bool) get_post_meta($post->ID, '_fnh_active', true);

        ?>
        <table class="form-table">
            <tr>
                <th><label for="fnh_feed_url"><?php esc_html_e('URL del feed', 'flavor-news-hub'); ?></label></th>
                <td><input type="url" id="fnh_feed_url" name="fnh_feed_url" value="<?php echo esc_attr($urlFeed); ?>" class="large-text" required /></td>
            </tr>
            <tr>
                <th><label for="fnh_feed_type"><?php esc_html_e('Tipo de feed', 'flavor-news-hub'); ?></label></th>
                <td>
                    <select id="fnh_feed_type" name="fnh_feed_type">
                        <?php foreach (self::TIPOS_FEED_DISPONIBLES as $valor => $etiqueta) : ?>
                            <option value="<?php echo esc_attr($valor); ?>" <?php selected($tipoFeed, $valor); ?>>
                                <?php echo esc_html($etiqueta); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_website_url"><?php esc_html_e('Web del medio', 'flavor-news-hub'); ?></label></th>
                <td><input type="url" id="fnh_website_url" name="fnh_website_url" value="<?php echo esc_attr($urlSitio); ?>" class="large-text" /></td>
            </tr>
            <tr>
                <th><label for="fnh_languages"><?php esc_html_e('Idiomas', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="text" id="fnh_languages" name="fnh_languages" value="<?php echo esc_attr(implode(', ', array_map('strval', $idiomas))); ?>" class="regular-text" />
                    <p class="description"><?php esc_html_e('Códigos ISO 639-1 separados por coma. Ej: es, ca, eu, gl.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_territory"><?php esc_html_e('Territorio', 'flavor-news-hub'); ?></label></th>
                <td><input type="text" id="fnh_territory" name="fnh_territory" value="<?php echo esc_attr($territorio); ?>" class="regular-text" /></td>
            </tr>
            <tr>
                <th><label for="fnh_ownership"><?php esc_html_e('Propiedad y financiación', 'flavor-news-hub'); ?></label></th>
                <td>
                    <textarea id="fnh_ownership" name="fnh_ownership" rows="3" class="large-text"><?php echo esc_textarea($propiedad); ?></textarea>
                    <p class="description"><?php esc_html_e('Quién posee el medio y cómo se financia. Admite HTML básico.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_editorial_note"><?php esc_html_e('Línea editorial', 'flavor-news-hub'); ?></label></th>
                <td>
                    <textarea id="fnh_editorial_note" name="fnh_editorial_note" rows="3" class="large-text"><?php echo esc_textarea($lineaEditorial); ?></textarea>
                </td>
            </tr>
            <tr>
                <th><?php esc_html_e('Estado', 'flavor-news-hub'); ?></th>
                <td>
                    <label>
                        <input type="checkbox" name="fnh_active" value="1" <?php checked($activo, true); ?> />
                        <?php esc_html_e('Activo (se ingesta automáticamente)', 'flavor-news-hub'); ?>
                    </label>
                </td>
            </tr>
        </table>
        <?php
    }

    public static function renderIngesta(\WP_Post $post): void
    {
        if ($post->post_status === 'auto-draft') {
            echo '<p>' . esc_html__('Guarda el medio primero para poder lanzar una ingesta manual.', 'flavor-news-hub') . '</p>';
            return;
        }

        $urlAccion = admin_url('admin-post.php');
        $nonceCampoHidden = wp_create_nonce('fnh_ingest_source_' . $post->ID);
        ?>
        <form method="post" action="<?php echo esc_url($urlAccion); ?>">
            <input type="hidden" name="action" value="fnh_ingest_source" />
            <input type="hidden" name="source_id" value="<?php echo (int) $post->ID; ?>" />
            <input type="hidden" name="_wpnonce" value="<?php echo esc_attr($nonceCampoHidden); ?>" />
            <p>
                <button type="submit" class="button button-primary">
                    <?php esc_html_e('Ingest now', 'flavor-news-hub'); ?>
                </button>
            </p>
            <p class="description">
                <?php esc_html_e('Dispara una ingesta inmediata de este medio. El cron sigue activo al margen.', 'flavor-news-hub'); ?>
            </p>
        </form>
        <?php
    }

    /**
     * Hook `save_post_fnh_source`: persiste los meta fields editables.
     */
    public static function guardar(int $idPost, \WP_Post $post): void
    {
        // Ignorar autosaves y revisiones.
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }
        if ($post->post_type !== Source::SLUG) {
            return;
        }
        if (!current_user_can('edit_post', $idPost)) {
            return;
        }
        if (!isset($_POST[self::NONCE_NAME]) || !wp_verify_nonce((string) wp_unslash($_POST[self::NONCE_NAME]), self::NONCE_ACTION)) {
            return;
        }

        $urlFeed = isset($_POST['fnh_feed_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_feed_url'])) : '';
        $tipoFeed = isset($_POST['fnh_feed_type']) ? sanitize_key((string) wp_unslash($_POST['fnh_feed_type'])) : 'rss';
        if (!array_key_exists($tipoFeed, self::TIPOS_FEED_DISPONIBLES)) {
            $tipoFeed = 'rss';
        }
        $urlSitio = isset($_POST['fnh_website_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_website_url'])) : '';
        $cadenaIdiomas = isset($_POST['fnh_languages']) ? sanitize_text_field((string) wp_unslash($_POST['fnh_languages'])) : '';
        $listaIdiomas = array_values(array_filter(array_map(
            static fn(string $pieza): string => sanitize_key(trim($pieza)),
            explode(',', $cadenaIdiomas)
        )));
        $territorio = isset($_POST['fnh_territory']) ? sanitize_text_field((string) wp_unslash($_POST['fnh_territory'])) : '';
        $propiedad = isset($_POST['fnh_ownership']) ? wp_kses_post((string) wp_unslash($_POST['fnh_ownership'])) : '';
        $lineaEditorial = isset($_POST['fnh_editorial_note']) ? wp_kses_post((string) wp_unslash($_POST['fnh_editorial_note'])) : '';
        $activo = !empty($_POST['fnh_active']);

        update_post_meta($idPost, '_fnh_feed_url', $urlFeed);
        update_post_meta($idPost, '_fnh_feed_type', $tipoFeed);
        update_post_meta($idPost, '_fnh_website_url', $urlSitio);
        update_post_meta($idPost, '_fnh_languages', $listaIdiomas);
        update_post_meta($idPost, '_fnh_territory', $territorio);
        update_post_meta($idPost, '_fnh_ownership', $propiedad);
        update_post_meta($idPost, '_fnh_editorial_note', $lineaEditorial);
        update_post_meta($idPost, '_fnh_active', $activo);
    }
}
