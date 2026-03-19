import 'package:flutter/material.dart';

/// Collapsible header for a date-grouped list of entries.
/// Shows relative date, entry count, and an animated chevron.
class DateGroupHeader extends StatelessWidget {
  final String displayDate;
  final int entryCount;
  final bool isCollapsed;
  final VoidCallback onTap;

  const DateGroupHeader({
    super.key,
    required this.displayDate,
    required this.entryCount,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = entryCount == 1 ? '1 entry' : '$entryCount entries';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              displayDate,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              countLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: isCollapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
