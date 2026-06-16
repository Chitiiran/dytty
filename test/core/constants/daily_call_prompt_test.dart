import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/daily_call_prompt.dart';

void main() {
  group('dailyCallSystemPrompt', () {
    test('is non-empty', () {
      expect(dailyCallSystemPrompt, isNotEmpty);
    });

    test('includes key behavioral instructions', () {
      // These are the critical rules that address #122.
      // If someone edits the prompt, these should survive.
      expect(dailyCallSystemPrompt, contains('follow-up'));
      expect(dailyCallSystemPrompt, contains('save_entry'));
      expect(dailyCallSystemPrompt, contains('NEVER'));
      expect(dailyCallSystemPrompt, contains('Multi-category'));
    });

    test('mentions all 5 journal categories', () {
      expect(dailyCallSystemPrompt, contains('positive'));
      expect(dailyCallSystemPrompt, contains('negative'));
      expect(dailyCallSystemPrompt, contains('gratitude'));
      expect(dailyCallSystemPrompt, contains('beauty'));
      expect(dailyCallSystemPrompt, contains('identity'));
    });

    test('includes #231 questioning-restraint guardrails', () {
      final p = dailyCallSystemPrompt;
      // 2:1 reflection-to-question ratio
      expect(p, contains('at least TWICE as often as questions'));
      // never ask "why"
      expect(p.toLowerCase(), contains('never ask "why"'));
      // don't end every turn on a question
      expect(p, contains('Do NOT end every turn on a question'));
      // backchannels for pauses
      expect(p, contains('backchannel'));
      // ask only when genuinely unclear
      expect(p, contains('genuinely unclear'));
    });
  });

  group('dailyCallMinimalPrompt', () {
    test('is non-empty', () {
      expect(dailyCallMinimalPrompt.trim(), isNotEmpty);
    });

    test('is shorter than detailed prompt', () {
      expect(
        dailyCallMinimalPrompt.length,
        lessThan(dailyCallSystemPrompt.length),
      );
    });

    test('is different from detailed prompt', () {
      expect(dailyCallMinimalPrompt, isNot(equals(dailyCallSystemPrompt)));
    });
  });
}
