import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Filtro local del feed para "ver sólo este medio". A diferencia de
/// topics, territorio e idiomas — que viven en
/// `filtrosTransversalesProvider` y se comparten con todas las pestañas
/// que los toleren — el filtro de source es propio del Feed (Vídeos
/// tiene el suyo, TV no tiene). Se invalida al limpiar todos los
/// filtros de la sección o al pulsar la X del chip.
final feedSourceFilterProvider = StateProvider<int?>((_) => null);
