import 'dart:math';

import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:dytty/data/models/category_config.dart';

/// A radial menu showing category bubbles around a center mic button.
///
/// Category bubbles show entry-count badges (checkmarks) and support
/// archived categories (rendered with muted colors and lower icon opacity).
class CategoryRadialMenu extends StatefulWidget {
  final List<CategoryConfig> categories;
  final Map<String, int> filledCounts;
  final void Function(CategoryConfig category) onCategoryTap;
  final VoidCallback onVoiceTap;

  const CategoryRadialMenu({
    super.key,
    required this.categories,
    required this.filledCounts,
    required this.onCategoryTap,
    required this.onVoiceTap,
  });

  @override
  State<CategoryRadialMenu> createState() => _CategoryRadialMenuState();
}

class _CategoryRadialMenuState extends State<CategoryRadialMenu> {
  final GlobalKey<CircularMenuState> _menuKey = GlobalKey<CircularMenuState>();

  @override
  void initState() {
    super.initState();
    // Auto-open the menu after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _menuKey.currentState?.forwardAnimation();
    });
  }

  String _badgeLabel(int count) {
    if (count == 0) return '';
    if (count == 1) return '\u2713';
    return '\u2713\u2713';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.categories.map((cat) {
      final count = widget.filledCounts[cat.id] ?? 0;
      final isArchived = cat.isArchived;

      return CircularMenuItem(
        icon: cat.icon,
        color: isArchived
            ? Colors.grey.shade700
            : cat.color.withValues(alpha: 0.85),
        iconColor: isArchived ? Colors.grey.shade400 : Colors.white,
        iconSize: 22,
        padding: 12,
        margin: 6,
        enableBadge: count > 0,
        badgeLabel: _badgeLabel(count),
        badgeColor: const Color(0xFF10B981),
        badgeTextColor: Colors.white,
        badgeRadius: 9,
        badgeTextStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: isArchived
                ? Colors.grey.shade900
                : cat.color.withValues(alpha: 0.3),
            blurRadius: 6,
          ),
        ],
        onTap: () => widget.onCategoryTap(cat),
      );
    }).toList();

    // Use 3*pi/2 (= 12 o'clock in clockwise radians from right).
    // When start == end, circular_menu treats it as a full 360-degree circle.
    const startAngle = 3 * pi / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        CircularMenu(
          key: _menuKey,
          alignment: Alignment.center,
          startingAngleInRadian: startAngle,
          endingAngleInRadian: startAngle,
          radius: 80,
          animationDuration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
          toggleButtonColor: Colors.transparent,
          toggleButtonSize: 0.01,
          toggleButtonPadding: 0,
          toggleButtonMargin: 0,
          toggleButtonBoxShadow: const [BoxShadow(color: Colors.transparent)],
          toggleButtonIconColor: Colors.transparent,
          items: items,
        ),
        // Center mic button overlaid on the toggle button
        Semantics(
          label: 'Start voice call',
          button: true,
          excludeSemantics: true,
          child: Material(
            color: Theme.of(context).colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onVoiceTap,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(Icons.mic_rounded, size: 28, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
