import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/utils/menu_position_utils.dart';

void main() {
  group('clampMenuPosition', () {
    const screenSize = Size(400, 800);
    const menuSize = 250.0;
    const padding = 16.0;

    test('clamps to top-left boundary when tap is near top-left', () {
      const tapPosition = Offset(10, 10);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(10 - 125, 16, 134) = 16
      // top  = clamp(10 - 125, 16, 534) = 16
      expect(clamped.dx, 16.0);
      expect(clamped.dy, 16.0);
    });

    test('clamps to bottom-right boundary when tap is near bottom-right', () {
      const tapPosition = Offset(390, 790);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(390 - 125, 16, 134) = 134
      // top  = clamp(790 - 125, 16, 534) = 534
      expect(clamped.dx, 134.0);
      expect(clamped.dy, 534.0);
    });

    test('centers on tap when space allows', () {
      const tapPosition = Offset(200, 400);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(200 - 125, 16, 134) = 75
      // top  = clamp(400 - 125, 16, 534) = 275
      expect(clamped.dx, 75.0);
      expect(clamped.dy, 275.0);
    });

    test('clamps left edge only when tap is on left side mid-height', () {
      const tapPosition = Offset(20, 400);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(20 - 125, 16, 134) = 16
      // top  = clamp(400 - 125, 16, 534) = 275
      expect(clamped.dx, 16.0);
      expect(clamped.dy, 275.0);
    });

    test('clamps right edge only when tap is on right side mid-height', () {
      const tapPosition = Offset(380, 400);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(380 - 125, 16, 134) = 134
      // top  = clamp(400 - 125, 16, 534) = 275
      expect(clamped.dx, 134.0);
      expect(clamped.dy, 275.0);
    });

    test('clamps top edge only when tap is at top center', () {
      const tapPosition = Offset(200, 20);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(200 - 125, 16, 134) = 75
      // top  = clamp(20 - 125, 16, 534) = 16
      expect(clamped.dx, 75.0);
      expect(clamped.dy, 16.0);
    });

    test('clamps bottom edge only when tap is at bottom center', () {
      const tapPosition = Offset(200, 780);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: screenSize,
        menuSize: menuSize,
        padding: padding,
      );

      // left = clamp(200 - 125, 16, 134) = 75
      // top  = clamp(780 - 125, 16, 534) = 534
      expect(clamped.dx, 75.0);
      expect(clamped.dy, 534.0);
    });

    test('does not crash on very small screen (smaller than menu)', () {
      // Screen is 200x200 but menu is 250x250 — maxLeft/maxTop would be
      // negative without the safety clamp, causing ArgumentError.
      const tapPosition = Offset(100, 100);
      const smallScreen = Size(200, 200);

      final clamped = clampMenuPosition(
        tapPosition: tapPosition,
        screenSize: smallScreen,
        menuSize: menuSize,
        padding: padding,
      );

      // maxLeft = (200 - 250 - 16).clamp(0, inf) = 0
      // maxTop  = (200 - 250 - 16).clamp(0, inf) = 0
      // left = (100 - 125).clamp(min(16,0), 0) = 0
      // top  = (100 - 125).clamp(min(16,0), 0) = 0
      expect(clamped.dx, 0.0);
      expect(clamped.dy, 0.0);
    });
  });
}
