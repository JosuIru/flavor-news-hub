<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\MetaBoxes;

use FlavorNewsHub\CPT\Radio;

/**
 * Metabox de edición para el CPT `fnh_radio`.
 *
 * Hasta ahora las radios sólo se podían crear/editar vía seed JSON +
 * "Reimportar catálogo": al abrir una radio en WP Admin la pantalla
 * salía vacía (solo título + Gutenberg) sin acceso a `_fnh_stream_url`,
 * `_fnh_active`, etc. Este metabox cierra ese hueco.
 *
 * Expone los meta editables más frecuentes — los desglosados de
 * territorio (`country`/`region`/`city`) se calculan automáticamente
 * vía `TerritoryNormalizer` desde el campo libre `territory`, así no
 * forzamos al editor a rellenarlos a mano.
 */
final class RadioMetaBox
{
    public const ID_METABOX_DATOS = 'fnh_radio_datos';
    public const NONCE_NAME = 'fnh_radio_metabox_nonce';
    public const NONCE_ACTION = 'fnh_radio_metabox_save';

    public static function registrar(): void
    {
        add_meta_box(
            self::ID_METABOX_DATOS,
            __('Datos editoriales y stream', 'flavor-news-hub'),
            [self::class, 'renderDatos'],
            Radio::SLUG,
            'normal',
            'high'
        );
    }

