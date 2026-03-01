import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:dytty/core/constants/categories.dart';

final _schema = S.object(
  properties: {
    'filledCount': S.integer(
      description: 'Number of categories with entries (0-5)',
    ),
    'filledCategories': S.list(
      description:
          'Which categories are filled (e.g. ["positive", "gratitude"])',
      items: S.string(
        enumValues: [
          'positive',
          'negative',
          'gratitude',
          'beauty',
          'identity',
        ],
      ),
    ),
  },
  required: ['filledCount'],
);

final progressCardItem = CatalogItem(
  name: 'ProgressCard',
  dataSchema: _schema,
  widgetBuilder: (CatalogItemContext ctx) {
    final json = ctx.data as Map<String, Object?>;
    final filled = (json['filledCount'] as num?)?.toInt() ?? 0;
    final filledNames =
        (json['filledCategories'] as List?)?.cast<String>() ?? [];
    const total = 5;
    final progress = total > 0 ? filled / total : 0.0;
    final theme = Theme.of(ctx.buildContext);

    String message;
    if (filled == 0) {
      message = 'Start your daily reflection';
    } else if (filled < total) {
      message =
          'Keep going! ${total - filled} ${total - filled == 1 ? 'category' : 'categories'} left';
    } else {
      message = 'All categories complete!';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  "Today's Progress",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '$filled/$total',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Category icons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: JournalCategory.values.map((cat) {
                final isFilled = filledNames.contains(cat.name);
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? cat.color.withValues(alpha: 0.15)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        cat.icon,
                        size: 20,
                        color: isFilled
                            ? cat.color
                            : theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isFilled)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                color: filled == total
                    ? const Color(0xFF10B981)
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  },
);
