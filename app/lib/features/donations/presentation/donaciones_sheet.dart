import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sheet modal con las opciones de donación / apoyo. Replica las URLs
/// del proyecto "Colección Nuevo Ser" para unificar la caja común entre
/// apps: Ko-fi, PayPal y dos direcciones Bitcoin.
///
/// Las direcciones se copian al portapapeles con feedback; los enlaces
/// abren en navegador externo para no bloquear la app con un WebView.
///
/// También ofrece compartir la app en redes — es "donar tiempo" en vez
/// de dinero, y encaja con el manifiesto (proyecto autogestionado,
/// crecimiento por recomendación humana, no por algoritmo).
Future<void> mostrarSheetDonaciones(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ContenidoSheet(),
  );
}

class _ContenidoSheet extends StatelessWidget {
  const _ContenidoSheet();

  static const String _kofiUrl = 'https://ko-fi.com/codigodespierto';
  static const String _paypalUrl = 'https://www.paypal.com/paypalme/codigodespierto';
  static const String _btcSegwit = 'bc1qjnva46wy92ldhsv4w0j26jmu8c5wm5cxvgdfd7';
  static const String _btcTaproot =
      'bc1p29l9vjelerljlwhg6dhr0uldldus4zgn8vjaecer0spj7273d7rss4gnyk';

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, controladorScroll) => ListView(
        controller: controladorScroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            textos.donationsTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            textos.donationsIntro,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _TarjetaEnlace(
            icono: Icons.local_cafe,
            titulo: 'Ko-fi',
            subtitulo: textos.donationsKofi,
            url: _kofiUrl,
            colorFondo: const Color(0xFFC06A34),
          ),
          const SizedBox(height: 10),
          _TarjetaEnlace(
            icono: Icons.credit_card,
            titulo: 'PayPal',
            subtitulo: textos.donationsPaypal,
            url: _paypalUrl,
            colorFondo: const Color(0xFF2E5CB8),
          ),
          const SizedBox(height: 10),
          _TarjetaBitcoin(
            etiqueta: textos.donationsBitcoinSegwit,
            direccion: _btcSegwit,
            colorFondo: const Color(0xFFB26B19),
          ),
          const SizedBox(height: 10),
          _TarjetaBitcoin(
            etiqueta: textos.donationsBitcoinTaproot,
            direccion: _btcTaproot,
            colorFondo: const Color(0xFFA07818),
          ),
          const SizedBox(height: 24),
          _SeccionCompartir(textos: textos),
          const SizedBox(height: 20),
          _OtrasFormas(textos: textos),
          const SizedBox(height: 16),
          _TarjetaEcosistema(textos: textos),
        ],
      ),
    );
  }
}

/// Enlace a la web de "Colección del Nuevo Ser" indicando que esta app
/// forma parte del mismo ecosistema de proyectos autogestionados.
class _TarjetaEcosistema extends StatelessWidget {
  const _TarjetaEcosistema({required this.textos});
  final AppLocalizations textos;

  static const String _urlColeccion = 'https://coleccion-nuevo-ser.gailu.net/';

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri.parse(_urlColeccion);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: esquema.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textos.ecosistemaTitle,
                      style: TextStyle(
                        color: esquema.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      textos.ecosistemaSubtitle,
                      style: TextStyle(
                        color: esquema.onTertiaryContainer.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: esquema.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaEnlace extends StatelessWidget {
  const _TarjetaEnlace({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.url,
    required this.colorFondo,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String url;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorFondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri == null) return;
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icono, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaBitcoin extends StatelessWidget {
  const _TarjetaBitcoin({
    required this.etiqueta,
    required this.direccion,
    required this.colorFondo,
  });

  final String etiqueta;
  final String direccion;
  final Color colorFondo;

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_bitcoin, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(
                etiqueta,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            direccion,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.copy),
            label: Text(textos.donationsCopyAddress),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: direccion));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(textos.donationsAddressCopied),
                duration: const Duration(seconds: 2),
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _SeccionCompartir extends StatelessWidget {
  const _SeccionCompartir({required this.textos});
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textos.donationsShare,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          textos.donationsShareHelp,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: const Icon(Icons.share),
            label: Text(textos.donationsShareAction),
            onPressed: () {
              Share.share(
                '${textos.donationsShareMessage}\n'
                'https://github.com/JosuIru/flavor-news-hub',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OtrasFormas extends StatelessWidget {
  const _OtrasFormas({required this.textos});
  final AppLocalizations textos;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.star_border, textos.donationsHelpStar),
      (Icons.bug_report_outlined, textos.donationsHelpBug),
      (Icons.translate, textos.donationsHelpTranslate),
      (Icons.code, textos.donationsHelpContribute),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            textos.donationsOtherWays,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final (icono, texto) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(texto)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
