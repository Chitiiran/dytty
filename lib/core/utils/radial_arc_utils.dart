import 'dart:math';
import 'dart:ui';

/// Geometry for the category radial menu (#190).
///
/// Angles are radians clockwise from +x with y-down screen coordinates,
/// matching circular_menu's convention (12 o'clock = 3*pi/2).

/// Tight radius: the menu hugs the date cell. Clamped so a single
/// category still clears the mic button and large custom category sets
/// stay reachable one-handed.
double menuRadius(int count) => (40 + 7.0 * count).clamp(54.0, 96.0);

/// A contiguous angular window: [start] in radians, [sweep] in radians.
typedef ArcWindow = ({double start, double sweep});

/// Largest contiguous angular window in which a bubble of [bubbleRadius]
/// at [radius] from [center] stays fully on-screen with [padding] from
/// every edge.
///
/// Unconstrained anchors get the full circle starting at 12 o'clock,
/// which reproduces the completion-ring alignment by construction. The
/// degenerate no-angle-fits case (unreachable with the clamped radius on
/// real screens) also falls back to the full circle rather than hiding
/// the menu.
///
/// Implementation samples 1-degree steps: the menu opens once per tap,
/// so 360 trig evaluations beat piecewise interval algebra on
/// robustness with no measurable cost.
ArcWindow visibleArcWindow({
  required Offset center,
  required Size screen,
  required double radius,
  required double bubbleRadius,
  double padding = 16,
}) {
  const samples = 360;
  const fullCircle = (start: 3 * pi / 2, sweep: 2 * pi);
  final lo = padding + bubbleRadius;

  bool fits(double angle) {
    final x = center.dx + radius * cos(angle);
    final y = center.dy + radius * sin(angle);
    return x >= lo &&
        x <= screen.width - lo &&
        y >= lo &&
        y <= screen.height - lo;
  }

  final ok = List.generate(samples, (i) => fits(2 * pi * i / samples));
  if (ok.every((v) => v)) return fullCircle;
  if (!ok.any((v) => v)) return fullCircle;

  // Longest circular run of fitting samples.
  var bestStart = 0;
  var bestLen = 0;
  var i = 0;
  while (i < samples) {
    if (!ok[i]) {
      i++;
      continue;
    }
    var j = i;
    var len = 0;
    while (len < samples && ok[j % samples]) {
      j++;
      len++;
    }
    if (len > bestLen) {
      bestLen = len;
      bestStart = i;
    }
    i = j > i ? j : i + 1;
  }

  // A bubble's own angular footprint at this radius.
  final bubbleAngularWidth = 2 * asin((bubbleRadius / radius).clamp(0.0, 1.0));

  // Blocked slice narrower than one bubble: endpoint-inclusive placement
  // across that sliver puts the first and last bubbles nearly on top of
  // each other (review finding). Snap to the full circle — the worst
  // bubble intrudes less than bubbleRadius into the padding margin while
  // staying fully on-screen.
  final blocked = 2 * pi * (samples - bestLen) / samples;
  if (blocked < bubbleAngularWidth) return fullCircle;

  // The run's last FITTING sample is bestStart + bestLen - 1 (review
  // finding: bestLen samples span bestLen - 1 steps). No further inset
  // is needed: fits() constrains bubble CENTERS to the padded region,
  // so endpoint bubbles already keep their full footprint plus padding.
  return (
    start: 2 * pi * bestStart / samples,
    sweep: 2 * pi * (bestLen - 1) / samples,
  );
}

/// Even bubble distribution across [window]. Full circles space by
/// sweep/count from the window start (no duplicated endpoint); partial
/// arcs include both endpoints.
List<double> bubbleAngles(int count, ArcWindow window) {
  if (count <= 0) return const [];
  if (count == 1) return [window.start + window.sweep / 2];
  final full = window.sweep >= 2 * pi - 1e-6;
  final step = full ? window.sweep / count : window.sweep / (count - 1);
  return [for (var i = 0; i < count; i++) window.start + step * i];
}
