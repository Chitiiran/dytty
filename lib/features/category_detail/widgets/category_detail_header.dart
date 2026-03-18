import 'package:flutter/material.dart';
import 'package:dytty/core/constants/categories.dart';

/// AppBar-style header for the category detail page.
/// Shows category name, icon with call badge, and back navigation.
class CategoryDetailHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final String categoryId;
  final bool hasRecentEntries;
  final VoidCallback? onCallTap;

  const CategoryDetailHeader({
    super.key,
    required this.categoryId,
    required this.hasRecentEntries,
    this.onCallTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  JournalCategory get _category =>
      JournalCategory.values.firstWhere((c) => c.name == categoryId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = _category;

    return AppBar(
      leading: const BackButton(),
      title: Text(
        category.displayName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _CallBadgeIcon(
            category: category,
            hasRecentEntries: hasRecentEntries,
            onTap: onCallTap,
          ),
        ),
      ],
    );
  }
}

/// Category icon with a small call-status badge overlay.
class _CallBadgeIcon extends StatelessWidget {
  final JournalCategory category;
  final bool hasRecentEntries;
  final VoidCallback? onTap;

  const _CallBadgeIcon({
    required this.category,
    required this.hasRecentEntries,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = hasRecentEntries
        ? Colors.green
        : theme.colorScheme.outline;

    return GestureDetector(
      onTap: hasRecentEntries ? onTap : null,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              category.icon,
              color: category.color,
              size: 28,
            ),
            Positioned(
              right: 2,
              bottom: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
