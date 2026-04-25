import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// URL pública del repositorio del proyecto. Si el proyecto se mueve, se
/// cambia aquí; no hace falta reenlazarlo en ningún sitio más.
const String _urlRepositorioProyecto = 'https://github.com/JosuIru/flavor-news-hub';
const String _urlLicenciaAgpl = 'https://www.gnu.org/licenses/agpl-3.0.html';
const String _urlManifiesto =
    'https://github.com/JosuIru/flavor-news-hub/blob/main/MANIFESTO.md';

final _paqueteInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final asyncInfo = ref.watch(_paqueteInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(textos.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            textos.appName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            textos.appTagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          _Seccion(titulo: textos.aboutManifestoHeader, children: [
            Text(textos.aboutManifestoBody, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            const _BotonEnlaceExterno(
              icono: Icons.article_outlined,
              etiqueta: 'Leer el manifiesto completo',
              url: _urlManifiesto,
            ),
          ]),

          const SizedBox(height: 24),
          const _Seccion(titulo: 'Principios irrenunciables', children: [
            _PrincipioItem(texto: 'Sin algoritmo de engagement.'),
            _PrincipioItem(texto: 'Sin tracking, sin publicidad, sin telemetría.'),
            _PrincipioItem(texto: 'Sin dark patterns.'),
            _PrincipioItem(texto: 'Transparencia editorial de las fuentes.'),
            _PrincipioItem(texto: 'Apropiabilidad (AGPL-3.0): cualquier colectivo puede autohospedarla.'),
            _PrincipioItem(texto: 'Multilingüe desde el día 1: castellano, catalán, euskera, gallego, inglés.'),
            _PrincipioItem(texto: 'Accesibilidad real.'),
            _PrincipioItem(texto: 'Sencillez antes que features.'),
          ]),

          const SizedBox(height: 24),
          _Seccion(titulo: 'Proyecto', children: [
            // Botón "Compartir app": abre el chooser nativo con un
            // mensaje completo (descripción + URL de releases/latest +
            // pasos de instalación). El usuario natural llega a
            // "Acerca de" cuando ha decidido recomendar el proyecto;
            // tener el share aquí ahorra una visita a Ajustes.
            OutlinedButton.icon(
              onPressed: () => Share.share(textos.shareAppMessage),
              icon: const Icon(Icons.ios_share),
              label: Text(textos.settingsShareApp),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            _BotonEnlaceExterno(
              icono: Icons.code,
              etiqueta: textos.aboutRepository,
              url: _urlRepositorioProyecto,
            ),
            const SizedBox(height: 8),
            _BotonEnlaceExterno(
              icono: Icons.gavel_outlined,
              etiqueta: '${textos.aboutLicense}: AGPL-3.0',
              url: _urlLicenciaAgpl,
            ),
            const SizedBox(height: 8),
            _BotonEnlaceExterno(
              icono: Icons.auto_awesome,
              etiqueta: textos.ecosistemaTitle,
              url: 'https://coleccion-nuevo-ser.gailu.net/',
            ),
          ]),

          const SizedBox(height: 24),
          _Seccion(titulo: textos.privacyPolicyTitle, children: const [
            _PrincipioItem(texto: 'Qué datos salen del dispositivo: SÓLO las peticiones HTTP a la instancia backend configurada (titulares, medios, colectivos, radios) y, al reproducir, a los streams de audio/vídeo de los medios originales. Nada más.'),
            _PrincipioItem(texto: 'Qué NO hacemos: no enviamos telemetría, no usamos cookies de terceros, no tenemos SDKs de analytics, no hay servidores push propios, no identificamos el dispositivo.'),
            _PrincipioItem(texto: 'Qué se guarda localmente: historial de lectura, guardados, preferencias, fuentes personales, favoritos de radios y canales. Todo en tu dispositivo. Puedes borrarlo con "Vaciar datos" desde Ajustes de Android.'),
            _PrincipioItem(texto: 'Servicios de terceros implicados al usarlos explícitamente: YouTube (al reproducir un vídeo), Audius/Funkwhale/Jamendo/Archive.org (al buscar o escuchar música), tile servers de OpenStreetMap (al abrir el mapa), Bandcamp (si añades un feed). Cada uno recibe sólo lo que su protocolo requiere.'),
            _PrincipioItem(texto: 'Notificaciones: locales, sin servidor push. Si las activas, la app consulta directamente el backend cada N minutos; la notificación se arma en el dispositivo.'),
            _PrincipioItem(texto: 'No hay cuentas, no hay login, no hay identificadores únicos.'),
          ]),

          const SizedBox(height: 24),
          _Seccion(titulo: textos.settingsVersion, children: [
            asyncInfo.when(
              loading: () => const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Text('—'),
              data: (info) => Text(
                '${info.version}+${info.buildNumber}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _PrincipioItem extends StatelessWidget {
  const _PrincipioItem({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _BotonEnlaceExterno extends StatelessWidget {
  const _BotonEnlaceExterno({
    required this.icono,
    required this.etiqueta,
    required this.url,
  });

  final IconData icono;
  final String etiqueta;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      icon: Icon(icono),
      label: Text(etiqueta),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
