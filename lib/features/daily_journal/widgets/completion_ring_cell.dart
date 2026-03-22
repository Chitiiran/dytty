import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:dytty/core/utils/ring_angle_utils.dart';
import 'package:dytty/data/models/category_config.dart';

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
    final gap = RingAngleUtils.gapRadians(n);
    final sweepAngle = segmentAngle - gap;

    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < n; i++) {
      final segment = segments[i];
      final startAngle = RingAngleUtils.categoryAngle(index: i, total: n);

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

/// A calendar date cell with a completion ring showing category fill state.
class CompletionRingCell extends StatefulWidget {
  final DateTime day;
  final Map<String, int>? categoryMarkers;
  final List<CategoryConfig> activeCategories;
  final bool isSelected;
  final bool isToday;

  const CompletionRingCell({
    super.key,
    required this.day,
    required this.categoryMarkers,
    required this.activeCategories,
    this.isSelected = false,
    this.isToday = false,
  });

  @override
  State<CompletionRingCell> createState() => _CompletionRingCellState();
}

class _CompletionRingCellState extends State<CompletionRingCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(CompletionRingCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryMarkers != widget.categoryMarkers) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<RingSegment> _buildSegments() {
    return widget.activeCategories.map((config) {
      final count = widget.categoryMarkers?[config.id] ?? 0;
      return RingSegment(color: config.color, isFilled: count > 0);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _buildSegments();
    final dimColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    TextStyle textStyle = TextStyle(
      fontSize: 14,
      color: theme.colorScheme.onSurface,
    );
    if (widget.isSelected) {
      textStyle = textStyle.copyWith(
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.w700,
      );
    } else if (widget.isToday) {
      textStyle = textStyle.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: segments.isNotEmpty
              ? CompletionRingPainter(
                  segments: segments,
                  animationProgress: _animation.value,
                  dimColor: dimColor,
                  strokeWidth: 3.0,
                )
              : null,
          child: child,
        );
      },
      child: Container(
        decoration: widget.isSelected
            ? BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              )
            : widget.isToday
            ? BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              )
            : null,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(4),
        child: Text('${widget.day.day}', style: textStyle),
      ),
    );
  }
}
