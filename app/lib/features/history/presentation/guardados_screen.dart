import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/item.dart';
import '../../audio/presentation/reproductor_episodio_sheet.dart';
import '../../feed/presentation/item_card.dart';
import '../data/historial_provider.dart';

/// Lista de items guardados, separada en dos pestañas:
///  - **Titulares**: artículos/noticias (sin `audioUrl`).
///  - **Mi audio**: episodios de pódcast + canciones de música (con `audioUrl`).
///
/// La partición se hace client-side sobre la misma lista que sirve el DAO;
/// así mantenemos una única tabla de persistencia pero la UX queda clara.
/// Filtro de texto libre sobre Guardados. Compartido entre ambas tabs.
final filtroGuardadosProvider = StateProvider<String>((_) => '');

class GuardadosScreen extends ConsumerStatefulWidget {
  const GuardadosScreen({super.key});

  @override
  ConsumerState<GuardadosScreen> createState() => _EstadoGuardados();
}

class _EstadoGuardados extends ConsumerState<GuardadosScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(filtroGuardadosProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(textos.savedTitle),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.article_outlined), text: textos.savedTabNews),
              Tab(icon: const Icon(Icons.music_note), text: textos.savedTabAudio),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _controller,
                onChanged: (v) =>
                    ref.read(filtroGuardadosProvider.notifier).state = v,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: textos.savedSearchHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _controller.clear();
                            ref.read(filtroGuardadosProvider.notifier).state = '';
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _ListaGuardados(soloAudio: false),
                  _ListaGuardados(soloAudio: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaGuardados extends ConsumerWidget {
  const _ListaGuardados({required this.soloAudio});
  final bool soloAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = AppLocalizations.of(context);
    final asyncItems = ref.watch(itemsGuardadosProvider);
    final leidos = ref.watch(leidosProvider).valueOrNull ?? const <int>{};

    return asyncItems.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString(), textAlign: TextAlign.center),
        ),
      ),
      data: (todos) {
        final filtro = ref.watch(filtroGuardadosProvider).trim().toLowerCase();
        final items = todos.where((i) {
          final esAudio = i.audioUrl.isNotEmpty;
          if (soloAudio != esAudio) return false;
          if (filtro.isEmpty) return true;
          final fuente = (i.source?.name ?? '').toLowerCase();
          return i.title.toLowerCase().contains(filtro) ||
              fuente.contains(filtro);
        }).toList();
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    soloAudio ? Icons.music_off : Icons.bookmark_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    soloAudio ? textos.savedAudioEmpty : textos.savedEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }
        if (soloAudio) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, indice) => _FilaAudioGuardado(
              item: items[indice],
              onDesguardar: () =>
                  ref.read(guardadosProvider.notifier).alternar(items[indice]),
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
              estaGuardado: true,
              estaLeido: leidos.contains(item.id),
              onTap: () => context.push('/items/${item.id}'),
              onSourceTap: (idSource) => context.push('/sources/$idSource'),
              onTopicTap: (_) {
                // En la lista de guardados no aplicamos filtro al feed.
              },
              onGuardarAlternar: () =>
                  ref.read(guardadosProvider.notifier).alternar(item),
            );
          },
        );
      },
    );
  }
}

/// Fila específica para contenido de audio: reproduce in-app en el sheet
/// del reproductor en vez de abrir un detalle de noticia.
class _FilaAudioGuardado extends StatelessWidget {
  const _FilaAudioGuardado({required this.item, required this.onDesguardar});

  final Item item;
  final VoidCallback onDesguardar;

  @override
  Widget build(BuildContext context) {
    final localeCodigo = Localizations.localeOf(context).toLanguageTag();
    final fecha = DateTime.tryParse(item.publishedAt);
    final fechaTexto = fecha != null
        ? DateFormat.yMMMd(localeCodigo).format(fecha.toLocal())
        : '';
    final subt = [
      item.source?.name ?? '',
      if (fechaTexto.isNotEmpty) fechaTexto,
    ].where((s) => s.isNotEmpty).join(' · ');
    return ListTile(
      leading: item.mediaUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                item.mediaUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
              ),
            )
          : const Icon(Icons.music_note),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subt.isNotEmpty ? Text(subt, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: IconButton(
        icon: const Icon(Icons.favorite),
        onPressed: onDesguardar,
      ),
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => ReproductorEpisodioSheet(episodio: item),
        );
      },
    );
  }
}
