import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/preferences_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/api_provider.dart';
import 'features/audio/data/reproductor_episodio_notifier.dart';
import 'features/radios/data/radios_favoritas_notifier.dart';
import 'features/radios/data/reproductor_radio_notifier.dart';
import 'features/deep_links/deep_link_listener.dart';
import 'features/share_intake/share_intake_listener.dart';
import 'features/widgets/widget_favoritos_writer.dart';
import 'features/widgets/widget_musica_writer.dart';
import 'features/widgets/widget_radio_writer.dart';

/// Widget raíz de la app. Escucha preferencias del usuario (tema e idioma
/// de UI) y se regenera cuando cambian.
class FlavorNewsHubApp extends ConsumerWidget {
  const FlavorNewsHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencias = ref.watch(preferenciasProvider);
    final enrutador = ref.watch(enrutadorProvider);

    // Sincroniza el widget Android de radio cada vez que cambia el estado
    // del reproductor. `listen` no rebuilds, sólo reacciona a cambios.
    ref.listen<EstadoReproductor>(reproductorRadioProvider, (_, nuevo) {
      WidgetRadioWriter.escribir(nuevo);
    });

    // El widget de música refleja el reproductor genérico de episodios
    // (pódcast + tracks de Audius/Funkwhale/Jamendo/Archive).
    ref.listen<EstadoReproductorEpisodio>(reproductorEpisodioProvider, (_, nuevo) {
      WidgetMusicaWriter.escribir(nuevo);
    });

    // El widget de favoritos se reescribe cuando cambia el set de IDs o
    // cuando llega la lista de radios del backend/seed.
    ref.listen<Set<int>>(radiosFavoritasProvider, (_, ids) {
      final radios = ref.read(radiosProvider).valueOrNull ?? const [];
      WidgetFavoritosWriter.escribir(ids, radios);
    });
    ref.listen(radiosProvider, (_, nueva) {
      final radios = nueva.valueOrNull ?? const [];
      final ids = ref.read(radiosFavoritasProvider);
      WidgetFavoritosWriter.escribir(ids, radios);
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      darkTheme: AppTheme.oscuro(),
      themeMode: preferencias.modoTema,
      locale: preferencias.codigoIdioma != null ? Locale(preferencias.codigoIdioma!) : null,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: enrutador,
      builder: (context, child) {
        // Respeta la escala de texto del sistema y, encima, aplica la
        // preferencia manual del usuario si difiere de 1.0.
        final mediaQueryOriginal = MediaQuery.of(context);
        final escalaFinal = mediaQueryOriginal.textScaler.scale(1.0) * preferencias.escalaTexto;
        return MediaQuery(
          data: mediaQueryOriginal.copyWith(textScaler: TextScaler.linear(escalaFinal)),
          child: ShareIntakeListener(
            child: DeepLinkListener(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
