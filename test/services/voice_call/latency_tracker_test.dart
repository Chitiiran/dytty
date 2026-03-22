import 'package:dytty/services/voice_call/latency_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LatencyTracker tracker;

  setUp(() {
    tracker = LatencyTracker();
  });

  group('LatencyTracker', () {
    test('p50 and p95 return null when empty', () {
      expect(tracker.p50, isNull);
      expect(tracker.p95, isNull);
    });

    test('p50 and p95 with single measurement', () {
      tracker.add(150);
      expect(tracker.p50, 150);
      expect(tracker.p95, 150);
    });

    test('p50 is median of odd count', () {
      // Sorted: [100, 200, 300]
      tracker.add(200);
      tracker.add(100);
      tracker.add(300);
      expect(tracker.p50, 200);
    });

    test('p50 is upper-middle of even count', () {
      // Sorted: [100, 200, 300, 400] → ceil(3 * 0.5) = 2 → value 300
      tracker.add(300);
      tracker.add(100);
      tracker.add(400);
      tracker.add(200);
      expect(tracker.p50, 300);
    });

    test('p95 picks 95th percentile (ceil for small N accuracy)', () {
      // 20 values: 10, 20, ..., 200
      // 95th percentile index = ceil(19 * 0.95) = 19 → value 200
      for (var i = 1; i <= 20; i++) {
        tracker.add(i * 10);
      }
      expect(tracker.p95, 200);
    });

    test('measurements getter returns defensive copy', () {
      tracker.add(100);
      expect(tracker.measurements, [100]);
      final copy = List<int>.of(tracker.measurements);
      copy.add(999); // mutating the copy
      expect(tracker.measurements, [100]); // original unchanged
    });

    test('measurements getter is unmodifiable', () {
      tracker.add(100);
      expect(() => tracker.measurements.add(999), throwsUnsupportedError);
    });

    test('reset clears all data', () {
      tracker.add(100);
      tracker.add(200);
      tracker.reset();
      expect(tracker.p50, isNull);
      expect(tracker.p95, isNull);
      expect(tracker.measurements, isEmpty);
    });
  });
}
