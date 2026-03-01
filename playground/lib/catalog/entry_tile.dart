import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _schema = S.object(
  properties: {
    'text': S.string(description: 'The journal entry text'),
    'timestamp': S.string(description: 'Relative time like "2h ago"'),
  },
  required: ['text'],
);

final entryTileItem = CatalogItem(
  name: 'EntryTile',
  dataSchema: _schema,
  widgetBuilder: (CatalogItemContext ctx) {
    final json = ctx.data as Map<String, Object?>;
    final text = json['text'] as String? ?? '';
    final timestamp = json['timestamp'] as String? ?? '';
    final theme = Theme.of(ctx.buildContext);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyMedium),
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: () {},
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: () {},
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  },
);
