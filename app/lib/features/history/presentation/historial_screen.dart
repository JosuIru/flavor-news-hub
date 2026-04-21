import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../feed/presentation/item_card.dart';
import '../data/historial_provider.dart';

/// Pantalla "Historial de lectura": lista de titulares que el usuario ha
/// abierto en algún momento, más reciente primero. Usa la misma tarjeta
/// que el feed — los items ya llevan el flag `estaLeido` por construcción.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncItems = ref.watch(itemsLeidosProvider);
    final guardados = ref.watch(guardadosProvider).valueOrNull ?? const <int>{};
    final utiles = ref.watch(utilesProvider).valueOrNull ?? const <int>{};

    return Scaffold(
      appBar: AppBar(title: Text(textos.historyTitle)),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      textos.historyEmpty,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, indice) {
              final item = items[indice];
              return ItemCard(
                item: item,
                estaGuardado: guardados.contains(item.id),
                esUtil: utiles.contains(item.id),
                estaLeido: true,
                onTap: () => context.push('/items/${item.id}'),
                onSourceTap: (idSource) => context.push('/sources/$idSource'),
                onTopicTap: (_) {},
                onGuardarAlternar: () =>
                    ref.read(guardadosProvider.notifier).alternar(item),
                onUtilAlternar: () =>
                    ref.read(utilesProvider.notifier).alternar(item),
              );
            },
          );
        },
      ),
    );
  }
}
