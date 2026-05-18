import 'package:flutter/material.dart';
import 'package:flavor_news_hub/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/canal_distribucion.dart';
import '../../../core/idioma_contenido/politica_idioma_contenido.dart';
import '../../../core/idioma_contenido/sheet_politica_idioma_contenido.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/settings_sync.dart';
import '../../../core/utils/territory_normalizer.dart';
import '../../actualizaciones/data/actualizaciones_provider.dart';
import '../../widgets/widgets_refrescador.dart';

/// Ajustes completos de la app: idioma UI, tema, tamaño de texto, URL de
/// la instancia backend. Todo persistido via `preferenciasProvider`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const List<_OpcionIdioma> _opcionesIdioma = [
    _OpcionIdioma(codigo: null),
    _OpcionIdioma(codigo: 'es'),
    _OpcionIdioma(codigo: 'ca'),
    _OpcionIdioma(codigo: 'eu'),
    _OpcionIdioma(codigo: 'gl'),
    _OpcionIdioma(codigo: 'en'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final preferencias = ref.watch(preferenciasProvider);
    final notifier = ref.read(preferenciasProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(textos.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(textos.settingsTheme),
            subtitle: Text(_etiquetaTema(textos, preferencias.modoTema)),
            onTap: () => _seleccionarTema(context, notifier, preferencias.modoTema, textos),
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(textos.settingsInterfaceLanguage),
            subtitle: Text(_etiquetaIdioma(textos, preferencias.codigoIdioma)),
            onTap: () => _seleccionarIdioma(context, ref, notifier, preferencias.codigoIdioma, textos),
          ),
          Consumer(
            builder: (context, refIdioma, _) {
              final estado = refIdioma.watch(politicaIdiomaContenidoProvider);
              return ListTile(
                leading: const Icon(Icons.subtitles_outlined),
                title: Text(textos.settingsContentLanguage),
                subtitle: Text(_etiquetaPoliticaIdioma(textos, estado)),
                onTap: () => _abrirPoliticaIdiomaContenido(context, refIdioma, textos),
              );
            },
          ),
          const Divider(height: 24),
          _ControlEscalaTexto(
            escalaActual: preferencias.escalaTexto,
            onCambio: notifier.establecerEscalaTexto,
            etiqueta: textos.settingsTextScale,
          ),
          const Divider(height: 24),
          ListTile(
            leading: Icon(
              Icons.campaign_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(textos.settingsMovimientos),
            subtitle: Text(textos.settingsMovimientosSubtitle),
            onTap: () => context.push('/movimientos'),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text(textos.savedTitle),
            subtitle: Text(textos.savedSubtitle),
            onTap: () => context.push('/guardados'),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(textos.settingsHistory),
            subtitle: Text(textos.settingsHistorySubtitle),
            onTap: () => context.push('/historial'),
          ),
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(textos.settingsTusIntereses),
            subtitle: Text(textos.settingsTusInteresesSubtitle),
            onTap: () => context.push('/tus-intereses'),
          ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(textos.settingsMyTerritory),
            subtitle: Text(
              preferencias.territorioBase.isEmpty
                  ? textos.settingsMyTerritorySubtitle
                  : TerritoryNormalizer.etiquetaDeClave(preferencias.territorioBase),
            ),
            onTap: () => _seleccionarTerritorio(context, notifier, preferencias.territorioBase, textos),
          ),
          ListTile(
            leading: const Icon(Icons.rss_feed),
            title: Text(textos.settingsMyMedia),
            subtitle: Text(textos.settingsMyMediaSubtitle),
            onTap: () => context.push('/mis-medios'),
          ),
          ListTile(
            leading: const Icon(Icons.filter_alt_outlined),
            title: Text(textos.settingsSourcesPrefs),
            subtitle: Text(textos.settingsSourcesPrefsSubtitle),
            onTap: () => context.push('/fuentes-preferencias'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(textos.settingsNotifications),
            subtitle: Text(textos.settingsNotificationsSubtitle),
            onTap: () => context.push('/notificaciones'),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(textos.settingsMap),
            subtitle: Text(textos.settingsMapSubtitle),
            onTap: () => context.push('/map'),
          ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: Text(textos.settingsMusic),
            subtitle: Text(textos.settingsMusicSubtitle),
            onTap: () => context.push('/music'),
          ),
          ListTile(
            leading: const Icon(Icons.rss_feed_outlined),
            title: Text(textos.settingsProposeSource),
            subtitle: Text(textos.settingsProposeSourceSubtitle),
            onTap: () => context.push('/sources/submit'),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(textos.settingsShareApp),
            subtitle: Text(textos.settingsShareAppSubtitle),
            onTap: () => Share.share(textos.shareAppMessage),
          ),
          // En el flavor `playstore` Google Play se encarga de las
          // actualizaciones; ofrecer un botón propio de "comprobar
          // actualización" sólo confunde, y la permission para
          // auto-instalar APKs no está incluida en ese flavor.
          if (soportaOtaInterna)
            ListTile(
              leading: const Icon(Icons.system_update_alt_outlined),
              title: Text(textos.settingsCheckUpdate),
              subtitle: Text(textos.settingsCheckUpdateSubtitle),
              onTap: () => _comprobarActualizacion(context, ref, textos),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(textos.settingsAbout),
            onTap: () => context.push('/about'),
          ),
          // "Avanzado" agrupa opciones para usuarios técnicos — hoy solo
          // la URL del backend. Colapsado por defecto: el 99 % de la
          // gente no necesita tocarla, y tenerla a la vista invita a
          // introducir una URL rota y dejar la app sin datos.
          ExpansionTile(
            leading: const Icon(Icons.tune),
            title: Text(textos.settingsAdvanced),
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(_etiquetaInstancia(preferencias)),
                subtitle: Text(
                  preferencias.urlInstanciaBackend,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _editarUrlBackend(
                  context,
                  notifier,
                  preferencias.urlInstanciaBackend,
                  preferencias.nombreInstancia,
                  textos,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Forzamos una comprobación inmediata saltando el cache local y el
  /// cache del backend: limpiamos las dos claves de SharedPreferences
  /// donde el provider guarda la última respuesta y su timestamp, y
  /// luego invalidamos el provider para que vuelva a pedir. Si hay
  /// actualización, abrimos directamente la release en el navegador —
  /// no dependemos del diálogo automático de `AvisoActualizacion`
  /// (cuyo flag `_mostrado` puede estar a `true` si ya apareció).
  Future<void> _comprobarActualizacion(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations textos,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('fnh.pref.actualizacion.respuesta');
    await prefs.remove('fnh.pref.actualizacion.ts');
    await prefs.remove('fnh.pref.actualizacion.descartada');
    // Invalidamos ambas variantes (forzar=true y =false) por si el
    // usuario había chequeado pasivo antes — así Aviso y Comprobar
    // re-piden tras esta acción.
    ref.invalidate(actualizacionProvider);
    messenger.showSnackBar(SnackBar(
      content: Text(textos.settingsCheckUpdateChecking),
      duration: const Duration(seconds: 2),
    ));
    try {
      // forzar=true → la app salta su cache local Y le pasa
      // refresh=1 al backend para que también ignore el transient.
      final estado = await ref.read(actualizacionProvider(true).future);
      if (!context.mounted) return;
      if (!estado.hayActualizacion) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(textos.settingsCheckUpdateUpToDate),
        ));
        return;
      }
      final url = estado.urlRelease ?? estado.urlDescarga;
      if (url == null || url.isEmpty) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(
          textos.settingsCheckUpdateAvailable(estado.versionRemota ?? ''),
        ),
        action: SnackBarAction(
          label: textos.updateDownload,
          onPressed: () async {
            final uri = Uri.tryParse(url);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
        duration: const Duration(seconds: 8),
      ));
    } catch (_) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(textos.settingsCheckUpdateError),
      ));
    }
  }

  String _etiquetaTema(AppLocalizations textos, ThemeMode modo) {
    switch (modo) {
      case ThemeMode.light:
        return textos.settingsThemeLight;
      case ThemeMode.dark:
        return textos.settingsThemeDark;
      case ThemeMode.system:
        return textos.settingsThemeSystem;
    }
  }

  String _etiquetaIdioma(AppLocalizations textos, String? codigo) {
    if (codigo == null) return textos.settingsInterfaceLanguageSystem;
    return _nombreIdioma(codigo);
  }

  static String _nombreIdioma(String codigo) {
    switch (codigo) {
      case 'es':
        return 'Castellano';
      case 'ca':
        return 'Català';
      case 'eu':
        return 'Euskara';
      case 'gl':
        return 'Galego';
      case 'en':
        return 'English';
      default:
        return codigo;
    }
  }

  Future<void> _seleccionarTema(
    BuildContext context,
    PreferenciasNotifier notifier,
    ThemeMode actual,
    AppLocalizations textos,
  ) async {
    final seleccion = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final modo in ThemeMode.values)
              RadioListTile<ThemeMode>(
                value: modo,
                groupValue: actual,
                title: Text(_etiquetaTema(textos, modo)),
                onChanged: (valor) {
                  if (valor != null) Navigator.pop(ctx, valor);
                },
              ),
          ],
        ),
      ),
    );
    if (seleccion != null) {
      await notifier.establecerModoTema(seleccion);
    }
  }

  Future<void> _seleccionarIdioma(
    BuildContext context,
    WidgetRef ref,
    PreferenciasNotifier notifier,
    String? actual,
    AppLocalizations textos,
  ) async {
    final seleccion = await showModalBottomSheet<_OpcionIdioma>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opcion in _opcionesIdioma)
              RadioListTile<_OpcionIdioma>(
                value: opcion,
                groupValue: _opcionesIdioma.firstWhere(
                  (o) => o.codigo == actual,
                  orElse: () => _opcionesIdioma.first,
                ),
                title: Text(_etiquetaIdioma(textos, opcion.codigo)),
                onChanged: (valor) {
                  if (valor != null) Navigator.pop(ctx, valor);
                },
              ),
          ],
        ),
      ),
    );
    if (seleccion != null) {
      await notifier.establecerIdiomaUi(seleccion.codigo);
      // Ya no hace falta propagar manualmente a los filtros de
      // contenido: la política central
      // (`idiomasContenidoEfectivosProvider`) detecta el cambio del
      // idioma de UI cuando está en modo `seguirInterfaz` y todas las
      // pestañas se refrescan automáticamente.
      //
      // Sí necesitamos repintar los widgets nativos: leen sus textos
      // de `strings.xml` con `IdiomaWidget.recursos()`, que mira la
      // preferencia recién cambiada. Sin este disparo, el widget en
      // pantalla de inicio se queda con los textos del idioma anterior
      // hasta el siguiente refresh natural.
      await WidgetsRefrescador.repintarTodos();
    }
  }

  /// Texto resumen para mostrar bajo el ListTile "Idioma del contenido".
  /// Tres modos posibles: seguir UI / manual (lista de chips) / off.
  String _etiquetaPoliticaIdioma(AppLocalizations textos, EstadoIdiomaContenido estado) {
    switch (estado.modo) {
      case ModoIdiomaContenido.seguirInterfaz:
        return textos.settingsContentLanguageFollowUi;
      case ModoIdiomaContenido.desactivado:
        return textos.settingsContentLanguageOff;
      case ModoIdiomaContenido.manual:
        if (estado.idiomasManuales.isEmpty) {
          return textos.settingsContentLanguageManual;
        }
        return estado.idiomasManuales
            .map((c) => _nombreIdioma(c))
            .join(' · ');
    }
  }

  Future<void> _abrirPoliticaIdiomaContenido(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations textos,
  ) async {
    await SheetPoliticaIdiomaContenido.mostrar(context);
  }

  Future<void> _seleccionarTerritorio(
    BuildContext context,
    PreferenciasNotifier notifier,
    String actual,
    AppLocalizations textos,
  ) async {
    final opciones = TerritoryNormalizer.listarOpcionesCuradas();
    final porGrupo = <String, List<TerritoryOption>>{};
    for (final opcion in opciones) {
      porGrupo.putIfAbsent(opcion.grupo, () => []).add(opcion);
    }
    final seleccion = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final altoPantalla = MediaQuery.of(ctx).size.height;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: altoPantalla * 0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    textos.settingsMyTerritoryChoose,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      RadioListTile<String>(
                        value: '',
                        groupValue: actual,
                        title: Text(textos.settingsMyTerritoryNone),
                        onChanged: (valor) => Navigator.pop(ctx, valor ?? ''),
                      ),
                      for (final entrada in porGrupo.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            entrada.key,
                            style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(ctx).colorScheme.primary,
                                ),
                          ),
                        ),
                        for (final opcion in entrada.value)
                          RadioListTile<String>(
                            value: opcion.clave,
                            groupValue: actual,
                            title: Text(opcion.etiqueta),
                            onChanged: (valor) => Navigator.pop(ctx, valor),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (seleccion != null) {
      await notifier.establecerTerritorioBase(seleccion);
    }
  }

  Future<void> _editarUrlBackend(
    BuildContext context,
    PreferenciasNotifier notifier,
    String urlActual,
    String nombreActual,
    AppLocalizations textos,
  ) async {
    final resultado = await showDialog<_ResultadoEditarInstancia?>(
      context: context,
      builder: (ctx) => _DialogoEditarUrl(
        urlInicial: urlActual,
        nombreInicial: nombreActual,
        textos: textos,
      ),
    );
    if (resultado != null) {
      await notifier.establecerUrlBackend(resultado.url);
      await notifier.establecerNombreInstancia(resultado.nombre);
    }
  }
}

