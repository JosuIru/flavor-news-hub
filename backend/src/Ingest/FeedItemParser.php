<?php
declare(strict_types=1);

namespace FlavorNewsHub\Ingest;

/**
 * Convierte un `SimplePie_Item` en un array normalizado listo para crear
 * un CPT `fnh_item`.
 *
 * Principio editorial: NO se scrapea la web del medio. Sólo se usa lo que
 * el feed provee, y además se recorta el cuerpo a un extracto: respetar el
 * tráfico y los ingresos del medio es parte del contrato del proyecto.
 */
final class FeedItemParser
{
    private const LIMITE_PALABRAS_EXTRACTO = 80;

    /**
     * @return array{
     *   title:string,
     *   excerpt:string,
     *   permalink:string,
     *   published_at:string,
     *   guid:string,
     *   media_url:string
     * }
     */
    public static function parsear(\SimplePie_Item $itemFeed): array
    {
        // Los feeds suelen entregar títulos con entidades HTML (`&quot;`, `&amp;`,
        // `&#8220;`…). SimplePie las deja tal cual. Algunos feeds (p.ej. MakerTube)
        // las entregan **doblemente escapadas** (`&amp;#8217;` → decode una vez
        // queda `&#8217;`), así que aplicamos decode dos veces antes de persistir.
        $titularLimpio = wp_strip_all_tags((string) $itemFeed->get_title());
        $titularLimpio = html_entity_decode($titularLimpio, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $titularLimpio = html_entity_decode($titularLimpio, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $titularLimpio = self::sanearCadenaLegible(trim($titularLimpio));
        $urlPermalinkOriginal = esc_url_raw((string) $itemFeed->get_permalink());

        $extractoRespetuoso = self::extraerExtracto($itemFeed);

        // SimplePie devuelve el timestamp en UTC cuando pides 'U'.
        $timestampPublicacion = (int) $itemFeed->get_date('U');
        $fechaPublicacionIso = $timestampPublicacion > 0
            ? gmdate('c', $timestampPublicacion)
            : '';

        // GUID canónico del feed; si no existe, caemos al permalink como id estable.
        $identificadorUnico = (string) $itemFeed->get_id();
        if ($identificadorUnico === '') {
            $identificadorUnico = $urlPermalinkOriginal;
        }

        $urlImagenDestacada = self::extraerImagenDestacada($itemFeed);

        return [
            'title'        => $titularLimpio,
            'excerpt'      => $extractoRespetuoso,
            'permalink'    => $urlPermalinkOriginal,
            'published_at' => $fechaPublicacionIso,
            'guid'         => $identificadorUnico,
            'media_url'    => $urlImagenDestacada,
        ];
    }

    /**
     * Quita control chars, reemplazo UTF-8 y emojis decorativos frecuentes
     * en titulares clickbait de YouTube (🚨 🔥 👉 ❗ ⚡ 📢 ✅ ❌ …) que la
     * tipografía del sistema a menudo no renderiza bien.
     *
     * Deja intactos acentos, puntuación y caracteres latinos extendidos.
     */
    public static function sanearCadenaLegible(string $entrada): string
    {
        if ($entrada === '') {
            return '';
        }
        // Unicode-safe: PHP PCRE con /u. Los rangos son los bloques de
        // "Emoticons", "Misc Symbols and Pictographs", "Transport",
        // "Supplemental Symbols", "Symbols and Pictographs Extended-A",
        // y el selector de presentación emoji (U+FE0F).
        $sinEmojis = preg_replace(
            '/[\x{1F000}-\x{1FBFF}\x{2600}-\x{27BF}\x{FE0F}\x{200D}]/u',
            '',
            $entrada
        );
        if ($sinEmojis === null) {
            $sinEmojis = $entrada; // fallback si PCRE falla
        }
        // Control chars (excepto salto de línea y tab).
        $sinControl = preg_replace('/[\x{0000}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001F}]/u', '', $sinEmojis);
        if ($sinControl === null) {
            $sinControl = $sinEmojis;
        }
        // Replacement char U+FFFD (aparece cuando un byte UTF-8 se perdió).
        $sinReplacement = str_replace("\u{FFFD}", '', $sinControl);
        // Espacios dobles resultantes de quitar emojis pegados.
        $compacto = preg_replace('/\s{2,}/u', ' ', $sinReplacement);
        return trim($compacto ?? $sinReplacement);
    }

    /**
     * Prefiere el `description` del feed (típicamente un summary corto).
     * Si viene vacío, trunca el `content` a un número razonable de palabras.
     * Nunca devuelve HTML completo de un artículo entero.
     */
    private static function extraerExtracto(\SimplePie_Item $itemFeed): string
    {
        $descripcionFeed = (string) $itemFeed->get_description();
        $descripcionSaneada = wp_kses_post($descripcionFeed);
        if (trim(wp_strip_all_tags($descripcionSaneada)) !== '') {
            return $descripcionSaneada;
        }

        $contenidoFeed = (string) $itemFeed->get_content();
        if ($contenidoFeed === '') {
            return '';
        }
        $textoPlano = wp_strip_all_tags(wp_kses_post($contenidoFeed));
        return wp_trim_words($textoPlano, self::LIMITE_PALABRAS_EXTRACTO, '…');
    }

    /**
     * Estrategia por prioridad:
     *  1. Enclosure de tipo imagen.
     *  2. Thumbnail del enclosure (media:thumbnail).
     *  3. Primera <img> del contenido (fallback barato).
     */
    private static function extraerImagenDestacada(\SimplePie_Item $itemFeed): string
    {
        $enclosure = $itemFeed->get_enclosure();
        if ($enclosure instanceof \SimplePie_Enclosure) {
            $tipoMime = (string) $enclosure->get_type();
            if ($tipoMime === '' || str_starts_with($tipoMime, 'image/')) {
                $urlEnclosure = (string) $enclosure->get_link();
                if ($urlEnclosure !== '') {
                    return esc_url_raw($urlEnclosure);
                }
            }
            $urlThumbnail = (string) $enclosure->get_thumbnail();
            if ($urlThumbnail !== '') {
                return esc_url_raw($urlThumbnail);
            }
        }

        $contenidoFeed = (string) $itemFeed->get_content();
        if ($contenidoFeed !== '' && preg_match('/<img[^>]+src=["\']([^"\']+)["\']/i', $contenidoFeed, $coincidencias)) {
            return esc_url_raw($coincidencias[1]);
        }
        return '';
    }
}
