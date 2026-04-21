import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/source_submission.dart';
import '../../../core/providers/api_provider.dart';

/// Formulario público para proponer un medio.
///
/// Envía un POST a `/sources/submit` que el backend procesa: rate-limit
/// por IP, honeypot y validación. El medio queda en `pending` y aparecerá
/// en el feed sólo cuando un verificador humano lo active desde el admin.
class SourceSubmitScreen extends ConsumerStatefulWidget {
  const SourceSubmitScreen({this.urlInicial, super.key});

  /// URL a pre-rellenar en el campo `feed_url`. Llega cuando el usuario
  /// comparte un enlace desde otra app vía intent SEND.
  final String? urlInicial;

  @override
  ConsumerState<SourceSubmitScreen> createState() => _EstadoSourceSubmit();
}

class _EstadoSourceSubmit extends ConsumerState<SourceSubmitScreen> {
  final _claveFormulario = GlobalKey<FormState>();

  final _controllerNombre = TextEditingController();
  final _controllerFeedUrl = TextEditingController();
  final _controllerEmail = TextEditingController();
  final _controllerDescripcion = TextEditingController();
  final _controllerWebsite = TextEditingController();
  final _controllerTerritorio = TextEditingController();

  String _tipoFeedSeleccionado = 'rss';
  final Set<String> _idiomasSeleccionados = {};
  final Set<String> _slugsTopicsSeleccionados = {};
  bool _enviando = false;

  static const List<_OpcionTipoFeed> _tiposFeedDisponibles = [
    _OpcionTipoFeed(codigo: 'rss', etiqueta: 'RSS'),
    _OpcionTipoFeed(codigo: 'atom', etiqueta: 'Atom'),
    _OpcionTipoFeed(codigo: 'youtube', etiqueta: 'YouTube'),
    _OpcionTipoFeed(codigo: 'mastodon', etiqueta: 'Mastodon'),
    _OpcionTipoFeed(codigo: 'podcast', etiqueta: 'Podcast'),
  ];

  static const List<_OpcionIdiomaChip> _idiomasDisponibles = [
    _OpcionIdiomaChip(codigo: 'es', etiqueta: 'Castellano'),
    _OpcionIdiomaChip(codigo: 'ca', etiqueta: 'Català'),
    _OpcionIdiomaChip(codigo: 'eu', etiqueta: 'Euskara'),
    _OpcionIdiomaChip(codigo: 'gl', etiqueta: 'Galego'),
    _OpcionIdiomaChip(codigo: 'en', etiqueta: 'English'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.urlInicial != null && widget.urlInicial!.isNotEmpty) {
      _controllerFeedUrl.text = widget.urlInicial!;
    }
  }