/// Etiqueta a mostrar como título del ListTile de la instancia: si el
/// usuario fijó un nombre, ese; si no, el host de la URL como pista
/// rápida ("flavor.gailu.it" en lugar de la URL completa que ya está en
/// el subtítulo). Si la URL es inválida cae a la cadena por defecto.
String _etiquetaInstancia(PreferenciasUsuario prefs) {
  if (prefs.nombreInstancia.isNotEmpty) return prefs.nombreInstancia;
  final uri = Uri.tryParse(prefs.urlInstanciaBackend);
  if (uri != null && uri.host.isNotEmpty) return uri.host;
  return prefs.urlInstanciaBackend;
}

/// Tupla devuelta por `_DialogoEditarUrl`. Se usa una clase explícita en
/// lugar de un record `({String url, String nombre})` para que las
/// llamadas a `Navigator.pop` sean inequívocas y `showDialog` infiera
/// el genérico sin ambigüedades.
class _ResultadoEditarInstancia {
  const _ResultadoEditarInstancia({required this.url, required this.nombre});
  final String url;
  final String nombre;
}

class _DialogoEditarUrl extends StatefulWidget {
  const _DialogoEditarUrl({
    required this.urlInicial,
    required this.nombreInicial,
    required this.textos,
  });
  final String urlInicial;
  final String nombreInicial;
  final AppLocalizations textos;

