import 'package:flutter/material.dart';

class AudioFiltersHeader extends StatelessWidget {
  const AudioFiltersHeader({
    required this.title,
    required this.topicLabel,
    required this.languageLabel,
    required this.clearLabel,
    required this.activeTopicsCount,
    required this.activeLanguagesCount,
    required this.onOpenFilters,
    required this.onClearFilters,
    super.key,
  });

  final String title;
  final String topicLabel;
  final String languageLabel;
  final String clearLabel;
  final int activeTopicsCount;
  final int activeLanguagesCount;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;

  bool get _hayFiltros => activeTopicsCount > 0 || activeLanguagesCount > 0;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Material(
        color: esquema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 18, color: esquema.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  ),
                  IconButton(
                    onPressed: onOpenFilters,
                    icon: const Icon(Icons.tune),
                    tooltip: title,
                  ),
                  if (_hayFiltros)
                    TextButton(
                      onPressed: onClearFilters,
                      child: Text(clearLabel),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    label: '$topicLabel · $activeTopicsCount',
                    active: activeTopicsCount > 0,
                  ),
                  _Pill(
                    label: '$languageLabel · $activeLanguagesCount',
                    active: activeLanguagesCount > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? esquema.primaryContainer : esquema.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
