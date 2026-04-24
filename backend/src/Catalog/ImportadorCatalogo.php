<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\CPT\Collective;
use FlavorNewsHub\Taxonomy\Topic;
use FlavorNewsHub\Support\TerritoryNormalizer;

/**
 * Servicio de importación del catálogo curado. Lo invocan tanto la
 * pantalla admin (botones) como los comandos WP-CLI. La lógica de
 * crear/actualizar/saltar vive una sola vez aquí.
 *
 * Diseño:
 *  - Idempotente: match por slug. Si existe y no pediste `actualizar`,
 *    saltamos. Si pediste `actualizar`, sobreescribimos los metas pero
 *    respetamos flags del usuario (p. ej. `_fnh_active=false` manual).
 *  - Devuelve tupla [creados, actualizados, saltados] para que el caller
 *    decida cómo mostrarlo.
 *  - Topic se mapea por slug contra `fnh_topic` existente — no creamos
 *    términos nuevos, la taxonomía la pobla el activador del plugin.
 */
final class ImportadorCatalogo
{
    /**
     * @param list<array<string,mixed>> $datos
     * @param list<string>|null $slugsSeleccionados Si es null, importa todos.
     * @return array{creados:int,actualizados:int,saltados:int,errores:list<string>}
     */
    public static function importarSources(
        array $datos,
        bool $actualizar = false,
        ?array $slugsSeleccionados = null
    ): array {
        $creados = 0;
        $actualizados = 0;
        $saltados = 0;
        $errores = [];

        $filtroSlug = $slugsSeleccionados === null
            ? null
            : array_flip($slugsSeleccionados);

        foreach ($datos as $raw) {
            $slug = (string) ($raw['slug'] ?? '');
            $nombre = (string) ($raw['name'] ?? '');
            if ($slug === '' || $nombre === '') continue;
            if ($filtroSlug !== null && !isset($filtroSlug[$slug])) continue;

            $existente = get_page_by_path($slug, OBJECT, Source::SLUG);
            if ($existente && !$actualizar) {
                $saltados++;
                continue;
            }

            $idPost = $existente
                ? (int) $existente->ID
                : (int) wp_insert_post([
                    'post_type'   => Source::SLUG,
                    'post_status' => 'publish',
                    'post_title'  => $nombre,
                    'post_name'   => $slug,
                ], true);

            if (!$idPost) {
                $errores[] = "No se pudo crear '$slug'.";
                continue;
            }

            update_post_meta($idPost, '_fnh_feed_url', (string) ($raw['feed_url'] ?? ''));
            update_post_meta($idPost, '_fnh_feed_type', (string) ($raw['feed_type'] ?? 'rss'));
            update_post_meta($idPost, '_fnh_website_url', (string) ($raw['website_url'] ?? ''));
            $territorio = (string) ($raw['territory'] ?? '');
            update_post_meta($idPost, '_fnh_territory', $territorio);
            $ubicacion = TerritoryNormalizer::desglosar($territorio);
            update_post_meta($idPost, '_fnh_country', (string) ($raw['country'] ?? $ubicacion['country']));
            update_post_meta($idPost, '_fnh_region', (string) ($raw['region'] ?? $ubicacion['region']));
            update_post_meta($idPost, '_fnh_city', (string) ($raw['city'] ?? $ubicacion['city']));
            update_post_meta($idPost, '_fnh_network', (string) ($raw['network'] ?? $ubicacion['network']));
            $idiomas = $raw['languages'] ?? [];
            if (!is_array($idiomas)) $idiomas = [];
            update_post_meta(
                $idPost,
                '_fnh_languages',
                array_values(array_map('strval', $idiomas))
            );
            // Al importar ponemos activa por defecto — si el usuario
            // ya había desactivado una manualmente, sólo se sobreescribe
            // con `--actualizar`. Sin esa flag el `saltados` ya cortó.
            update_post_meta($idPost, '_fnh_active', true);

            // Campos opcionales introducidos con Vol. 3 (TV, PeerTube,
            // licencias). Sólo sobreescribimos si el seed los trae — así
            // no machacamos valores que un admin haya editado a mano en
            // fuentes ya presentes. El fallback sensato lo da el meta
            // registrar (medium_type=news, licencia vacía, sin stream).
            if (array_key_exists('medium_type', $raw)) {
                update_post_meta($idPost, '_fnh_medium_type', (string) $raw['medium_type']);
            }
            if (array_key_exists('broadcast_format', $raw)) {
                $formatos = $raw['broadcast_format'];
                if (!is_array($formatos)) $formatos = [];
                update_post_meta(
                    $idPost,
                    '_fnh_broadcast_format',
                    array_values(array_map('strval', $formatos))
                );
            }
            if (array_key_exists('content_license', $raw)) {
                update_post_meta($idPost, '_fnh_content_license', (string) $raw['content_license']);
            }
            if (array_key_exists('legal_note', $raw)) {
                update_post_meta($idPost, '_fnh_legal_note', (string) $raw['legal_note']);
            }
            if (array_key_exists('has_live_stream', $raw)) {
                update_post_meta($idPost, '_fnh_has_live_stream', (bool) $raw['has_live_stream']);
            }
            if (array_key_exists('live_stream_permit', $raw)) {
                update_post_meta($idPost, '_fnh_live_stream_permit', (string) $raw['live_stream_permit']);
            }

            self::asignarTopics($idPost, $raw['topics'] ?? []);

            if ($existente) {
                $actualizados++;
            } else {
                $creados++;
            }
        }

        return [
            'creados' => $creados,
            'actualizados' => $actualizados,
            'saltados' => $saltados,
            'errores' => $errores,
        ];
    }

