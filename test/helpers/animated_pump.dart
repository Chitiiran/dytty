import 'package:flutter_test/flutter_test.dart';

/// Helpers for testing widgets with animations, gestures, and timed interactions.
///
/// Use these instead of [pumpAndSettle] when widgets have looping animations,
/// physics-based animations, or repeating effects that never "settle."
extension AnimatedPump on WidgetTester {
  /// Pumps frames for [duration], then pumps one final frame.
  ///
  /// Unlike [pumpAndSettle], this doesn't wait for all animations to stop —
  /// it advances time by a fixed amount. Use this for widgets with looping
  /// animations (pulse, shimmer, orbit) or physics-based animations.
  ///
  /// Default 500ms is enough for most enter/exit transitions.
  Future<void> pumpFor({Duration duration = const Duration(milliseconds: 500)}) async {
    await pump(duration);
    await pump();
  }

  /// Simulates a long press at the center of [finder], holds for [holdDuration],
  /// then releases. Pumps frames during the hold to allow animation updates.
  ///
  /// Use for tap-and-hold interactions (e.g., radial menus, orbiting buttons).
  Future<void> longPressAndHold(
    Finder finder, {
    Duration holdDuration = const Duration(milliseconds: 600),
  }) async {
    final center = getCenter(finder);
    final gesture = await startGesture(center);
    await pumpFor(duration: holdDuration);
    await gesture.up();
    await pump();
  }

  /// Simulates a long press, holds, then drags to [offset] before releasing.
  ///
  /// Useful for testing drag-from-hold gestures (e.g., selecting an orbiting
  /// button by dragging to it after long-pressing the source).
  Future<void> longPressDragAndRelease(
    Finder finder, {
    required Offset offset,
    Duration holdDuration = const Duration(milliseconds: 600),
    Duration dragDuration = const Duration(milliseconds: 300),
  }) async {
    final center = getCenter(finder);
    final gesture = await startGesture(center);
    await pumpFor(duration: holdDuration);
    await gesture.moveTo(center + offset);
    await pumpFor(duration: dragDuration);
    await gesture.up();
    await pump();
  }
}
