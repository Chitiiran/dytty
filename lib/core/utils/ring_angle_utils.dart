import 'dart:math';

/// Shared angle calculation for completion ring and radial menu.
///
/// Both widgets use the same formula so bubbles align with ring segments.
class RingAngleUtils {
  RingAngleUtils._();

  /// Gap between segments in radians. 0 for single category, 4 degrees otherwise.
  static double gapRadians(int total) => total == 1 ? 0.0 : 4 * pi / 180;

  /// Center angle for category at [index] out of [total] categories.
  /// Starts at 12 o'clock (-pi/2), offset by half gap.
  static double categoryAngle({required int index, required int total}) {
    final gap = gapRadians(total);
    final segmentAngle = 2 * pi / total;
    return -pi / 2 + index * segmentAngle + gap / 2;
  }
}
