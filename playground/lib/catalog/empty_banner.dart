import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _schema = S.object(
  properties: {
    'title': S.string(description: 'Bold heading text (e.g. "Time to reflect")'),
    'subtitle': S.string(
      description: 'Supporting text (e.g. "Tap + on any category to start writing.")',
    ),
  },
  required: ['title', 'subtitle'],
);

final emptyBannerItem = CatalogItem(
  name: 'EmptyBanner',
  dataSchema: _schema,
  widgetBuilder: (CatalogItemContext ctx) {
    final json = ctx.data as Map<String, Object?>;
    final title = json['title'] as String? ?? 'Time to reflect';
    final subtitle = json['subtitle'] as String? ??
        'Tap + on any category to start writing.';
    final theme = Theme.of(ctx.buildContext);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);