    /**
     * @param list<array<string,mixed>> $datos
     * @param list<string>|null $slugsSeleccionados
     * @return array{creados:int,actualizados:int,saltados:int,errores:list<string>}
     */
    public static function importarRadios(
        array $datos,
        bool $actualizar = false,
        ?array $slugsSeleccionados = null
    ): array {
        $creados = 0;
        $actualizados = 0;
        $saltados = 0;
        $errores = [];

        $filtroSlug = $slugsSeleccionados === null
            ? null
            : array_flip($slugsSeleccionados);

        foreach ($datos as $raw) {
            $slug = (string) ($raw['slug'] ?? '');
            $nombre = (string) ($raw['name'] ?? '');
            $streamUrl = (string) ($raw['stream_url'] ?? '');
            if ($slug === '' || $nombre === '' || $streamUrl === '') {
                // Las radios sin stream no se reproducen; mejor no
                // crearlas como radios — pertenecen a `sources` con
                // feed_type=podcast.
                continue;
            }
            if ($filtroSlug !== null && !isset($filtroSlug[$slug])) continue;

            $existente = get_page_by_path($slug, OBJECT, Radio::SLUG);
            if ($existente && !$actualizar) {
                $saltados++;
                continue;
            }

            $idPost = $existente
                ? (int) $existente->ID
                : (int) wp_insert_post([
                    'post_type'   => Radio::SLUG,
                    'post_status' => 'publish',
                    'post_title'  => $nombre,
                    'post_name'   => $slug,
                ], true);

            if (!$idPost) {
                $errores[] = "No se pudo crear la radio '$slug'.";
                continue;
            }

            update_post_meta($idPost, '_fnh_stream_url', $streamUrl);
            update_post_meta($idPost, '_fnh_website_url', (string) ($raw['website_url'] ?? ''));
            update_post_meta($idPost, '_fnh_rss_url', (string) ($raw['rss_url'] ?? ''));
            $territorio = (string) ($raw['territory'] ?? '');
            update_post_meta($idPost, '_fnh_territory', $territorio);
            $ubicacion = TerritoryNormalizer::desglosar($territorio);
            update_post_meta($idPost, '_fnh_country', (string) ($raw['country'] ?? $ubicacion['country']));
            update_post_meta($idPost, '_fnh_region', (string) ($raw['region'] ?? $ubicacion['region']));
            update_post_meta($idPost, '_fnh_city', (string) ($raw['city'] ?? $ubicacion['city']));
            $idiomas = $raw['languages'] ?? [];
            if (!is_array($idiomas)) $idiomas = [];
            update_post_meta(
                $idPost,
                '_fnh_languages',
                array_values(array_map('strval', $idiomas))
            );

            if ($existente) {
                $actualizados++;
            } else {
                $creados++;
            }
        }

        return [
            'creados' => $creados,
            'actualizados' => $actualizados,
            'saltados' => $saltados,
            'errores' => $errores,
        ];
    }

