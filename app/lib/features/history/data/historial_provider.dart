import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import 'base_datos_local.dart';
import 'items_locales_dao.dart';

/// Provider singleton de la BD local. Se abre una vez (async) y se cierra
/// con el ciclo de vida de Riverpod.
final baseDatosLocalProvider = FutureProvider<BaseDatosLocal>((ref) async {
  BaseDatosLocal? base;
  // Registramos el cierre ANTES del primer `await`: si el provider se dispone
  // mientras la apertura está en vuelo, llamar `ref.onDispose` después lanzaría
  // `StateError: Cannot call onDispose after a provider was disposed`. Así el
  // callback queda registrado mientras el provider sigue activo y cierra la BD
  // solo si llegó a abrirse.
  ref.onDispose(() => base?.cerrar());

  base = await BaseDatosLocal.abrir();
  // Purga oportunista al arrancar. Best-effort: si la BD se cerró mientras
  // tanto (el provider se dispuso), las queries lanzan `database_closed`; ese
  // fallo no es crítico (se reintenta en el próximo arranque), así que lo
  // aislamos para que no escape como error asíncrono no manejado.
  final dao = ItemsLocalesDao(base);
  try {
    await dao.purgarCacheAntiguo();
  } catch (e) {
    debugPrint('[baseDatosLocalProvider] purga omitida: $e');
  }
  return base;
});

final itemsLocalesDaoProvider = FutureProvider<ItemsLocalesDao>((ref) async {
  final base = await ref.watch(baseDatosLocalProvider.future);
  return ItemsLocalesDao(base);
});

/// Set de IDs marcados como leídos, para tintar tarjetas en el feed.
class LeidosNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    return dao.obtenerIdsLeidos();
  }

  Future<void> marcarLeido(Item item) async {
    final dao = await ref.read(itemsLocalesDaoProvider.future);
    await dao.marcarLeido(item);
    // Optimismo: actualizamos el set sin re-leer toda la tabla.
    final previo = state.valueOrNull ?? <int>{};
    state = AsyncData({...previo, item.id});
  }
}

final leidosProvider = AsyncNotifierProvider<LeidosNotifier, Set<int>>(LeidosNotifier.new);

/// Set de IDs guardados. Para Toggle rápido desde tarjeta o detalle.
class GuardadosNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    return dao.obtenerIdsGuardados();
  }

  Future<void> alternar(Item item) async {
    final dao = await ref.read(itemsLocalesDaoProvider.future);
    await dao.alternarGuardado(item);
    final previo = state.valueOrNull ?? <int>{};
    final nuevo = {...previo};
    if (nuevo.contains(item.id)) {
      nuevo.remove(item.id);
    } else {
      nuevo.add(item.id);
    }
    state = AsyncData(nuevo);
  }
}

final guardadosProvider =
    AsyncNotifierProvider<GuardadosNotifier, Set<int>>(GuardadosNotifier.new);

/// Lista completa de items guardados, con los datos para renderizarlos
/// aunque ya no estén en el feed del backend.
final itemsGuardadosProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  // Reactivo a cambios en el set de IDs: cuando se guarda/desguarda, se recalcula.
  ref.watch(guardadosProvider);
  final dao = await ref.watch(itemsLocalesDaoProvider.future);
  return dao.obtenerGuardados();
});

/// Lista de items leídos (historial). Reactivo al set de ids leídos para
/// que al marcar uno nuevo se refresque la pantalla.
final itemsLeidosProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  ref.watch(leidosProvider);
  final dao = await ref.watch(itemsLocalesDaoProvider.future);
  return dao.obtenerLeidos();
});

/// Set de IDs marcados como "útiles" por el usuario. Alimenta el panel
/// "Tus intereses" y el botón de útil/no-útil en tarjetas y detalle.
/// **No** reordena el feed — eso iría contra el manifiesto (sin
/// algoritmo de engagement).
class UtilesNotifier extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final dao = await ref.watch(itemsLocalesDaoProvider.future);
    return dao.obtenerIdsUtiles();
  }

  Future<void> alternar(Item item) async {
    final dao = await ref.read(itemsLocalesDaoProvider.future);
    await dao.alternarUtil(item);
    final previo = state.valueOrNull ?? <int>{};
    final nuevo = {...previo};
    if (nuevo.contains(item.id)) {
      nuevo.remove(item.id);
    } else {
      nuevo.add(item.id);
    }
    state = AsyncData(nuevo);
  }
}

final utilesProvider = AsyncNotifierProvider<UtilesNotifier, Set<int>>(UtilesNotifier.new);

/// Lista completa de items marcados útiles, con sus payloads. Reactiva
/// al set de ids para refrescar la pantalla "Tus intereses".
final itemsUtilesProvider = FutureProvider.autoDispose<List<Item>>((ref) async {
  ref.watch(utilesProvider);
  final dao = await ref.watch(itemsLocalesDaoProvider.future);
  return dao.obtenerUtiles();
});
