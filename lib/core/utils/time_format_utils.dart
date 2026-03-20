import 'package:intl/intl.dart';

/// Formats a [DateTime] as a human-readable relative time string.
///
/// Returns:
/// - 'just now' for < 1 minute ago
/// - 'Xm ago' for < 60 minutes ago
/// - 'Xh ago' for < 24 hours ago
/// - 'Xd ago' for < 30 days ago
/// - 'MMM d' (e.g. 'Jan 15') for >= 30 days ago
String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
  final currentTime = now ?? DateTime.now();
  final diff = currentTime.difference(dateTime);

  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dateTime);
}