    public static function renderDatos(\WP_Post $post): void
    {
        wp_nonce_field(self::NONCE_ACTION, self::NONCE_NAME);

        $urlStream = (string) get_post_meta($post->ID, '_fnh_stream_url', true);
        $urlSitio = (string) get_post_meta($post->ID, '_fnh_website_url', true);
        $urlRss = (string) get_post_meta($post->ID, '_fnh_rss_url', true);
        $idiomas = get_post_meta($post->ID, '_fnh_languages', true);
        if (!is_array($idiomas)) {
            $idiomas = [];
        }
        $territorio = (string) get_post_meta($post->ID, '_fnh_territory', true);
        $propiedad = (string) get_post_meta($post->ID, '_fnh_ownership', true);
        $activo = (bool) get_post_meta($post->ID, '_fnh_active', true);

        ?>
        <table class="form-table">
            <tr>
                <th><label for="fnh_stream_url"><?php esc_html_e('URL del stream en directo', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="url" id="fnh_stream_url" name="fnh_stream_url" value="<?php echo esc_attr($urlStream); ?>" class="large-text" required />
                    <p class="description"><?php esc_html_e('URL directa del Icecast/Shoutcast/HLS. Ej: https://giss.tv:666/RadioKras.mp3 o https://…/playlist.m3u8.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_website_url"><?php esc_html_e('Web de la emisora', 'flavor-news-hub'); ?></label></th>
                <td><input type="url" id="fnh_website_url" name="fnh_website_url" value="<?php echo esc_attr($urlSitio); ?>" class="large-text" /></td>
            </tr>
            <tr>
                <th><label for="fnh_rss_url"><?php esc_html_e('RSS de programas (opcional)', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="url" id="fnh_rss_url" name="fnh_rss_url" value="<?php echo esc_attr($urlRss); ?>" class="large-text" />
                    <p class="description"><?php esc_html_e('Si la emisora publica podcast/programas vía RSS, la app lo enseña como bottom sheet de "Programas".', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_languages"><?php esc_html_e('Idiomas', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="text" id="fnh_languages" name="fnh_languages" value="<?php echo esc_attr(implode(', ', array_map('strval', $idiomas))); ?>" class="regular-text" />
                    <p class="description"><?php esc_html_e('Códigos ISO 639-1 separados por coma. Ej: es, ca, eu, gl, fr, pt.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_territory"><?php esc_html_e('Territorio', 'flavor-news-hub'); ?></label></th>
                <td>
                    <input type="text" id="fnh_territory" name="fnh_territory" value="<?php echo esc_attr($territorio); ?>" class="regular-text" />
                    <p class="description"><?php esc_html_e('Texto libre legible (Bizkaia, Catalunya, Argentina, Wallmapu…). Los campos country/region/city se derivan automáticamente.', 'flavor-news-hub'); ?></p>
                </td>
            </tr>
            <tr>
                <th><label for="fnh_ownership"><?php esc_html_e('Propiedad y financiación', 'flavor-news-hub'); ?></label></th>
                <td>
                    <textarea id="fnh_ownership" name="fnh_ownership" rows="3" class="large-text"><?php echo esc_textarea($propiedad); ?></textarea>
                </td>
            </tr>
            <tr>
                <th><?php esc_html_e('Estado', 'flavor-news-hub'); ?></th>
                <td>
                    <label>
                        <input type="checkbox" name="fnh_active" value="1" <?php checked($activo, true); ?> />
                        <?php esc_html_e('Activa (aparece en el directorio público)', 'flavor-news-hub'); ?>
                    </label>
                </td>
            </tr>
        </table>
        <?php
    }

    /**
     * Hook `save_post_fnh_radio`: persiste los meta fields editables.
     * El desglose `country/region/city` se calcula al vuelo desde el
     * `territory` libre (mismo criterio que `ImportadorCatalogo`).
     */
    public static function guardar(int $idPost, \WP_Post $post): void
    {
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }
        if ($post->post_type !== Radio::SLUG) {
            return;
        }
        if (!current_user_can('edit_post', $idPost)) {
            return;
        }
        if (!isset($_POST[self::NONCE_NAME]) || !wp_verify_nonce((string) wp_unslash($_POST[self::NONCE_NAME]), self::NONCE_ACTION)) {
            return;
        }

        $urlStream = isset($_POST['fnh_stream_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_stream_url'])) : '';
        $urlSitio = isset($_POST['fnh_website_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_website_url'])) : '';
        $urlRss = isset($_POST['fnh_rss_url']) ? esc_url_raw((string) wp_unslash($_POST['fnh_rss_url'])) : '';
        $cadenaIdiomas = isset($_POST['fnh_languages']) ? sanitize_text_field((string) wp_unslash($_POST['fnh_languages'])) : '';
        $listaIdiomas = array_values(array_filter(array_map(
            static fn(string $pieza): string => sanitize_key(trim($pieza)),
            explode(',', $cadenaIdiomas)
        )));
        $territorio = isset($_POST['fnh_territory']) ? sanitize_text_field((string) wp_unslash($_POST['fnh_territory'])) : '';
        $propiedad = isset($_POST['fnh_ownership']) ? wp_kses_post((string) wp_unslash($_POST['fnh_ownership'])) : '';
        $activo = !empty($_POST['fnh_active']);

        update_post_meta($idPost, '_fnh_stream_url', $urlStream);
        update_post_meta($idPost, '_fnh_website_url', $urlSitio);
        update_post_meta($idPost, '_fnh_rss_url', $urlRss);
        update_post_meta($idPost, '_fnh_languages', $listaIdiomas);
        update_post_meta($idPost, '_fnh_territory', $territorio);
        update_post_meta($idPost, '_fnh_ownership', $propiedad);
        update_post_meta($idPost, '_fnh_active', $activo);

        // Recalcular country/region/city desde territory para mantener
        // coherencia con el flujo del importador. Si el admin quisiera
        // sobreescribir manualmente alguno de ellos, podemos añadir
        // campos dedicados más adelante; de momento el caso 99% es
        // "el normalizer hace su trabajo".
        $ubicacion = \FlavorNewsHub\Support\TerritoryNormalizer::desglosar($territorio);
        update_post_meta($idPost, '_fnh_country', $ubicacion['country']);
        update_post_meta($idPost, '_fnh_region', $ubicacion['region']);
        update_post_meta($idPost, '_fnh_city', $ubicacion['city']);
    }
}