  @override
  void dispose() {
    _controllerNombre.dispose();
    _controllerFeedUrl.dispose();
    _controllerEmail.dispose();
    _controllerDescripcion.dispose();
    _controllerWebsite.dispose();
    _controllerTerritorio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final asyncTopics = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(textos.sourceSubmitTitle)),
      body: Form(
        key: _claveFormulario,
        child: AbsorbPointer(
          absorbing: _enviando,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                textos.sourceSubmitIntro,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _CampoTexto(
                controller: _controllerNombre,
                label: textos.sourceSubmitName,
                requerido: true,
                validador: (v) =>
                    (v == null || v.trim().isEmpty) ? textos.submitRequiredName : null,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerFeedUrl,
                label: textos.sourceSubmitFeedUrl,
                requerido: true,
                tipoTeclado: TextInputType.url,
                ayuda: textos.sourceSubmitFeedUrlHelp,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return textos.sourceSubmitRequiredFeedUrl;
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
                    return textos.sourceSubmitInvalidFeedUrl;
                  }
                  if (!uri.hasAuthority) return textos.sourceSubmitInvalidFeedUrl;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                textos.sourceSubmitFeedType,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final opcion in _tiposFeedDisponibles)
                    ChoiceChip(
                      label: Text(opcion.etiqueta),
                      selected: _tipoFeedSeleccionado == opcion.codigo,
                      onSelected: (_) => setState(() => _tipoFeedSeleccionado = opcion.codigo),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerEmail,
                label: textos.submitContactEmail,
                requerido: true,
                tipoTeclado: TextInputType.emailAddress,
                ayuda: textos.sourceSubmitEmailHelp,
                validador: (v) {
                  if (v == null || v.trim().isEmpty) return textos.submitRequiredEmail;
                  final expr = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!expr.hasMatch(v.trim())) return textos.submitRequiredEmail;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerDescripcion,
                label: textos.sourceSubmitDescription,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerWebsite,
                label: textos.sourceSubmitWebsiteUrl,
                tipoTeclado: TextInputType.url,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerTerritorio,
                label: textos.sourceSubmitTerritory,
              ),
              const SizedBox(height: 24),
              Text(
                textos.sourceSubmitLanguages,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final opcion in _idiomasDisponibles)
                    FilterChip(
                      label: Text(opcion.etiqueta),
                      selected: _idiomasSeleccionados.contains(opcion.codigo),
                      onSelected: (seleccionado) {
                        setState(() {
                          if (seleccionado) {
                            _idiomasSeleccionados.add(opcion.codigo);
                          } else {
                            _idiomasSeleccionados.remove(opcion.codigo);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                textos.submitTopics,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              asyncTopics.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => Text(textos.feedError),
                data: (topics) => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final topic in topics)
                      FilterChip(
                        label: Text(topic.name),
                        selected: _slugsTopicsSeleccionados.contains(topic.slug),
                        onSelected: (seleccionado) {
                          setState(() {
                            if (seleccionado) {
                              _slugsTopicsSeleccionados.add(topic.slug);
                            } else {
                              _slugsTopicsSeleccionados.remove(topic.slug);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _enviando ? null : _enviarFormulario,
                icon: _enviando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(textos.submitSend),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviarFormulario() async {
    final textos = AppLocalizations.of(context);
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    setState(() => _enviando = true);

    final peticion = SourceSubmission(
      name: _controllerNombre.text.trim(),
      feedUrl: _controllerFeedUrl.text.trim(),
      contactEmail: _controllerEmail.text.trim(),
      feedType: _tipoFeedSeleccionado,
      description: _controllerDescripcion.text.trim(),
      websiteUrl: _controllerWebsite.text.trim(),
      territory: _controllerTerritorio.text.trim(),
      languages: _idiomasSeleccionados.toList(),
      topics: _slugsTopicsSeleccionados.toList(),
      // honeypot vacío por default
    );

    try {
      final api = ref.read(flavorNewsApiProvider);
      await api.submitSource(peticion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.sourceSubmitSuccess)),
      );
      context.pop();
    } on FlavorNewsApiException catch (error) {
      if (!mounted) return;
      final mensaje = error.estaRateLimited
          ? textos.submitErrorRateLimited
          : (error.message.isNotEmpty ? error.message : textos.submitErrorGeneric);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.submitErrorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.controller,
    required this.label,
    this.requerido = false,
    this.maxLines = 1,
    this.tipoTeclado = TextInputType.text,
    this.validador,
    this.ayuda,
  });

  final TextEditingController controller;
  final String label;
  final bool requerido;
  final int maxLines;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    final esMultilinea = maxLines > 1;
    final tieneAyuda = ayuda != null && ayuda!.isNotEmpty;
    return TextFormField(
      controller: controller,
      keyboardType: esMultilinea ? TextInputType.multiline : tipoTeclado,
      maxLines: maxLines,
      // `minLines` sólo si hay más de una línea — si no, dejamos el
      // comportamiento por defecto y evitamos asserts del framework.
      minLines: esMultilinea ? maxLines : null,
      textInputAction: esMultilinea ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: requerido ? '$label *' : label,
        helperText: ayuda,
        // `helperMaxLines` sin `helperText` puede generar layouts inesperados.
        helperMaxLines: tieneAyuda ? 3 : null,
        border: const OutlineInputBorder(),
      ),
      validator: validador,
    );
  }
}

class _OpcionTipoFeed {
  const _OpcionTipoFeed({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}

class _OpcionIdiomaChip {
  const _OpcionIdiomaChip({required this.codigo, required this.etiqueta});
  final String codigo;
  final String etiqueta;
}
