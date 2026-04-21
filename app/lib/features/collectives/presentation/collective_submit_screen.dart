import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/models/collective_submission.dart';
import '../../../core/providers/api_provider.dart';

/// Formulario público de alta de colectivo. Llama a `POST /collectives/submit`
/// del backend, que valida, aplica rate-limit por IP (3/hora) y deja la
/// entrada en `pending` hasta verificación manual.
///
/// El campo `website` del modelo `CollectiveSubmission` se envía siempre
/// vacío: es el honeypot que el backend evalúa para descartar bots.
class CollectiveSubmitScreen extends ConsumerStatefulWidget {
  const CollectiveSubmitScreen({super.key});

  @override
  ConsumerState<CollectiveSubmitScreen> createState() => _EstadoCollectiveSubmit();
}

class _EstadoCollectiveSubmit extends ConsumerState<CollectiveSubmitScreen> {
  final _claveFormulario = GlobalKey<FormState>();

  final _controllerNombre = TextEditingController();
  final _controllerDescripcion = TextEditingController();
  final _controllerEmail = TextEditingController();
  final _controllerWebsite = TextEditingController();
  final _controllerTerritorio = TextEditingController();
  final _controllerFlavorUrl = TextEditingController();

  final Set<String> _slugsTopicsSeleccionados = {};
  bool _enviando = false;

  @override
  void dispose() {
    _controllerNombre.dispose();
    _controllerDescripcion.dispose();
    _controllerEmail.dispose();
    _controllerWebsite.dispose();
    _controllerTerritorio.dispose();
    _controllerFlavorUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = AppLocalizations.of(context);
    final asyncTopics = ref.watch(topicsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(textos.submitTitle)),
      body: Form(
        key: _claveFormulario,
        child: AbsorbPointer(
          absorbing: _enviando,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _CampoTexto(
                controller: _controllerNombre,
                label: textos.submitName,
                requerido: true,
                validador: (valor) =>
                    (valor == null || valor.trim().isEmpty) ? textos.submitRequiredName : null,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerDescripcion,
                label: textos.submitDescription,
                requerido: true,
                maxLines: 4,
                validador: (valor) =>
                    (valor == null || valor.trim().isEmpty) ? textos.submitRequiredDescription : null,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerEmail,
                label: textos.submitContactEmail,
                requerido: true,
                tipoTeclado: TextInputType.emailAddress,
                validador: (valor) {
                  if (valor == null || valor.trim().isEmpty) return textos.submitRequiredEmail;
                  final expresionEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!expresionEmail.hasMatch(valor.trim())) return textos.submitRequiredEmail;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerWebsite,
                label: textos.submitWebsite,
                tipoTeclado: TextInputType.url,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerTerritorio,
                label: textos.submitTerritory,
              ),
              const SizedBox(height: 16),
              _CampoTexto(
                controller: _controllerFlavorUrl,
                label: textos.submitFlavorUrl,
                tipoTeclado: TextInputType.url,
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

    final peticion = CollectiveSubmission(
      name: _controllerNombre.text.trim(),
      description: _controllerDescripcion.text.trim(),
      contactEmail: _controllerEmail.text.trim(),
      websiteUrl: _controllerWebsite.text.trim(),
      territory: _controllerTerritorio.text.trim(),
      flavorUrl: _controllerFlavorUrl.text.trim(),
      topics: _slugsTopicsSeleccionados.toList(),
      // honeypot: `website` del modelo queda con el default `''`.
    );

    try {
      final api = ref.read(flavorNewsApiProvider);
      await api.submitCollective(peticion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textos.submitSuccess)),
      );
      context.pop();
    } on FlavorNewsApiException catch (error) {
      if (!mounted) return;
      final mensaje = error.estaRateLimited
          ? textos.submitErrorRateLimited
          : (error.message.isNotEmpty ? error.message : textos.submitErrorGeneric);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
      );
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
  });

  final TextEditingController controller;
  final String label;
  final bool requerido;
  final int maxLines;
  final TextInputType tipoTeclado;
  final String? Function(String?)? validador;

  @override
  Widget build(BuildContext context) {
    final esMultilinea = maxLines > 1;
    return TextFormField(
      controller: controller,
      keyboardType: esMultilinea ? TextInputType.multiline : tipoTeclado,
      maxLines: maxLines,
      minLines: esMultilinea ? maxLines : null,
      textInputAction: esMultilinea ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: requerido ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
      validator: validador,
    );
  }
}
