import 'package:flutter/material.dart';

import '../../../core/models/collective.dart';

/// Tarjeta de un colectivo en el directorio. Título + territorio + topics.
/// La descripción no aparece aquí (va en el detalle) para densidad visual.
class CollectiveCard extends StatelessWidget {
  const CollectiveCard({
    required this.colectivo,
    required this.onTap,
    super.key,
  });

  final Collective colectivo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    colectivo.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                  ),
                ),
                if (colectivo.flavorUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Flavor',
                    child: Icon(
                      Icons.hub_outlined,
                      size: 20,
                      color: esquema.primary,
                    ),
                  ),
                ],
              ],
            ),
            if (colectivo.territory.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                colectivo.territory,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
              ),
            ],
            if (colectivo.topics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final topic in colectivo.topics)
                    Chip(
                      label: Text(topic.name),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