    /**
     * @param list<array<string,mixed>> $datos
     * @param list<string>|null $slugsSeleccionados
     * @return array{creados:int,actualizados:int,saltados:int,errores:list<string>}
     */
    public static function importarCollectives(
        array $datos,
        bool $actualizar = false,
        ?array $slugsSeleccionados = null
    ): array {
        $creados = 0;
        $actualizados = 0;
        $saltados = 0;
        $errores = [];

        $filtroSlug = $slugsSeleccionados === null
            ? null
            : array_flip($slugsSeleccionados);

        foreach ($datos as $raw) {
            $slug = (string) ($raw['slug'] ?? '');
            $nombre = (string) ($raw['name'] ?? '');
            if ($slug === '' || $nombre === '') continue;
            if ($filtroSlug !== null && !isset($filtroSlug[$slug])) continue;

            $existente = get_page_by_path($slug, OBJECT, Collective::SLUG);
            if ($existente && !$actualizar) {
                $saltados++;
                continue;
            }

            $descripcion = (string) ($raw['description'] ?? '');
            $verificado = $raw['verified'] !== false;
            $estado = $verificado ? 'publish' : 'pending';

            $idPost = $existente
                ? (int) $existente->ID
                : (int) wp_insert_post([
                    'post_type'    => Collective::SLUG,
                    'post_status'  => $estado,
                    'post_title'   => $nombre,
                    'post_name'    => $slug,
                    'post_content' => $descripcion,
                ], true);

            if (!$idPost) {
                $errores[] = "No se pudo crear '$slug'.";
                continue;
            }

            if ($existente) {
                wp_update_post([
                    'ID'           => $idPost,
                    'post_status'  => $estado,
                    'post_title'   => $nombre,
                    'post_content' => $descripcion,
                ]);
            }

            update_post_meta($idPost, '_fnh_website_url', (string) ($raw['website_url'] ?? ''));
            update_post_meta($idPost, '_fnh_flavor_url', (string) ($raw['flavor_url'] ?? ''));
            $territorio = (string) ($raw['territory'] ?? '');
            update_post_meta($idPost, '_fnh_territory', $territorio);
            $ubicacion = TerritoryNormalizer::desglosar($territorio);
            update_post_meta($idPost, '_fnh_country', (string) ($raw['country'] ?? $ubicacion['country']));
            update_post_meta($idPost, '_fnh_region', (string) ($raw['region'] ?? $ubicacion['region']));
            update_post_meta($idPost, '_fnh_city', (string) ($raw['city'] ?? $ubicacion['city']));
            update_post_meta($idPost, '_fnh_verified', $verificado);

            // No inventamos emails: los seed bundleados suelen no traer
            // un contacto canónico. La API pública expondrá `has_contact`
            // como false hasta que el admin añada un email interno.
            if (!get_post_meta($idPost, '_fnh_contact_email', true)) {
                update_post_meta($idPost, '_fnh_contact_email', '');
            }

            self::asignarTopics($idPost, $raw['topics'] ?? []);

            if ($existente) {
                $actualizados++;
            } else {
                $creados++;
            }
        }

        return [
            'creados' => $creados,
            'actualizados' => $actualizados,
            'saltados' => $saltados,
            'errores' => $errores,
        ];
    }

    /**
     * Marca un post_id con los términos de topic correspondientes a la
     * lista de slugs. Slugs no existentes en `fnh_topic` se ignoran —
     * la taxonomía la pobla el activador del plugin con las
     * canónicas; añadir nuevas es decisión editorial del admin.
     */
    private static function asignarTopics(int $idPost, mixed $slugsRaw): void
    {
        if (!is_array($slugsRaw) || empty($slugsRaw)) return;
        $ids = [];
        foreach ($slugsRaw as $slug) {
            if (!is_string($slug) || $slug === '') continue;
            $term = get_term_by('slug', $slug, Topic::SLUG);
            if ($term instanceof \WP_Term) {
                $ids[] = (int) $term->term_id;
            }
        }
        if (!empty($ids)) {
            wp_set_object_terms($idPost, $ids, Topic::SLUG, false);
        }
    }
}
