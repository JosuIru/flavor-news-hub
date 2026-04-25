import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/movimientos_provider.dart';

/// Sección dedicada a "voces de movimiento": items de medios y
/// colectivos pequeños/militantes que en el feed general quedan
/// tapados por agregadores prolíficos. Dar visibilidad sin manipular
/// el feed principal — es una pestaña separada con scroll propio.
///
/// El criterio editorial vive en `_fnh_es_movimiento` por source en
/// el backend; el admin puede activar/desactivar el flag por medio.
class MovimientosScreen extends ConsumerWidget {
  const MovimientosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncItems = ref.watch(feedMovimientosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(textos.movimientosTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: textos.searchTooltip,
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(feedMovimientosProvider),
        child: asyncItems.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(e.toString(), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          textos.movimientosEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, indice) {
                if (indice == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      textos.movimientosSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                final item = items[indice - 1];
                final fuente = item.source?.name ?? '';
                return ListTile(
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: fuente.isEmpty
                      ? null
                      : Text(fuente, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/items/${item.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
