<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\MetaBoxes;

use FlavorNewsHub\CPT\Item;

/**
 * Metabox read-only para el CPT `fnh_item`.
 *
 * Los items son agregados automáticamente por la ingesta; no se editan a
 * mano. Este metabox existe sólo para inspeccionar el origen de cada
 * noticia desde el admin (source, URL original, guid, fecha de publicación).
 */
final class ItemMetaBox
{
    public const ID_METABOX = 'fnh_item_origen';

    public static function registrar(): void
    {
        add_meta_box(
            self::ID_METABOX,
            __('Origen de la noticia', 'flavor-news-hub'),
            [self::class, 'render'],
            Item::SLUG,
            'side',
            'default'
        );
    }

    public static function render(\WP_Post $post): void
    {
        $idSource = (int) get_post_meta($post->ID, '_fnh_source_id', true);
        $urlOriginal = (string) get_post_meta($post->ID, '_fnh_original_url', true);
        $fechaPublicacion = (string) get_post_meta($post->ID, '_fnh_published_at', true);
        $identificadorGuid = (string) get_post_meta($post->ID, '_fnh_guid', true);
        $urlImagen = (string) get_post_meta($post->ID, '_fnh_media_url', true);

        $tituloSource = $idSource > 0 ? get_the_title($idSource) : '';
        $urlEditSource = $idSource > 0 ? admin_url('post.php?action=edit&post=' . $idSource) : '';

        ?>
        <p>
            <strong><?php esc_html_e('Medio', 'flavor-news-hub'); ?>:</strong><br/>
            <?php if ($tituloSource && $urlEditSource) : ?>
                <a href="<?php echo esc_url($urlEditSource); ?>"><?php echo esc_html($tituloSource); ?></a>
            <?php else : ?>
                <em><?php esc_html_e('sin asignar', 'flavor-news-hub'); ?></em>
            <?php endif; ?>
        </p>
        <p>
            <strong><?php esc_html_e('URL original', 'flavor-news-hub'); ?>:</strong><br/>
            <?php if ($urlOriginal !== '') : ?>
                <a href="<?php echo esc_url($urlOriginal); ?>" target="_blank" rel="noopener noreferrer">
                    <?php echo esc_html($urlOriginal); ?>
                </a>
            <?php else : ?>
                —
            <?php endif; ?>
        </p>
        <p>
            <strong><?php esc_html_e('Fecha de publicación (ISO)', 'flavor-news-hub'); ?>:</strong><br/>
            <code><?php echo esc_html($fechaPublicacion !== '' ? $fechaPublicacion : '—'); ?></code>
        </p>
        <p>
            <strong><?php esc_html_e('GUID', 'flavor-news-hub'); ?>:</strong><br/>
            <code style="word-break:break-all;"><?php echo esc_html($identificadorGuid !== '' ? $identificadorGuid : '—'); ?></code>
        </p>
        <?php if ($urlImagen !== '') : ?>
            <p>
                <strong><?php esc_html_e('Imagen destacada (del feed)', 'flavor-news-hub'); ?>:</strong><br/>
                <img src="<?php echo esc_url($urlImagen); ?>" alt="" style="max-width:100%; height:auto; border:1px solid #ccd0d4; padding:2px;" />
            </p>
        <?php endif; ?>
        <?php
    }
}
