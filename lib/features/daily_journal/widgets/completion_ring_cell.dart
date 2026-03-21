import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Describes one segment of the completion ring.
class RingSegment extends Equatable {
  final Color color;
  final bool isFilled;

  const RingSegment({required this.color, required this.isFilled});

  @override
  List<Object?> get props => [color, isFilled];
}

/// Paints a segmented completion ring.
///
/// Each segment occupies an equal arc. Filled segments use [RingSegment.color];
/// unfilled segments use [dimColor]. Segments are separated by small gaps.
class CompletionRingPainter extends CustomPainter {
  final List<RingSegment> segments;
  final double animationProgress;
  final Color dimColor;
  final double strokeWidth;

  /// Gap between segments in radians. For N=1, no gap is applied.
  static const double _gapRadians = 4 * pi / 180; // 4 degrees

  CompletionRingPainter({
    required this.segments,
    required this.animationProgress,
    required this.dimColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final n = segments.length;
    final segmentAngle = 2 * pi / n;
    final gap = n == 1 ? 0.0 : _gapRadians;
    final sweepAngle = segmentAngle - gap;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < n; i++) {
      final segment = segments[i];
      // Start at 12 o'clock (-pi/2), offset by half gap
      final startAngle = -pi / 2 + i * segmentAngle + gap / 2;

      if (segment.isFilled) {
        // Draw dim background for the full sweep first
        final dimPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = dimColor;
        canvas.drawArc(rect, startAngle, sweepAngle, false, dimPaint);

        // Draw filled portion on top, scaled by animation progress
        final fillPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = segment.color;
        canvas.drawArc(
          rect,
          startAngle,
          sweepAngle * animationProgress,
          false,
          fillPaint,
        );
      } else {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = dimColor;
        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CompletionRingPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.segments != segments ||
        oldDelegate.dimColor != dimColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
