import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/daily_journal/widgets/completion_ring_cell.dart';

void main() {
  group('CompletionRingPainter', () {
    test('shouldRepaint returns true when segments change', () {
      final painter1 = CompletionRingPainter(
        segments: const [RingSegment(color: Colors.amber, isFilled: true)],
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final painter2 = CompletionRingPainter(
        segments: const [RingSegment(color: Colors.amber, isFilled: false)],
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when animationProgress changes', () {
      const segments = [RingSegment(color: Colors.amber, isFilled: true)];
      final painter1 = CompletionRingPainter(
        segments: segments,
        animationProgress: 0.5,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final painter2 = CompletionRingPainter(
        segments: segments,
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      const segments = [RingSegment(color: Colors.amber, isFilled: true)];
      final painter1 = CompletionRingPainter(
        segments: segments,
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final painter2 = CompletionRingPainter(
        segments: segments,
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('paints without error for 0 segments', () {
      final painter = CompletionRingPainter(
        segments: const [],
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(40, 40));
      recorder.endRecording();
    });

    test('paints without error for 1 segment (no gap)', () {
      final painter = CompletionRingPainter(
        segments: const [RingSegment(color: Colors.amber, isFilled: true)],
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(40, 40));
      recorder.endRecording();
    });

    test('paints without error for 5 segments partial fill', () {
      final painter = CompletionRingPainter(
        segments: const [
          RingSegment(color: Colors.amber, isFilled: true),
          RingSegment(color: Colors.indigo, isFilled: false),
          RingSegment(color: Colors.green, isFilled: true),
          RingSegment(color: Colors.pink, isFilled: false),
          RingSegment(color: Colors.cyan, isFilled: true),
        ],
        animationProgress: 1.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(40, 40));
      recorder.endRecording();
    });

    test('paints without error for 7 segments', () {
      final painter = CompletionRingPainter(
        segments: List.generate(
          7,
          (i) => RingSegment(color: Colors.primaries[i], isFilled: i.isEven),
        ),
        animationProgress: 0.5,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(40, 40));
      recorder.endRecording();
    });

    test('paints without error at animation progress 0', () {
      final painter = CompletionRingPainter(
        segments: const [
          RingSegment(color: Colors.amber, isFilled: true),
          RingSegment(color: Colors.indigo, isFilled: true),
        ],
        animationProgress: 0.0,
        dimColor: Colors.grey,
        strokeWidth: 3.0,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(40, 40));
      recorder.endRecording();
    });
  });

  group('RingSegment', () {
    test('equality works correctly', () {
      expect(
        const RingSegment(color: Colors.amber, isFilled: true),
        const RingSegment(color: Colors.amber, isFilled: true),
      );
    });

    test('inequality when isFilled differs', () {
      expect(
        const RingSegment(color: Colors.amber, isFilled: true),
        isNot(const RingSegment(color: Colors.amber, isFilled: false)),
      );
    });

    test('inequality when color differs', () {
      expect(
        const RingSegment(color: Colors.amber, isFilled: true),
        isNot(const RingSegment(color: Colors.red, isFilled: true)),
      );
    });
  });
}
