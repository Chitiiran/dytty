import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final _schema = S.object(
  properties: {
    'filledCount': S.integer(
      description: 'Number of categories with entries (0-5)',
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
    const total = 5;
    final progress = total > 0 ? filled / total : 0.0;
    final theme = Theme.of(ctx.buildContext);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$filled of $total categories filled',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  },
);
