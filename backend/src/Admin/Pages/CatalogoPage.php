<?php
declare(strict_types=1);

namespace FlavorNewsHub\Admin\Pages;

use FlavorNewsHub\Catalog\CatalogoPorDefecto;
use FlavorNewsHub\Catalog\ImportadorCatalogo;
use FlavorNewsHub\CPT\Source;
use FlavorNewsHub\CPT\Radio;

/**
 * Pantalla admin "Catálogo": lista el seed curado que viaja con el
 * plugin (el mismo catálogo que usa la app Flutter) y permite al admin
 * activar fuentes/radios con un clic. Cada entrada muestra su estado
 * (si ya existe como post o no) y se puede seleccionar por checkbox
 * para una importación parcial.
 *
 * Pensado para "ponerse en marcha rápido": tras instalar el plugin,
 * el admin entra aquí, marca los que le interesan y le da a importar.
 * El `FeedIngester` hará su trabajo periódico con esos.
 */
final class CatalogoPage
{
    public const SLUG = 'fnh-catalogo';
    public const NONCE_ACCION = 'fnh_catalogo_importar';

    public static function render(): void
    {
        if (!current_user_can('manage_options')) {
            wp_die(__('No tienes permisos para ver esta página.', 'flavor-news-hub'));
        }

        self::procesarAccionSiCorresponde();

        $tabActiva = isset($_GET['tab']) ? sanitize_key((string) $_GET['tab']) : 'sources';
        if (!in_array($tabActiva, ['sources', 'radios'], true)) {
            $tabActiva = 'sources';
        }

        echo '<div class="wrap">';
        echo '<h1>' . esc_html__('Catálogo por defecto', 'flavor-news-hub') . '</h1>';
        echo '<p class="description">' . esc_html__(
            'Este catálogo viaja con el plugin y es el mismo que usa la app. Marca los medios que quieras activar en tu instancia y pulsa "Importar seleccionados". Puedes re-importar más tarde para recibir cambios — sólo crea los nuevos.',
            'flavor-news-hub'
        ) . '</p>';

        // Tabs
        $urlBase = admin_url('admin.php?page=' . self::SLUG);
        echo '<h2 class="nav-tab-wrapper">';
        printf(
            '<a href="%s" class="nav-tab %s">%s</a>',
            esc_url(add_query_arg('tab', 'sources', $urlBase)),
            $tabActiva === 'sources' ? 'nav-tab-active' : '',
            esc_html__('Fuentes', 'flavor-news-hub')
        );
        printf(
            '<a href="%s" class="nav-tab %s">%s</a>',
            esc_url(add_query_arg('tab', 'radios', $urlBase)),
            $tabActiva === 'radios' ? 'nav-tab-active' : '',
            esc_html__('Radios', 'flavor-news-hub')
        );
        echo '</h2>';

        self::renderizarTab($tabActiva);

        echo '</div>';
    }