  @override
  State<_DialogoEditarUrl> createState() => _EstadoDialogoEditarUrl();
}

class _EstadoDialogoEditarUrl extends State<_DialogoEditarUrl> {
  late final TextEditingController _controllerUrl;
  late final TextEditingController _controllerNombre;
  String? _mensajeErrorUrl;
  bool _sugiriendoNombre = false;

  @override
  void initState() {
    super.initState();
    _controllerUrl = TextEditingController(text: widget.urlInicial);
    _controllerNombre = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _controllerUrl.dispose();
    _controllerNombre.dispose();
    super.dispose();
  }

  String? _validar(String valor) {
    final limpio = valor.trim();
    if (limpio.isEmpty) return null; // vacío = restaurar default
    final uri = Uri.tryParse(limpio);
    if (uri == null) return 'URL no válida.';
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'La URL debe empezar por http:// o https://';
    }
    if (!uri.hasAuthority || uri.host.isEmpty) return 'Falta el dominio.';
    return null;
  }

  /// Pide a la URL escrita el `site_name` declarado por la instancia y
  /// rellena el campo Nombre con la respuesta. Si la URL es inválida,
  /// el backend no responde o no expone el campo (plugin viejo) muestra
  /// un SnackBar y deja el campo como esté.
  Future<void> _sugerirNombreDesdeInstancia() async {
    final messenger = ScaffoldMessenger.of(context);
    final urlIntroducida = _controllerUrl.text.trim();
    final errorUrl = _validar(urlIntroducida);
    if (errorUrl != null || urlIntroducida.isEmpty) {
      setState(() => _mensajeErrorUrl = errorUrl ?? 'Introduce primero la URL.');
      return;
    }
    setState(() => _sugiriendoNombre = true);
    final nombre = await obtenerNombreSitioRemoto(Uri.parse(urlIntroducida));
    if (!mounted) return;
    setState(() => _sugiriendoNombre = false);
    if (nombre == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo obtener el nombre desde la instancia.'),
      ));
      return;
    }
    setState(() => _controllerNombre.text = nombre);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.textos.settingsBackendUrl),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.textos.settingsBackendUrlDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerUrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: urlInstanciaOficialDefault,
                errorText: _mensajeErrorUrl,
                border: const OutlineInputBorder(),
                suffixIcon: _controllerUrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controllerUrl.clear();
                          setState(() => _mensajeErrorUrl = null);
                        },
                      ),
              ),
              onChanged: (valor) => setState(() => _mensajeErrorUrl = _validar(valor)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllerNombre,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: 'Mi instancia',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton.icon(
                  onPressed: _sugiriendoNombre ? null : _sugerirNombreDesdeInstancia,
                  icon: _sugiriendoNombre
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                  label: const Text('Sugerir'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const _ResultadoEditarInstancia(url: urlInstanciaOficialDefault, nombre: ''),
          ),
          child: const Text('Restaurar por defecto'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.textos.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final valor = _controllerUrl.text.trim();
            final error = _validar(valor);
            if (error != null) {
              setState(() => _mensajeErrorUrl = error);
              return;
            }
            Navigator.of(context).pop(_ResultadoEditarInstancia(
              url: valor,
              nombre: _controllerNombre.text.trim(),
            ));
          },
          child: Text(widget.textos.commonOk),
        ),
      ],
    );
  }
}

class _ControlEscalaTexto extends StatelessWidget {
  const _ControlEscalaTexto({
    required this.escalaActual,
    required this.onCambio,
    required this.etiqueta,
  });

  final double escalaActual;
  final ValueChanged<double> onCambio;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields),
              const SizedBox(width: 16),
              Expanded(child: Text(etiqueta)),
              Text('${(escalaActual * 100).round()} %'),
            ],
          ),
          Slider(
            value: escalaActual,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${(escalaActual * 100).round()} %',
            onChanged: onCambio,
          ),
          // Preview textual en la escala seleccionada.
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4, bottom: 8),
            child: Text(
              'Aa — Ejemplo del tamaño actual',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * escalaActual),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionIdioma {
  const _OpcionIdioma({required this.codigo});
  final String? codigo;

  @override
  bool operator ==(Object other) => other is _OpcionIdioma && other.codigo == codigo;

  @override
  int get hashCode => codigo.hashCode;
}

