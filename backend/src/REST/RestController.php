<?php
declare(strict_types=1);

namespace FlavorNewsHub\REST;

/**
 * Punto de entrada del namespace REST propio del plugin: `flavor-news/v1`.
 *
 * Registra todas las rutas delegando en los endpoints concretos. Se engancha
 * desde Plugin::arrancar() al hook `rest_api_init`.
 *
 * La API estándar de WordPress (`wp/v2`) sigue exponiendo los CPTs para uso
 * interno del admin, pero la app cliente consumirá siempre `flavor-news/v1`,
 * que normaliza los datos a snake_case y filtra los campos sensibles.
 */
final class RestController
{
    public const NAMESPACE_REST = 'flavor-news/v1';

    public static function registrar(): void
    {
        ItemsEndpoint::registrarRutas();
        SourcesEndpoint::registrarRutas();
        CollectivesEndpoint::registrarRutas();
        TopicsEndpoint::registrarRutas();
        CollectiveSubmitEndpoint::registrarRutas();
        SourceSubmitEndpoint::registrarRutas();
        RadiosEndpoint::registrarRutas();
        AppUpdateEndpoint::registrarRutas();
        FeedHtmlEndpoint::registrarRutas();
        IngestTriggerEndpoint::registrarRutas();
        PublicSettingsEndpoint::registrarRutas();
        DiagnosticsEndpoint::registrarRutas();
    }
}