    private static function renderizarTab(string $tab): void
    {
        $datos = $tab === 'sources'
            ? CatalogoPorDefecto::sources()
            : CatalogoPorDefecto::radios();

        if (empty($datos)) {
            echo '<p>' . esc_html__('No hay entradas en el catálogo por defecto para esta pestaña.', 'flavor-news-hub') . '</p>';
            return;
        }

        $cptSlug = $tab === 'sources' ? Source::SLUG : Radio::SLUG;
        // Mapa slug → post_id para saber cuáles ya están importados.
        $slugsJson = array_map(
            static fn(array $x): string => (string) ($x['slug'] ?? ''),
            $datos
        );
        $existentesMapa = self::mapaExistentesPorSlug($cptSlug, $slugsJson);
        $instalados = self::valoresInstalados($existentesMapa);

        $totalJson = count($datos);
        $totalExistentes = count($existentesMapa);
        $totalPendientes = $totalJson - $totalExistentes;

        echo '<p>' . sprintf(
            esc_html__(
                'Catálogo: %1$d entradas. Ya instaladas: %2$d. Pendientes: %3$d.',
                'flavor-news-hub'
            ),
            $totalJson,
            $totalExistentes,
            $totalPendientes
        ) . '</p>';

        echo '<form method="post">';
        wp_nonce_field(self::NONCE_ACCION);
        echo '<input type="hidden" name="fnh_catalogo_tab" value="' . esc_attr($tab) . '" />';

        echo '<div style="margin: 12px 0;">';
        echo '<label><input type="checkbox" name="fnh_catalogo_actualizar" value="1" /> ';
        echo esc_html__(
            'Sobrescribir metas de los que ya existen (mantiene tus cambios si no marcas esto).',
            'flavor-news-hub'
        );
        echo '</label>';
        echo '<p class="description" style="margin-top:6px;">';
        echo esc_html__(
            'Marca la casilla de las entradas que quieras (re)importar y pulsa "Importar seleccionados". Para entradas ya instaladas necesitas también marcar "Sobrescribir metas" para que el seed pise sus valores actuales.',
            'flavor-news-hub'
        );
        echo '</p>';
        echo '</div>';

        echo '<p>';
        submit_button(
            __('Importar seleccionados', 'flavor-news-hub'),
            'primary',
            'fnh_catalogo_importar_seleccion',
            false
        );
        echo ' ';
        submit_button(
            __('Importar todos los pendientes', 'flavor-news-hub'),
            'secondary',
            'fnh_catalogo_importar_todos',
            false
        );
        echo '</p>';

        // Filtros en cliente. Con ~270 entradas, buscar a mano las que
        // hay que re-importar es inviable; "Sólo las que difieren" deja
        // en pantalla exactamente las que el seed cambiaría, y el botón
        // de seleccionar actúa sólo sobre lo visible para que no se
        // cuele nada fuera del filtro.
        echo '<div style="margin:12px 0; display:flex; gap:8px; flex-wrap:wrap; align-items:center;">';
        printf(
            '<input type="search" id="fnh-filtro-texto" placeholder="%s" style="min-width:260px;" />',
            esc_attr__('Buscar por nombre, territorio, idioma o URL…', 'flavor-news-hub')
        );
        if ($tab === 'sources') {
            echo '<select id="fnh-filtro-tipo"><option value="">'
                . esc_html__('Todos los tipos', 'flavor-news-hub') . '</option>';
            $tipos = array_values(array_unique(array_map(
                static fn(array $x): string => (string) ($x['feed_type'] ?? 'rss'),
                $datos
            )));
            sort($tipos);
            foreach ($tipos as $tipo) {
                printf('<option value="%s">%s</option>', esc_attr($tipo), esc_html($tipo));
            }
            echo '</select>';
        }
        echo '<select id="fnh-filtro-estado">';
        echo '<option value="">' . esc_html__('Todas', 'flavor-news-hub') . '</option>';
        echo '<option value="difiere">' . esc_html__('Sólo las que difieren de lo instalado', 'flavor-news-hub') . '</option>';
        echo '<option value="pendiente">' . esc_html__('Sólo pendientes de instalar', 'flavor-news-hub') . '</option>';
        echo '<option value="igual">' . esc_html__('Sólo ya sincronizadas', 'flavor-news-hub') . '</option>';
        echo '</select>';
        printf(
            '<button type="button" class="button" id="fnh-marcar-visibles">%s</button>',
            esc_html__('Marcar las visibles', 'flavor-news-hub')
        );
        printf(
            '<span id="fnh-contador" class="description" data-plantilla="%s"></span>',
            esc_attr__('%1$d visibles de %2$d', 'flavor-news-hub')
        );
        echo '</div>';

        echo '<table class="widefat striped">';
        echo '<thead><tr>';
        echo '<td style="width:32px;"><input type="checkbox" id="fnh-check-all" /></td>';
        echo '<th>' . esc_html__('Nombre', 'flavor-news-hub') . '</th>';
        echo '<th>' . esc_html__('Territorio', 'flavor-news-hub') . '</th>';
        echo '<th>' . esc_html__('Idiomas', 'flavor-news-hub') . '</th>';
        if ($tab === 'sources') {
            echo '<th>' . esc_html__('Tipo', 'flavor-news-hub') . '</th>';
            echo '<th>' . esc_html__('URL del feed', 'flavor-news-hub') . '</th>';
        } else {
            echo '<th>' . esc_html__('Stream', 'flavor-news-hub') . '</th>';
        }
        echo '<th>' . esc_html__('Estado', 'flavor-news-hub') . '</th>';
        echo '</tr></thead><tbody>';

        foreach ($datos as $entry) {
            $slug = (string) ($entry['slug'] ?? '');
            if ($slug === '') continue;
            $existe = isset($existentesMapa[$slug]);
            $comparacion = self::compararConInstalado(
                $entry,
                $instalados[$slug] ?? null,
                $tab
            );
            $idiomasFila = $entry['languages'] ?? [];
            $blobBusqueda = strtolower(trim(implode(' ', [
                (string) ($entry['name'] ?? ''),
                $slug,
                (string) ($entry['territory'] ?? ''),
                is_array($idiomasFila) ? implode(' ', $idiomasFila) : '',
                (string) ($entry['feed_url'] ?? ''),
                (string) ($entry['stream_url'] ?? ''),
                (string) ($entry['feed_type'] ?? ''),
            ])));

            printf(
                '<tr data-fnh-buscar="%s" data-fnh-tipo="%s" data-fnh-estado="%s">',
                esc_attr($blobBusqueda),
                esc_attr((string) ($entry['feed_type'] ?? '')),
                esc_attr($comparacion['estado'])
            );
            echo '<td>';
            // Checkbox SIEMPRE — antes sólo se dibujaba para entradas
            // pendientes y eso impedía re-importar (con "Sobrescribir
            // metas") fuentes ya existentes para sincronizar cambios
            // del seed (URLs corregidas, `active=false` en lote, etc.).
            // Re-importar sin "Sobrescribir metas" es no-op porque
            // `ImportadorCatalogo` salta los existentes en ese caso.
            printf(
                '<input type="checkbox" name="slugs[]" value="%s" />',
                esc_attr($slug)
            );
            echo '</td>';
            echo '<td><strong>' . esc_html((string) ($entry['name'] ?? '')) . '</strong></td>';
            echo '<td>' . esc_html((string) ($entry['territory'] ?? '')) . '</td>';
            $idiomas = $entry['languages'] ?? [];
            echo '<td>' . esc_html(is_array($idiomas) ? implode(', ', $idiomas) : '') . '</td>';
            if ($tab === 'sources') {
                echo '<td>' . esc_html((string) ($entry['feed_type'] ?? 'rss')) . '</td>';
                echo '<td><code style="font-size:11px;">' . esc_html((string) ($entry['feed_url'] ?? '')) . '</code></td>';
            } else {
                echo '<td><code style="font-size:11px;">' . esc_html((string) ($entry['stream_url'] ?? '')) . '</code></td>';
            }
            echo '<td>';
            if ($existe) {
                $urlEdicion = get_edit_post_link($existentesMapa[$slug]);
                printf(
                    '<a href="%s">%s</a>',
                    esc_url((string) $urlEdicion),
                    esc_html__('Ya instalada — editar', 'flavor-news-hub')
                );
                if ($comparacion['estado'] === 'difiere') {
                    printf(
                        '<br /><strong style="color:#b32d2e;">%s</strong>',
                        esc_html($comparacion['detalle'])
                    );
                }
            } else {
                echo '<span style="color:#777;">' . esc_html__('Pendiente', 'flavor-news-hub') . '</span>';
            }
            echo '</td>';
            echo '</tr>';
        }

        echo '</tbody></table>';

        echo '</form>';

        // JS del filtrado y del "select all" — sin dependencias.
        // Clave: tanto el check-all de la cabecera como "Marcar las
        // visibles" actúan SÓLO sobre filas visibles. Con un check-all
        // global, filtrar y marcar seleccionaba también lo oculto, que
        // es justo cómo se desactivan por error fuentes que no querías
        // tocar.
        ?>
        <script>
        (function () {
            var tabla = document.querySelector('table.widefat tbody');
            if (!tabla) return;
            var filas = Array.prototype.slice.call(tabla.querySelectorAll('tr'));
            var texto = document.getElementById('fnh-filtro-texto');
            var tipo = document.getElementById('fnh-filtro-tipo');
            var estado = document.getElementById('fnh-filtro-estado');
            var checkAll = document.getElementById('fnh-check-all');
            var botonVisibles = document.getElementById('fnh-marcar-visibles');
            var contador = document.getElementById('fnh-contador');

            function visibles() {
                return filas.filter(function (f) { return f.style.display !== 'none'; });
            }
            function casilla(fila) {
                return fila.querySelector('input[name="slugs[]"]');
            }
            function aplicar() {
                var q = (texto && texto.value || '').trim().toLowerCase();
                var t = tipo && tipo.value || '';
                var e = estado && estado.value || '';
                var n = 0;
                filas.forEach(function (fila) {
                    var ok = true;
                    if (q && (fila.getAttribute('data-fnh-buscar') || '').indexOf(q) === -1) ok = false;
                    if (ok && t && fila.getAttribute('data-fnh-tipo') !== t) ok = false;
                    if (ok && e && fila.getAttribute('data-fnh-estado') !== e) ok = false;
                    fila.style.display = ok ? '' : 'none';
                    if (ok) { n++; }
                    // Una fila oculta no debe seguir marcada: al enviar
                    // el formulario se importaría igualmente.
                    if (!ok) { var c = casilla(fila); if (c) { c.checked = false; } }
                });
                if (contador) {
                    contador.textContent = (contador.getAttribute('data-plantilla') || '%1$d / %2$d')
                        .replace('%1$d', n).replace('%2$d', filas.length);
                }
                if (checkAll) { checkAll.checked = false; }
            }
            function marcar(valor) {
                visibles().forEach(function (fila) {
                    var c = casilla(fila);
                    if (c) { c.checked = valor; }
                });
            }

            if (texto) { texto.addEventListener('input', aplicar); }
            if (tipo) { tipo.addEventListener('change', aplicar); }
            if (estado) { estado.addEventListener('change', aplicar); }
            if (checkAll) {
                checkAll.addEventListener('change', function () { marcar(checkAll.checked); });
            }
            if (botonVisibles) {
                botonVisibles.addEventListener('click', function () { marcar(true); });
            }
            aplicar();
        })();
        </script>
        <?php
    }

