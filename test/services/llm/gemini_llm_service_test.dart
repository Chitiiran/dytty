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
  });
}
