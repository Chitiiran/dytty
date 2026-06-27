import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/daily_call_prompt.dart';

void main() {
  test(
    'prompt instructs multiple save_entry calls for multi-item utterances',
    () {
      final p = dailyCallSystemPrompt.toLowerCase();
      expect(p, contains('save_entry'));
      expect(p, contains('each'));
      expect(p, contains('incomplete'));
    },
  );
}
