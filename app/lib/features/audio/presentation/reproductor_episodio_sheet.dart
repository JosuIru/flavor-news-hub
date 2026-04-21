import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../../history/data/historial_provider.dart';
import '../data/reproductor_episodio_notifier.dart';

/// Bottom sheet no-modal (persistente) para el reproductor de audio.
///
/// El sheet lee el estado del `reproductorEpisodioProvider` globalmente:
/// no guarda un track "propio". Si el caller ya arrancó una cola antes de
/// abrir el sheet (caso música), el sheet se limita a reflejar lo que suena.
/// Si se abre "solo" (caso pódcast tras tap en un programa), arranca el
/// track que recibe como argumento si no hay nada sonando aún.
class ReproductorEpisodioSheet extends ConsumerStatefulWidget {
  const ReproductorEpisodioSheet({required this.episodio, super.key});
  final Item episodio;

  @override
  ConsumerState<ReproductorEpisodioSheet> createState() => _EstadoSheet();
}

class _EstadoSheet extends ConsumerState<ReproductorEpisodioSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final estadoActual = ref.read(reproductorEpisodioProvider);
      // Si ya está sonando el episodio con el que nos abren (o uno de su
      // cola), no lo pisamos — respetamos la cola ya establecida.
      if (estadoActual.episodioActual?.id != widget.episodio.id) {
        ref.read(reproductorEpisodioProvider.notifier).reproducir(widget.episodio);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final esquema = Theme.of(context).colorScheme;
    final estado = ref.watch(reproductorEpisodioProvider);
    // Preferimos el episodio que está sonando de verdad (puede haber
    // cambiado por autoplay de cola), y sólo caemos al inicial si nada.
    final episodio = estado.episodioActual ?? widget.episodio;
    final reproduciendo = estado.estado == EstadoEpisodio.reproduciendo;
    final pausado = estado.estado == EstadoEpisodio.pausado;
    final cargando = estado.estado == EstadoEpisodio.cargando;

    final posicionActual = estado.posicion;
    final duracionTotal = estado.duracion;
    final hayCola = estado.cola.length > 1;

    return SafeArea(
      child: SingleChildScrollView(
        // Scroll defensivo: en pantallas bajas (o con la barra de
        // navegación por gestos que come 7px) el contenido se desborda
        // un poco. Flutter marca "BOTTOM OVERFLOWED BY N PIXELS" en
        // debug — feo y visible. Con SingleChildScrollView el sheet
        // absorbe esa diferencia sin pintar rayas.
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.podcasts),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    episodio.source?.name ?? '',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hayCola)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${estado.indiceEnCola + 1}/${estado.cola.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                    ),
                  ),
                Consumer(
                  builder: (context, ref, _) {
                    final guardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
                    final estaGuardado = guardados.contains(episodio.id);
                    return IconButton(
                      icon: Icon(
                        estaGuardado ? Icons.favorite : Icons.favorite_border,
                        color: estaGuardado ? esquema.primary : null,
                      ),
                      tooltip: estaGuardado
                          ? AppLocalizations.of(context).itemUnsave
                          : AppLocalizations.of(context).itemSave,
                      onPressed: () =>
                          ref.read(guardadosProvider.notifier).alternar(episodio),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              episodio.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (duracionTotal > Duration.zero)
              Slider(
                value: _valorSeguroSlider(posicionActual, duracionTotal),
                min: 0,
                max: duracionTotal.inMilliseconds.toDouble(),
                onChanged: (valor) {
                  ref
                      .read(reproductorEpisodioProvider.notifier)
                      .saltar(Duration(milliseconds: valor.toInt()));
                },
              )
            else
              const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatear(posicionActual)),
                  Text(duracionTotal > Duration.zero ? _formatear(duracionTotal) : '--:--'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hayCola)
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: estado.tienePrevio
                        ? () => ref.read(reproductorEpisodioProvider.notifier).previo()
                        : null,
                  )
                else
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.replay_10),
                    onPressed: () => ref
                        .read(reproductorEpisodioProvider.notifier)
                        .saltar(posicionActual - const Duration(seconds: 10)),
                  ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: cargando
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        )
                      : IconButton.filled(
                          iconSize: 44,
                          icon: Icon(reproduciendo ? Icons.pause : Icons.play_arrow),
                          onPressed: () {
                            final notifier = ref.read(reproductorEpisodioProvider.notifier);
                            if (reproduciendo) {
                              notifier.pausar();
                            } else if (pausado) {
                              notifier.reanudar();
                            } else {
                              notifier.reproducir(widget.episodio);
                            }
                          },
                        ),
                ),
                const SizedBox(width: 16),
                if (hayCola)
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.skip_next),
                    // Siempre habilitado cuando hay cola: si no hay siguiente
                    // cargado, el notifier pedirá más al proveedor (artista
                    // → género) y avanzará cuando lleguen.
                    onPressed: () =>
                        ref.read(reproductorEpisodioProvider.notifier).siguiente(),
                  )
                else
                  IconButton(
                    iconSize: 36,
                    icon: const Icon(Icons.forward_30),
                    onPressed: () => ref
                        .read(reproductorEpisodioProvider.notifier)
                        .saltar(posicionActual + const Duration(seconds: 30)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BotonVelocidad(velocidad: estado.velocidad),
                _BotonSleepTimer(restante: estado.sleepTimerRestante),
              ],
            ),
            if (estado.mensajeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  textos.radiosStreamError,
                  style: TextStyle(color: esquema.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Evita que el Slider reciba un valor fuera de [0, max] si la duración
  /// llega antes que la primera posición.
  double _valorSeguroSlider(Duration posicion, Duration duracion) {
    final ms = posicion.inMilliseconds.toDouble();
    final max = duracion.inMilliseconds.toDouble();
    if (ms.isNaN || ms < 0) return 0;
    if (ms > max) return max;
    return ms;
  }

  String _formatear(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (horas > 0) return '$horas:$minutos:$segundos';
    return '$minutos:$segundos';
  }
}

/// Chip que abre un menú para elegir la velocidad de reproducción.
class _BotonVelocidad extends ConsumerWidget {
  const _BotonVelocidad({required this.velocidad});
  final double velocidad;

  static const _opciones = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<double>(
      tooltip: AppLocalizations.of(context).playerSpeed,
      onSelected: (v) =>
          ref.read(reproductorEpisodioProvider.notifier).cambiarVelocidad(v),
      itemBuilder: (_) => [
        for (final o in _opciones)
          PopupMenuItem(
            value: o,
            child: Row(
              children: [
                Icon(
                  o == velocidad ? Icons.check : Icons.speed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text('${o}x'),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: const Icon(Icons.speed, size: 16),
        label: Text('${velocidad}x'),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Chip con sleep timer. Muestra la cuenta atrás en mm:ss cuando está
/// activo; al pulsarlo abre el menú para elegir duración o cancelarlo.
class _BotonSleepTimer extends ConsumerWidget {
  const _BotonSleepTimer({required this.restante});
  final Duration? restante;

  static const _opcionesMin = <int>[5, 15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final activo = restante != null;
    return PopupMenuButton<int>(
      tooltip: textos.playerSleepTimer,
      onSelected: (minutos) async {
        final notif = ref.read(reproductorEpisodioProvider.notifier);
        if (minutos == 0) {
          notif.cancelarSleepTimer();
        } else {
          await notif.programarSleepTimer(Duration(minutes: minutos));
        }
      },
      itemBuilder: (_) => [
        if (activo)
          PopupMenuItem(
            value: 0,
            child: Row(
              children: const [
                Icon(Icons.cancel_outlined, size: 18),
                SizedBox(width: 8),
                Text('Cancelar'),
              ],
            ),
          ),
        for (final m in _opcionesMin)
          PopupMenuItem(
            value: m,
            child: Text('$m min'),
          ),
      ],
      child: Chip(
        avatar: Icon(
          activo ? Icons.bedtime : Icons.bedtime_outlined,
          size: 16,
        ),
        label: Text(
          activo
              ? _formatearRestante(restante!)
              : textos.playerSleepTimer,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _formatearRestante(Duration d) {
    final minutos = d.inMinutes;
    final segundos = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutos:$segundos';
  }
}
