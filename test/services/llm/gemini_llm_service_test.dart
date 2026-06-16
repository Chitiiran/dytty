import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/gemini_llm_service.dart';
import 'package:dytty/services/llm/llm_service.dart';

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

  group('parseReconcileArray', () {
    test('maps JSON array of {category,text,quote} to add items', () {
      final json = jsonEncode([
        {
          'category': 'negative',
          'text': 'Work was brutal today.',
          'quote': 'work was brutal',
        },
        {
          'category': 'gratitude',
          'text': 'Grateful my sister called.',
          'quote': 'sister called',
        },
      ]);
      final items = parseReconcileArray(json);
      expect(items.length, 2);
      expect(items[0].action, ReconcileAction.add);
      expect(items[0].category, 'negative');
      expect(items[0].text, 'Work was brutal today.');
      expect(items[0].sourceTranscript, 'work was brutal');
      expect(items[1].category, 'gratitude');
    });

    test('drops items with empty text', () {
      final json = jsonEncode([
        {'category': 'positive', 'text': '', 'quote': 'x'},
        {'category': 'positive', 'text': 'Real item.', 'quote': 'y'},
      ]);
      expect(parseReconcileArray(json).length, 1);
    });

    test('defaults invalid category to positive', () {
      final json = jsonEncode([
        {'category': 'not_a_category', 'text': 'Item.', 'quote': 'z'},
      ]);
      expect(parseReconcileArray(json).single.category, 'positive');
    });

    test('tolerates markdown-fenced JSON array', () {
      const fenced =
          '```json\n[{"category":"beauty","text":"Sunset.","quote":"sky"}]\n```';
      final items = parseReconcileArray(fenced);
      expect(items.single.category, 'beauty');
      expect(items.single.text, 'Sunset.');
    });

    test('returns empty list on malformed JSON', () {
      expect(parseReconcileArray('not json'), isEmpty);
    });

    test('returns empty list when top level is not a list', () {
      expect(parseReconcileArray('{"category":"positive"}'), isEmpty);
    });
  });

  group('GeminiLlmService', () {
    // Note: GeminiLlmService() now requires Firebase to be initialized
    // (uses FirebaseAI.googleAI()). Constructor and API tests require
    // a Firebase test environment. extractJson tests above cover the
    // pure logic without Firebase dependency.
  });
}
