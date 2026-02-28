import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _schema = S.object(
  properties: {
    'text': S.string(description: 'The journal entry text'),
    'timestamp': S.string(description: 'Relative time like "2h ago"'),
    'categoryColor': S.string(
      description: 'Hex color string like "#4CAF50"',
    ),
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
    final colorHex = json['categoryColor'] as String?;
    final dotColor = colorHex != null && colorHex.startsWith('#')
        ? Color(int.parse('FF${colorHex.substring(1)}', radix: 16))
        : null;
    final theme = Theme.of(ctx.buildContext);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: dotColor),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (timestamp.isNotEmpty)
                  Text(
                    timestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () {},
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () {},
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  },
);
