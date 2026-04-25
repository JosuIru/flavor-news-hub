<?php
declare(strict_types=1);

namespace FlavorNewsHub\Notifications;

use FlavorNewsHub\Options\OptionsRepository;

/**
 * Avisa por email al administrador cuando llega una propuesta nueva
 * de medio (`source`) o colectivo (`collective`) por la API pública.
 *
 * Se llama desde `SourceSubmitEndpoint::crear` y
 * `CollectiveSubmitEndpoint::crear` justo después de crear el post
 * en estado `pending`. El envío se silencia con un toggle en Ajustes
 * y permite redirigir el destino con `notify_email_target`.
 */
final class SubmitNotifier
{
    public const TIPO_SOURCE = 'source';
    public const TIPO_COLLECTIVE = 'collective';

    /**
     * Envía el aviso. No bloquea ni propaga errores: si wp_mail falla,
     * la propuesta queda igualmente en `pending` para revisión manual.
     */
    public static function notificar(string $tipoEntidad, int $idPost, string $emailRemitente): void
    {
        $opciones = OptionsRepository::todas();
        if (empty($opciones['notify_email_on_submit'])) {
            return;
        }

        $emailDestino = trim((string) ($opciones['notify_email_target'] ?? ''));
        if ($emailDestino === '' || !is_email($emailDestino)) {
            $emailDestino = (string) get_option('admin_email');
        }
        if ($emailDestino === '' || !is_email($emailDestino)) {
            return;
        }

        $titulo = (string) get_the_title($idPost);
        $urlEditar = admin_url('post.php?post=' . $idPost . '&action=edit');
        $nombreSitio = (string) get_bloginfo('name');

        $etiquetaTipo = $tipoEntidad === self::TIPO_COLLECTIVE
            ? __('colectivo', 'flavor-news-hub')
            : __('medio', 'flavor-news-hub');

        $asunto = sprintf(
            /* translators: 1: nombre del sitio, 2: tipo de entidad (medio/colectivo), 3: título propuesto */
            __('[%1$s] Propuesta nueva de %2$s: %3$s', 'flavor-news-hub'),
            $nombreSitio,
            $etiquetaTipo,
            $titulo
        );

        $cuerpoLineas = [
            sprintf(
                /* translators: %s tipo de entidad (medio/colectivo) */
                __('Ha llegado una propuesta nueva de %s a través del formulario público.', 'flavor-news-hub'),
                $etiquetaTipo
            ),
            '',
            __('Resumen', 'flavor-news-hub') . ':',
            '  ' . __('Título', 'flavor-news-hub') . ': ' . $titulo,
            '  ' . __('Email del remitente', 'flavor-news-hub') . ': ' . ($emailRemitente !== '' ? $emailRemitente : '—'),
            '  ' . __('ID interno', 'flavor-news-hub') . ': ' . $idPost,
            '',
            __('Detalles', 'flavor-news-hub') . ':',
        ];

        $metaInteresante = self::extraerMetaRelevante($tipoEntidad, $idPost);
        foreach ($metaInteresante as $clave => $valor) {
            $cuerpoLineas[] = '  ' . $clave . ': ' . $valor;
        }

        $cuerpoLineas[] = '';
        $cuerpoLineas[] = __('Revisa y aprueba desde el admin:', 'flavor-news-hub');
        $cuerpoLineas[] = $urlEditar;
        $cuerpoLineas[] = '';
        $cuerpoLineas[] = sprintf(
            /* translators: %s nombre del sitio */
            __('— Flavor News Hub @ %s', 'flavor-news-hub'),
            $nombreSitio
        );

        $cuerpo = implode("\n", $cuerpoLineas);

        wp_mail($emailDestino, $asunto, $cuerpo);
    }

    /**
     * Vuelca los meta más relevantes de la propuesta para que el admin
     * pueda decidir sin entrar al backend si el caso es obvio.
     *
     * @return array<string,string>
     */
    private static function extraerMetaRelevante(string $tipoEntidad, int $idPost): array
    {
        $relevantes = [];

        if ($tipoEntidad === self::TIPO_SOURCE) {
            $mapaSource = [
                'feed_url'     => __('Feed URL', 'flavor-news-hub'),
                'feed_type'    => __('Tipo', 'flavor-news-hub'),
                'website_url'  => __('Web', 'flavor-news-hub'),
                'territory'    => __('Territorio', 'flavor-news-hub'),
                'languages'    => __('Idiomas', 'flavor-news-hub'),
            ];
            foreach ($mapaSource as $sufijo => $etiqueta) {
                $valor = get_post_meta($idPost, '_fnh_' . $sufijo, true);
                if (is_array($valor)) {
                    $valor = implode(', ', $valor);
                }
                $valor = (string) $valor;
                if ($valor !== '') {
                    $relevantes[$etiqueta] = $valor;
                }
            }
        } elseif ($tipoEntidad === self::TIPO_COLLECTIVE) {
            $mapaCollective = [
                'website_url'  => __('Web', 'flavor-news-hub'),
                'flavor_url'   => __('Flavor Platform', 'flavor-news-hub'),
                'territory'    => __('Territorio', 'flavor-news-hub'),
                'contact_email' => __('Email de contacto', 'flavor-news-hub'),
            ];
            foreach ($mapaCollective as $sufijo => $etiqueta) {
                $valor = (string) get_post_meta($idPost, '_fnh_' . $sufijo, true);
                if ($valor !== '') {
                    $relevantes[$etiqueta] = $valor;
                }
            }
        }

        return $relevantes;
    }
}
