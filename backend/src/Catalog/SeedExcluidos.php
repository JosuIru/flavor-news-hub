<?php
declare(strict_types=1);

namespace FlavorNewsHub\Catalog;

use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Radio;
use FlavorNewsHub\CPT\Collective;

/**
 * Lista de slugs que NUNCA se deben recrear desde el seed bundleado.
 *
 * Caso de uso: el admin borra una source/radio/collective desde
 * wp-admin porque no la quiere en su instancia. Sin esta lista,
 * `ImportadorCatalogo::importarSources` la vuelve a crear en el
 * siguiente upgrade del plugin (porque el seed sigue trayéndola y
 * `get_page_by_path` no encuentra posts en papelera, así que parece
 * que el slug está libre y crea uno nuevo).
 *
 * Almacenado en la option `fnh_seed_excluidos` como array plano
 * `['slug-uno', 'slug-dos', ...]`.
 *
 * Auto-mantenida vía hooks `wp_trash_post` (añade) y `untrashed_post`
 * (quita), así el comportamiento "borrar desde admin = excluir del
 * seed" es transparente.
 */
final class SeedExcluidos
{
    private const OPCION = 'fnh_seed_excluidos';

    /** @return list<string> */
    public static function obtener(): array
    {
        $valor = get_option(self::OPCION, []);
        if (!is_array($valor)) {
            return [];
        }
        return array_values(array_filter(array_map('strval', $valor)));
    }

    public static function contiene(string $slug): bool
    {
        if ($slug === '') {
            return false;
        }
        return in_array($slug, self::obtener(), true);
    }

    public static function anadir(string $slug): void
    {
        if ($slug === '') {
            return;
        }
        $lista = self::obtener();
        if (in_array($slug, $lista, true)) {
            return;
        }
        $lista[] = $slug;
        update_option(self::OPCION, $lista, false);
    }

    public static function eliminar(string $slug): void
    {
        if ($slug === '') {
            return;
        }
        $lista = array_values(array_filter(
            self::obtener(),
            static fn(string $s): bool => $s !== $slug
        ));
        update_option(self::OPCION, $lista, false);
    }

    /**
     * Engancha los hooks de WordPress para mantener la lista al día.
     * Llamar desde `Plugin::arrancar`.
     */
    public static function registrarHooks(): void
    {
        add_action('wp_trash_post', [self::class, 'alTrashPost']);
        add_action('before_delete_post', [self::class, 'alTrashPost']);
        add_action('untrashed_post', [self::class, 'alUntrashPost']);
    }

    /** @internal */
    public static function alTrashPost(int $idPost): void
    {
        $post = get_post($idPost);
        if (!$post || !self::esTipoCatalogado($post->post_type)) {
            return;
        }
        // `post_name` es el slug "limpio" antes del sufijo `__trashed`
        // que añade WP en el momento exacto del cambio. Tomamos el que
        // viene del DB justo antes de la operación.
        $slug = (string) $post->post_name;
        // Si ya tiene sufijo __trashed (en before_delete_post tras un
        // trash previo), lo quitamos para guardar el slug original.
        if (preg_match('/^(.*)__trashed(?:-\d+)?$/', $slug, $m)) {
            $slug = $m[1];
        }
        self::anadir($slug);
    }

    /** @internal */
    public static function alUntrashPost(int $idPost): void
    {
        $post = get_post($idPost);
        if (!$post || !self::esTipoCatalogado($post->post_type)) {
            return;
        }
        self::eliminar((string) $post->post_name);
    }

    private static function esTipoCatalogado(string $tipoPost): bool
    {
        return $tipoPost === Source::SLUG
            || $tipoPost === Radio::SLUG
            || $tipoPost === Collective::SLUG;
    }
}
