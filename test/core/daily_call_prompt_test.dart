import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/daily_call_prompt.dart';

/// #254: the AI greets first. The system prompt carries a day-aware
/// greeting directive; the app sends a hidden kickoff turn on connect.
void main() {
  group('buildDailyCallPrompt', () {
    test('base prompt is the prefix, greeting section appended', () {
      final p = buildDailyCallPrompt(
        targetDate: DateTime(2026, 7, 15),
        now: DateTime(2026, 7, 15, 9),
      );
      expect(p, startsWith(dailyCallSystemPrompt));
      expect(p, contains('GREETING'));
      expect(p, contains(callKickoff.split(' ').first)); // marker mentioned
    });

    test('morning today', () {
      final p = buildDailyCallPrompt(
        targetDate: DateTime(2026, 7, 15),
        now: DateTime(2026, 7, 15, 8, 30),
      );
      expect(p, contains('It is morning for the user.'));
      expect(p, contains('The user is journaling about today.'));
      expect(p, isNot(contains('acknowledging that day')));
    });

    test('evening today', () {
      final p = buildDailyCallPrompt(
        targetDate: DateTime(2026, 7, 15),
        now: DateTime(2026, 7, 15, 19, 5),
      );
      expect(p, contains('It is evening for the user.'));
    });

    test('past date names the day and asks to acknowledge it', () {
      final p = buildDailyCallPrompt(
        targetDate: DateTime(2026, 7, 3),
        now: DateTime(2026, 7, 15, 14),
      );
      expect(p, contains('It is afternoon for the user.'));
      expect(p, contains('Friday, July 3'));
      expect(p, contains('open by acknowledging that day'));
      expect(p, isNot(contains('journaling about today.')));
    });

    test('boundary hours: 12:00 is afternoon, 17:00 is evening', () {
      expect(
        buildDailyCallPrompt(
          targetDate: DateTime(2026, 7, 15),
          now: DateTime(2026, 7, 15, 12),
        ),
        contains('It is afternoon for the user.'),
      );
      expect(
        buildDailyCallPrompt(
          targetDate: DateTime(2026, 7, 15),
          now: DateTime(2026, 7, 15, 17),
        ),
        contains('It is evening for the user.'),
      );
    });

    test('kickoff constant carries the transcript-filter marker', () {
      expect(callKickoff, startsWith('[session-start]'));
    });
  });
}
