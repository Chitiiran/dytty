import 'dart:math';

import 'package:flutter/material.dart';
import 'package:dytty/core/utils/radial_arc_utils.dart';
import 'package:dytty/data/models/category_config.dart';

/// A radial menu showing category bubbles fanned around a center mic
/// button.
///
/// Bubbles are positioned by [bubbleAngles] across [window] at [radius]
/// (#190) — laid out in-house because circular_menu normalizes angles
/// into [0, 2pi) and rejects windows that wrap through zero, which is
/// exactly what edge and corner cells need. Owning the layout also lets
/// every bubble carry a proper [Semantics] label.
///
/// Category bubbles show entry-count badges (checkmarks) and support
/// archived categories (rendered with muted colors).
class CategoryRadialMenu extends StatefulWidget {
  final List<CategoryConfig> categories;
  final Map<String, int> filledCounts;
  final void Function(CategoryConfig category) onCategoryTap;
  final VoidCallback onVoiceTap;

  /// Distance of bubble centers from the menu center.
  final double radius;

  /// Angular window (radians, clockwise from +x; 12 o'clock = 3*pi/2).
  final ArcWindow window;

  const CategoryRadialMenu({
    super.key,
    required this.categories,
    required this.filledCounts,
    required this.onCategoryTap,
    required this.onVoiceTap,
    required this.radius,
    required this.window,
  });

  @override
  State<CategoryRadialMenu> createState() => _CategoryRadialMenuState();
}

class _CategoryRadialMenuState extends State<CategoryRadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // No reverseCurve: dismissal is instant route removal, the
    // controller never reverses.
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _badgeLabel(int count) {
    if (count <= 0) return '';
    return count >= 2 ? '✓✓' : '✓';
  }

  Widget _bubble(CategoryConfig cat) {
    final count = widget.filledCounts[cat.id] ?? 0;
    final isArchived = cat.isArchived;

    return Semantics(
      label: 'Add ${cat.displayName} entry from menu',
      button: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ink paints the fill on the Material itself, so ripples
            // render ABOVE the color instead of hiding beneath an opaque
            // Container (review finding). Shadow lives on an outer
            // DecoratedBox — Ink decorations may not paint shadows.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isArchived
                        ? Colors.grey.shade900
                        : cat.color.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onCategoryTap(cat),
                  child: Ink(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isArchived
                          ? Colors.grey.shade700
                          : cat.color.withValues(alpha: 0.85),
                    ),
                    child: Center(
                      child: Icon(
                        cat.icon,
                        size: 22,
                        color: isArchived ? Colors.grey.shade400 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Inside the 48dp box, clearly overlapping the circle — at
            // the box corner the badge only grazes it tangentially, and
            // protruding past the box collides with neighbors/chrome
            // (owner-verify findings).
            if (count > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  // Stadium, not circle: '✓✓' is wider than tall and a
                  // forced circle clips it (review finding).
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.all(Radius.circular(9)),
                  ),
                  child: Text(
                    _badgeLabel(count),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final angles = bubbleAngles(widget.categories.length, widget.window);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < widget.categories.length; i++)
              Transform.translate(
                offset: Offset(
                  widget.radius * _animation.value * cos(angles[i]),
                  widget.radius * _animation.value * sin(angles[i]),
                ),
                child: Opacity(
                  opacity: _animation.value,
                  child: _bubble(widget.categories[i]),
                ),
              ),
            // Center mic button: visually cell-sized (~40dp circle) so the
            // date stays the anchor, with a 48dp tap target (#190).
            Semantics(
              label: 'Start voice call',
              button: true,
              excludeSemantics: true,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onVoiceTap,
                    // Ink keeps the ripple visible over the fill (review
                    // finding); the visual circle stays ~40dp inside the
                    // 48dp tap target.
                    child: Center(
                      child: Ink(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.mic_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
