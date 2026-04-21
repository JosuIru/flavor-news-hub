import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/presentation/about_screen.dart';
import '../../features/collectives/presentation/collective_detail_screen.dart';
import '../../features/collectives/presentation/collective_directory_screen.dart';
import '../../features/collectives/presentation/collective_submit_screen.dart';
import '../../features/audio/presentation/audio_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/filters_screen.dart';
import '../../features/feed/presentation/item_detail_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/shell_screen.dart';
import '../../features/history/presentation/guardados_screen.dart';
import '../../features/history/presentation/historial_screen.dart';
import '../../features/history/presentation/tus_intereses_screen.dart';
import '../../features/map/presentation/mapa_screen.dart';
import '../../features/music/presentation/musica_screen.dart';
import '../../features/notifications/presentation/notificaciones_screen.dart';
import '../../features/personal_sources/presentation/mis_medios_screen.dart';
import '../../features/search/presentation/buscador_screen.dart';
import '../../features/sources_filter/presentation/fuentes_preferencias_screen.dart';
import '../../features/videos/presentation/reproductor_video_screen.dart';
import '../../features/videos/presentation/videos_screen.dart';
import '../../features/sources/presentation/source_detail_screen.dart';
import '../../features/sources/presentation/source_submit_screen.dart';

/// Configuración de rutas con `go_router`.
///
/// - ShellRoute envuelve las 3 destinaciones con `NavigationBar` inferior
///   (Feed, Directorio, Ajustes).
/// - Las pantallas de detalle y el formulario de alta quedan fuera del
///   shell: ocupan la pantalla completa, con el back button del sistema.
final enrutadorProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScreen(
          rutaActual: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(child: FeedScreen()),
          ),
          GoRoute(
            path: '/audio',
            pageBuilder: (context, state) => const NoTransitionPage(child: AudioScreen()),
          ),
          // Alias legacy: deep-links antiguos a `/radios` entran directos a
          // la pestaña Audio. El shell detecta ambas rutas como mismo tab.
          GoRoute(
            path: '/radios',
            pageBuilder: (context, state) => const NoTransitionPage(child: AudioScreen()),
          ),
          GoRoute(
            path: '/collectives',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CollectiveDirectoryScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const BuscadorScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapaScreen(),
      ),
      GoRoute(
        path: '/music',
        builder: (context, state) => const MusicaScreen(),
      ),
      GoRoute(
        path: '/filters',
        builder: (context, state) => const FiltersScreen(),
      ),
      GoRoute(
        path: '/items/:id',
        builder: (context, state) => ItemDetailScreen(
          idItem: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/sources/submit',
        builder: (context, state) => SourceSubmitScreen(
          urlInicial: state.uri.queryParameters['url'],
        ),
      ),
      GoRoute(
        path: '/mis-medios',
        builder: (context, state) => const MisMediosScreen(),
      ),
      GoRoute(
        path: '/fuentes-preferencias',
        builder: (context, state) => const FuentesPreferenciasScreen(),
      ),
      GoRoute(
        path: '/notificaciones',
        builder: (context, state) => const NotificacionesScreen(),
      ),
      GoRoute(
        path: '/guardados',
        builder: (context, state) => const GuardadosScreen(),
      ),
      GoRoute(
        path: '/historial',
        builder: (context, state) => const HistorialScreen(),
      ),
      GoRoute(
        path: '/tus-intereses',
        builder: (context, state) => const TusInteresesScreen(),
      ),
      GoRoute(
        path: '/videos',
        builder: (context, state) => const VideosScreen(),
      ),
      GoRoute(
        path: '/videos/play/:id',
        builder: (context, state) => ReproductorVideoScreen(
          idItem: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/sources/:id',
        builder: (context, state) => SourceDetailScreen(
          idSource: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/collectives/submit',
        builder: (context, state) => const CollectiveSubmitScreen(),
      ),
      GoRoute(
        path: '/collectives/:id',
        builder: (context, state) => CollectiveDetailScreen(
          idColectivo: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});
