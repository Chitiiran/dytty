import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/data/models/review_summary.dart';

/// Card displaying the weekly review summary for a category.
/// Uses a category-colored left border accent.
class ReviewSummaryCard extends StatelessWidget {
  final ReviewSummary summary;
  final String categoryId;

  const ReviewSummaryCard({
    super.key,
    required this.summary,
    required this.categoryId,
  });

  JournalCategory get _category =>
      JournalCategory.values.firstWhere((c) => c.name == categoryId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _category;
    final reviewDate = DateFormat('MMM d, yyyy').format(summary.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: category.color,
              width: 4,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: category.color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Weekly Review',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: category.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviewed on $reviewDate',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
