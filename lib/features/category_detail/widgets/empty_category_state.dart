import 'package:flutter/material.dart';
import 'package:dytty/core/constants/categories.dart';

/// Empty state shown when a category has no entries.
/// Displays a large faded category icon and an encouraging message.
class EmptyCategoryState extends StatelessWidget {
  final String categoryId;

  const EmptyCategoryState({
    super.key,
    required this.categoryId,
  });

  JournalCategory get _category => JournalCategory.values.firstWhere(
        (c) => c.name == categoryId,
        orElse: () => JournalCategory.positive,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _category;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              category.icon,
              size: 80,
              color: category.color.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No entries yet for ${category.displayName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reflections will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
