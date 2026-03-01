import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/theme/app_colors.dart';

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
    final categoryName = json['category'] as String? ?? 'positive';
    final entries =
        (json['entries'] as List?)?.cast<Map<String, Object?>>() ?? [];

    final category = JournalCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => JournalCategory.positive,
    );

    final theme = Theme.of(ctx.buildContext);
    final brightness = theme.brightness;
    final surfaceColor = AppColors.categorySurface(category.name, brightness);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: category.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tinted header strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(category.icon, size: 18, color: category.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Entry count badge
                if (entries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entries.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: category.color,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () {},
                  tooltip: 'Add entry',
                  color: category.color,
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      category.prompt,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ...entries.map((entry) {
                  final text = entry['text'] as String? ?? '';
                  final timestamp = entry['timestamp'] as String? ?? '';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(text,
                                  style: theme.textTheme.bodyMedium),
                              if (timestamp.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  timestamp,
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    color: theme
                                        .colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () {},
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {},
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
