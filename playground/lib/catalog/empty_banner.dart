import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _schema = S.object(
  properties: {
    'message': S.string(
      description: 'Motivational message for empty state',
    ),
  },
  required: ['message'],
);

final emptyBannerItem = CatalogItem(
  name: 'EmptyBanner',
  dataSchema: _schema,
  widgetBuilder: (CatalogItemContext ctx) {
    final json = ctx.data as Map<String, Object?>;
    final message = json['message'] as String? ??
        'Start your day by reflecting on each category. '
            'Tap + to add your first entry.';
    final theme = Theme.of(ctx.buildContext);

    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
