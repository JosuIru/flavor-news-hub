/// Canal por el que se distribuye este build de la app. Se inyecta como
/// `--dart-define=CANAL=playstore` al construir el flavor de Play; si no
/// se pasa, por defecto el canal es `libre` (F-Droid/IzzyOnDroid/GitHub
/// Releases/Obtainium).
///
/// Lo único que cambia entre canales hoy es el flujo OTA: el `libre`
/// trae auto-actualización completa (descarga APK + invoca instalador
/// del sistema vía `REQUEST_INSTALL_PACKAGES`), mientras que `playstore`
/// la oculta porque la política de Google Play prohíbe esa permission a
/// apps que no son gestores de paquetes.
const String canalDistribucion =
    String.fromEnvironment('CANAL', defaultValue: 'libre');

/// True si este build incluye el flujo OTA (descarga + auto-instalación
/// del APK). Use esta gate para mostrar/ocultar la pantalla "Comprobar
/// actualización", el banner de aviso, y cualquier código que dependa
/// de la permission `REQUEST_INSTALL_PACKAGES`.
const bool soportaOtaInterna = canalDistribucion != 'playstore';
