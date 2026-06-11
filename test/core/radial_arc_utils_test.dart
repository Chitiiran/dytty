import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/utils/radial_arc_utils.dart';
import 'package:dytty/core/utils/ring_angle_utils.dart';

void main() {
  const screen = Size(400, 800);
  const bubble = 24.0;

  group('menuRadius (#190)', () {
    test('scales with count', () {
      expect(menuRadius(2), 54);
      expect(menuRadius(3), 61);
      expect(menuRadius(5), 75);
    });

    test('clamps to [54, 96]', () {
      expect(menuRadius(1), 54);
      expect(menuRadius(12), 96);
    });
  });

  group('visibleArcWindow (#190)', () {
    test('mid-screen yields a full circle starting at 12 o\'clock', () {
      final w = visibleArcWindow(
        center: const Offset(200, 400),
        screen: screen,
        radius: 75,
        bubbleRadius: bubble,
      );
      expect(w.sweep, closeTo(2 * pi, 0.05));
      expect(w.start, closeTo(3 * pi / 2, 0.05));
    });

    test('left-edge cell opens rightward with roughly half a circle', () {
      final w = visibleArcWindow(
        center: const Offset(30, 400),
        screen: screen,
        radius: 75,
        bubbleRadius: bubble,
      );
      expect(w.sweep, lessThan(1.2 * pi));
      expect(w.sweep, greaterThan(0.7 * pi));
      final mid = w.start + w.sweep / 2;
      expect(cos(mid), greaterThan(0.7), reason: 'window must face right');
    });

    test('bottom-left corner yields a narrow arc opening up-right', () {
      final w = visibleArcWindow(
        center: const Offset(30, 770),
        screen: screen,
        radius: 75,
        bubbleRadius: bubble,
      );
      expect(w.sweep, lessThan(0.8 * pi));
      final mid = w.start + w.sweep / 2;
      expect(cos(mid), greaterThan(0.3), reason: 'window must face right');
      expect(sin(mid), lessThan(-0.3), reason: 'window must face up (y-down)');
    });

    test('every bubble position stays on-screen across anchors and counts', () {
      for (final cx in [30.0, 100.0, 200.0, 370.0]) {
        for (final cy in [30.0, 200.0, 400.0, 770.0]) {
          for (var n = 2; n <= 8; n++) {
            final r = menuRadius(n);
            final w = visibleArcWindow(
              center: Offset(cx, cy),
              screen: screen,
              radius: r,
              bubbleRadius: bubble,
            );
            for (final a in bubbleAngles(n, w)) {
              final p = Offset(cx + r * cos(a), cy + r * sin(a));
              expect(
                p.dx,
                inInclusiveRange(bubble, screen.width - bubble),
                reason: 'anchor ($cx,$cy) n=$n angle=$a',
              );
              expect(
                p.dy,
                inInclusiveRange(bubble, screen.height - bubble),
                reason: 'anchor ($cx,$cy) n=$n angle=$a',
              );
            }
          }
        }
      }
    });
  });

  group('bubbleAngles (#190)', () {
    test('full circle: even spacing from start, no duplicated endpoint', () {
      const w = (start: 3 * pi / 2, sweep: 2 * pi);
      final a = bubbleAngles(5, w);
      expect(a.length, 5);
      expect(a[0], closeTo(3 * pi / 2, 1e-9));
      expect(a[1] - a[0], closeTo(2 * pi / 5, 1e-9));
    });

    test('partial arc: endpoints inclusive', () {
      const w = (start: 0.0, sweep: pi);
      final a = bubbleAngles(3, w);
      expect(a[0], closeTo(0, 1e-9));
      expect(a[1], closeTo(pi / 2, 1e-9));
      expect(a[2], closeTo(pi, 1e-9));
    });

    test('single bubble sits at the window midpoint', () {
      final a = bubbleAngles(1, (start: 0.0, sweep: pi));
      expect(a.single, closeTo(pi / 2, 1e-9));
    });

    test('full circle reproduces completion-ring alignment within the gap', () {
      // Ring segments start at -pi/2 with a half-gap offset; the menu fan
      // starts at 3*pi/2 (same direction mod 2*pi). Bubbles must stay
      // within the ring gap of their segment's start angle.
      const n = 5;
      final a = bubbleAngles(n, (start: 3 * pi / 2, sweep: 2 * pi));
      final gap = RingAngleUtils.gapRadians(n);
      for (var i = 0; i < n; i++) {
        final ringAngle = RingAngleUtils.categoryAngle(index: i, total: n);
        final diff = (a[i] - ringAngle) % (2 * pi);
        final wrapped = min(diff, 2 * pi - diff);
        expect(
          wrapped,
          lessThanOrEqualTo(gap),
          reason: 'bubble $i drifted from its ring segment',
        );
      }
    });
  });
}