    /**
     * @param list<string> $slugs
     * @return array<string,int>
     */
    private static function mapaExistentesPorSlug(string $cptSlug, array $slugs): array
    {
        if (empty($slugs)) return [];
        // `get_page_by_path` funciona con CPTs; para rendimiento hacemos
        // una única query por slugs en batch.
        global $wpdb;
        $placeholders = implode(',', array_fill(0, count($slugs), '%s'));
        $params = array_merge([$cptSlug], $slugs);
        $filas = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT ID, post_name FROM {$wpdb->posts}
                 WHERE post_type = %s AND post_name IN ($placeholders)",
                ...$params
            )
        );
        $mapa = [];
        foreach ($filas as $f) {
            $mapa[(string) $f->post_name] = (int) $f->ID;
        }
        return $mapa;
    }

    /**
     * Valores instalados de las entradas ya presentes, para poder
     * señalar cuáles difieren del seed.
     *
     * Sin esto la tabla sólo distinguía "instalada" de "pendiente", y
     * con ~270 entradas era imposible saber cuáles hay que re-importar
     * tras corregir el catálogo: había que ir buscando a mano. Peor
     * aún, marcar de más con "Sobrescribir metas" desactiva fuentes
     * vivas cuya `active` haya derivado respecto al seed.
     *
     * @param array<string,int> $existentesMapa slug → post_id
     * @return array<string,array{feed_url:string,stream_url:string,active:bool}>
     */
    private static function valoresInstalados(array $existentesMapa): array
    {
        if (empty($existentesMapa)) return [];
        global $wpdb;
        $ids = array_map('intval', array_values($existentesMapa));
        $placeholders = implode(',', array_fill(0, count($ids), '%d'));
        $filas = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT post_id, meta_key, meta_value
                 FROM {$wpdb->postmeta}
                 WHERE post_id IN ($placeholders)
                   AND meta_key IN ('_fnh_feed_url', '_fnh_stream_url', '_fnh_active')",
                ...$ids
            ),
            ARRAY_A
        ) ?: [];
        $porId = [];
        foreach ($filas as $fila) {
            $porId[(int) $fila['post_id']][$fila['meta_key']] = (string) $fila['meta_value'];
        }
        $salida = [];
        foreach ($existentesMapa as $slug => $idPost) {
            $metas = $porId[(int) $idPost] ?? [];
            $salida[(string) $slug] = [
                'feed_url'   => (string) ($metas['_fnh_feed_url'] ?? ''),
                'stream_url' => (string) ($metas['_fnh_stream_url'] ?? ''),
                // Ausencia de meta = activa (así la trata el ingester).
                'active'     => !array_key_exists('_fnh_active', $metas)
                    || (bool) $metas['_fnh_active'],
            ];
        }
        return $salida;
    }

    /**
     * Compara una entrada del seed con lo instalado y devuelve qué
     * cambiaría al re-importarla con "Sobrescribir metas".
     *
     * @param array<string,mixed> $entrada
     * @param array{feed_url:string,stream_url:string,active:bool}|null $instalado
     * @return array{estado:string,detalle:string}
     */
    private static function compararConInstalado(
        array $entrada,
        ?array $instalado,
        string $tab
    ): array {
        if ($instalado === null) {
            return ['estado' => 'pendiente', 'detalle' => ''];
        }
        // `active` sólo se pisa si el seed lo declara (ver ImportadorCatalogo).
        if (array_key_exists('active', $entrada)) {
            $activoSeed = (bool) $entrada['active'];
            if ($activoSeed !== $instalado['active']) {
                return [
                    'estado'  => 'difiere',
                    'detalle' => $activoSeed
                        ? __('Se ACTIVARÁ', 'flavor-news-hub')
                        : __('Se DESACTIVARÁ', 'flavor-news-hub'),
                ];
            }
        }
        $claveUrl = $tab === 'sources' ? 'feed_url' : 'stream_url';
        $urlSeed = (string) ($entrada[$claveUrl] ?? '');
        if ($urlSeed !== '' && $urlSeed !== $instalado[$claveUrl]) {
            return ['estado' => 'difiere', 'detalle' => __('URL distinta', 'flavor-news-hub')];
        }
        return ['estado' => 'igual', 'detalle' => ''];
    }

    private static function procesarAccionSiCorresponde(): void
    {
        if (!isset($_POST['fnh_catalogo_tab'])) return;
        check_admin_referer(self::NONCE_ACCION);

        $tab = sanitize_key((string) $_POST['fnh_catalogo_tab']);
        $actualizar = !empty($_POST['fnh_catalogo_actualizar']);

        $importarTodos = isset($_POST['fnh_catalogo_importar_todos']);
        $slugs = $_POST['slugs'] ?? [];
        if (!is_array($slugs)) $slugs = [];
        $slugs = array_values(array_filter(array_map('sanitize_title', $slugs)));

        if (!$importarTodos && empty($slugs)) {
            add_settings_error(
                'fnh_catalogo',
                'vacio',
                __('No seleccionaste ninguna entrada para importar.', 'flavor-news-hub'),
                'warning'
            );
            settings_errors('fnh_catalogo');
            return;
        }

        $filtro = $importarTodos ? null : $slugs;
        $datos = $tab === 'sources'
            ? CatalogoPorDefecto::sources()
            : CatalogoPorDefecto::radios();

        $resultado = $tab === 'sources'
            ? ImportadorCatalogo::importarSources($datos, $actualizar, $filtro)
            : ImportadorCatalogo::importarRadios($datos, $actualizar, $filtro);

        add_settings_error(
            'fnh_catalogo',
            'ok',
            sprintf(
                esc_html__(
                    'Importación completada: %1$d nuevas, %2$d actualizadas, %3$d saltadas.',
                    'flavor-news-hub'
                ),
                $resultado['creados'],
                $resultado['actualizados'],
                $resultado['saltados']
            ),
            'updated'
        );
        if (!empty($resultado['errores'])) {
            add_settings_error(
                'fnh_catalogo',
                'errores',
                implode(' · ', $resultado['errores']),
                'error'
            );
        }
        settings_errors('fnh_catalogo');
    }
}
