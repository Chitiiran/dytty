import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

const _categoryColors = {
  'positive': Color(0xFFFFC107),
  'negative': Color(0xFF3F51B5),
  'gratitude': Color(0xFF4CAF50),
  'beauty': Color(0xFFE91E63),
  'identity': Color(0xFF00BCD4),
};

const _categoryIcons = {
  'positive': '\u2600',
  'negative': '\u2601',
  'gratitude': '\uD83D\uDE4F',
  'beauty': '\u273F',
  'identity': '\u25C9',
};

const _categoryLabels = {
  'positive': 'Positive Things',
  'negative': 'Negative Things',
  'gratitude': 'Gratitude',
  'beauty': 'Beauty',
  'identity': 'Identity',
};

final _schema = S.object(
  properties: {
    'category': S.string(
      description: 'One of: positive, negative, gratitude, beauty, identity',
      enumValues: ['positive', 'negative', 'gratitude', 'beauty', 'identity'],
    ),
    'entries': S.list(
      description: 'Journal entries for this category',
      items: S.object(
        properties: {
          'text': S.string(description: 'The journal entry text'),
          'timestamp': S.string(description: 'Relative time like "2h ago"'),
        },
        required: ['text'],
      ),
    ),
  },
  required: ['category'],
);

final categoryCardItem = CatalogItem(
  name: 'CategoryCard',
  dataSchema: _schema,
  widgetBuilder: (CatalogItemContext ctx) {
    final json = ctx.data as Map<String, Object?>;
    final category = json['category'] as String? ?? 'positive';
    final entries =
        (json['entries'] as List?)?.cast<Map<String, Object?>>() ?? [];
    final color = _categoryColors[category] ?? Colors.grey;
    final icon = _categoryIcons[category] ?? '?';
    final label = _categoryLabels[category] ?? category;
    final theme = Theme.of(ctx.buildContext);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {},
                    tooltip: 'Add entry',
                  ),
                ],
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Tap + to add your first entry',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...entries.map((entry) {
                  final text = entry['text'] as String? ?? '';
                  final timestamp = entry['timestamp'] as String? ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(Icons.circle, size: 6),
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
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  },
);
