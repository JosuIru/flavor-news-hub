import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../feed/data/filtros_feed.dart';

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
          const Divider(height: 24),
          _ControlEscalaTexto(
            escalaActual: preferencias.escalaTexto,
            onCambio: notifier.establecerEscalaTexto,
            etiqueta: textos.settingsTextScale,
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(textos.settingsBackendUrl),
            subtitle: Text(preferencias.urlInstanciaBackend, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _editarUrlBackend(context, notifier, preferencias.urlInstanciaBackend, textos),
          ),
          const Divider(height: 24),
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
            onTap: () => Share.share(
              '${textos.appName} — ${textos.appTagline}\nhttps://github.com/flavor-news-hub',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(textos.settingsAbout),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
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
      // Propagamos el nuevo idioma al filtro de noticias, salvo que el
      // usuario tuviera varios idiomas seleccionados a propósito.
      if (seleccion.codigo != null) {
        await ref.read(filtrosFeedProvider.notifier).adoptarIdiomaUi(seleccion.codigo);
      }
    }
  }

  Future<void> _editarUrlBackend(
    BuildContext context,
    PreferenciasNotifier notifier,
    String urlActual,
    AppLocalizations textos,
  ) async {
    final resultado = await showDialog<String?>(
      context: context,
      builder: (ctx) => _DialogoEditarUrl(
        urlInicial: urlActual,
        textos: textos,
      ),
    );
    if (resultado != null) {
      await notifier.establecerUrlBackend(resultado);
    }
  }
}

class _DialogoEditarUrl extends StatefulWidget {
  const _DialogoEditarUrl({required this.urlInicial, required this.textos});
  final String urlInicial;
  final AppLocalizations textos;

  @override
  State<_DialogoEditarUrl> createState() => _EstadoDialogoEditarUrl();
}

class _EstadoDialogoEditarUrl extends State<_DialogoEditarUrl> {
  late final TextEditingController _controllerUrl;
  String? _mensajeErrorUrl;

  @override
  void initState() {
    super.initState();
    _controllerUrl = TextEditingController(text: widget.urlInicial);
  }

  @override
  void dispose() {
    _controllerUrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.textos.settingsBackendUrl),
      content: Column(
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(urlInstanciaOficialDefault),
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
            Navigator.of(context).pop(valor);
          },
          child: const Text('OK'),
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
