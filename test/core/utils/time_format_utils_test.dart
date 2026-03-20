import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/utils/time_format_utils.dart';

void main() {
  group('formatRelativeTime', () {
    test('returns "just now" when less than 1 minute ago', () {
      final dateTime = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(dateTime), 'just now');
    });

    test('returns "Xm ago" when less than 60 minutes ago', () {
      final dateTime = DateTime.now().subtract(const Duration(minutes: 15));
      expect(formatRelativeTime(dateTime), '15m ago');
    });

    test('returns "1m ago" at exactly 1 minute', () {
      final dateTime = DateTime.now().subtract(const Duration(minutes: 1));
      expect(formatRelativeTime(dateTime), '1m ago');
    });

    test('returns "Xh ago" when less than 24 hours ago', () {
      final dateTime = DateTime.now().subtract(const Duration(hours: 5));
      expect(formatRelativeTime(dateTime), '5h ago');
    });

    test('returns "1h ago" at exactly 1 hour', () {
      final dateTime = DateTime.now().subtract(const Duration(hours: 1));
      expect(formatRelativeTime(dateTime), '1h ago');
    });

    test('returns "Xd ago" when less than 30 days ago', () {
      final dateTime = DateTime.now().subtract(const Duration(days: 10));
      expect(formatRelativeTime(dateTime), '10d ago');
    });

    test('returns "1d ago" at exactly 1 day', () {
      final dateTime = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeTime(dateTime), '1d ago');
    });

    test('returns "MMM d" format when 30 or more days ago', () {
      final dateTime = DateTime(2025, 1, 15);
      final result = formatRelativeTime(dateTime);
      expect(result, 'Jan 15');
    });

    test('returns "just now" for time exactly now', () {
      final dateTime = DateTime.now();
      expect(formatRelativeTime(dateTime), 'just now');
    });
  });
}
