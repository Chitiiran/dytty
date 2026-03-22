import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/utils/ring_angle_utils.dart';

void main() {
  group('RingAngleUtils', () {
    test('categoryAngle for 5 categories starts at -pi/2 (12 o clock)', () {
      final angle = RingAngleUtils.categoryAngle(index: 0, total: 5);
      final expectedGap = 4 * pi / 180;
      expect(angle, closeTo(-pi / 2 + expectedGap / 2, 0.001));
    });

    test(
      'categoryAngle distributes 5 categories evenly around 360 degrees',
      () {
        final angles = List.generate(
          5,
          (i) => RingAngleUtils.categoryAngle(index: i, total: 5),
        );
        final spacing = angles[1] - angles[0];
        for (int i = 2; i < 5; i++) {
          expect(angles[i] - angles[i - 1], closeTo(spacing, 0.001));
        }
      },
    );

    test('categoryAngle for single category has no gap', () {
      final angle = RingAngleUtils.categoryAngle(index: 0, total: 1);
      expect(angle, closeTo(-pi / 2, 0.001));
    });

    test('categoryAngle for 3 categories produces correct spacing', () {
      final angles = List.generate(
        3,
        (i) => RingAngleUtils.categoryAngle(index: i, total: 3),
      );
      final expectedSpacing = 2 * pi / 3;
      expect(angles[1] - angles[0], closeTo(expectedSpacing, 0.001));
    });

    test('categoryAngle for 7 categories produces correct spacing', () {
      final angles = List.generate(
        7,
        (i) => RingAngleUtils.categoryAngle(index: i, total: 7),
      );
      final expectedSpacing = 2 * pi / 7;
      expect(angles[1] - angles[0], closeTo(expectedSpacing, 0.001));
    });

    test('gapRadians returns 0 for single category', () {
      expect(RingAngleUtils.gapRadians(1), 0.0);
    });

    test('gapRadians returns 4 degrees for multiple categories', () {
      expect(RingAngleUtils.gapRadians(5), closeTo(4 * pi / 180, 0.0001));
    });
  });
}
