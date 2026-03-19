/// Returns the Monday of the week containing [date].
/// Dart's [DateTime.weekday] uses ISO 8601: Monday = 1, Sunday = 7.
DateTime mondayOfWeek(DateTime date) {
  final weekday = date.weekday; // Monday = 1
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}
