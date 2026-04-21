import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/api_provider.dart';
import 'flavor_models.dart';
import 'flavor_platform_client.dart';

/// Cliente de Flavor Platform compartido (reutiliza el http.Client del core).
final flavorPlatformClientProvider = Provider<FlavorPlatformClient>((ref) {
  final http = ref.watch(httpClientProvider);
  return FlavorPlatformClient(httpClient: http);
});

/// Actividad pública del nodo al que apunta `flavorUrl`. Auto-dispose:
/// al salir de la ficha del colectivo, se libera y la siguiente vista la
/// vuelve a pedir (política live, no cache).
final actividadFlavorProvider = FutureProvider.autoDispose
    .family<ActividadNodoFlavor, String>((ref, flavorUrl) async {
  if (flavorUrl.isEmpty) return ActividadNodoFlavor.vacia;
  final client = ref.watch(flavorPlatformClientProvider);
  return client.fetchActividad(flavorUrl);
});
