import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/gemini_llm_service.dart';

void main() {
  group('extractJson', () {
    test('returns raw JSON unchanged', () {
      const input = '{"category": "positive", "summary": "Good day"}';
      expect(extractJson(input), input);
    });

    test('strips ```json fences', () {
      const input = '```json\n{"category": "positive"}\n```';
      expect(extractJson(input), '{"category": "positive"}');
    });

    test('strips ``` fences without language tag', () {
      const input = '```\n{"category": "positive"}\n```';
      expect(extractJson(input), '{"category": "positive"}');
    });

    test('handles extra whitespace around fences', () {
      const input = '  ```json\n  {"category": "positive"}  \n  ```  ';
      expect(extractJson(input), '{"category": "positive"}');
    });

    test('handles multiline JSON inside fences', () {
      const input =
          '```json\n{\n  "category": "positive",\n  "summary": "test"\n}\n```';
      expect(
        extractJson(input),
        '{\n  "category": "positive",\n  "summary": "test"\n}',
      );
    });

    test('trims leading/trailing whitespace on plain JSON', () {
      const input = '  \n {"key": "value"} \n  ';
      expect(extractJson(input), '{"key": "value"}');
    });

    test('returns empty object string unchanged', () {
      const input = '{}';
      expect(extractJson(input), '{}');
    });

    test('returns plain text unchanged when no fences', () {
      const input = 'just some plain text';
      expect(extractJson(input), 'just some plain text');
    });

    test('handles fences with only whitespace content', () {
      const input = '```json\n  \n```';
      expect(extractJson(input), '');
    });
  });

  group('GeminiLlmService', () {
    test('dispose does not throw', () {
      // GeminiLlmService constructor requires a valid API key format but
      // dispose should always succeed since GenerativeModel needs no cleanup.
      final service = GeminiLlmService(apiKey: 'test-api-key');
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
