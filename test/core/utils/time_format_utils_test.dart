import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/utils/time_format_utils.dart';

void main() {
  group('formatRelativeTime', () {
    final now = DateTime(2026, 3, 20, 12, 0, 0);

    test('returns "just now" for time exactly now', () {
      expect(formatRelativeTime(now, now: now), 'just now');
    });

    test('returns "just now" when less than 1 minute ago', () {
      final input = now.subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(input, now: now), 'just now');
    });

    test('returns "1m ago" at exactly 1 minute', () {
      final input = now.subtract(const Duration(minutes: 1));
      expect(formatRelativeTime(input, now: now), '1m ago');
    });

    test('returns "Xm ago" when less than 60 minutes ago', () {
      final input = now.subtract(const Duration(minutes: 15));
      expect(formatRelativeTime(input, now: now), '15m ago');
    });

    test('returns "1h ago" at exactly 1 hour', () {
      final input = now.subtract(const Duration(hours: 1));
      expect(formatRelativeTime(input, now: now), '1h ago');
    });

    test('returns "Xh ago" when less than 24 hours ago', () {
      final input = now.subtract(const Duration(hours: 5));
      expect(formatRelativeTime(input, now: now), '5h ago');
    });

    test('returns "1d ago" at exactly 1 day', () {
      final input = now.subtract(const Duration(days: 1));
      expect(formatRelativeTime(input, now: now), '1d ago');
    });

    test('returns "Xd ago" when less than 30 days ago', () {
      final input = now.subtract(const Duration(days: 10));
      expect(formatRelativeTime(input, now: now), '10d ago');
    });

    test('returns "MMM d" at exactly 30 days', () {
      final input = now.subtract(const Duration(days: 30));
      expect(formatRelativeTime(input, now: now), 'Feb 18');
    });

    test('returns "MMM d" format when more than 30 days ago', () {
      final input = now.subtract(const Duration(days: 90));
      expect(formatRelativeTime(input, now: now), 'Dec 20');
    });

    test('returns "just now" for future timestamps', () {
      final input = now.add(const Duration(minutes: 5));
      expect(formatRelativeTime(input, now: now), 'just now');
    });
  });
}
