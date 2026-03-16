import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/llm/no_op_llm_service.dart';

void main() {
  late NoOpLlmService service;

  setUp(() {
    service = NoOpLlmService();
  });

  group('NoOpLlmService', () {
    test('generateResponse returns empty text', () async {
      final response = await service.generateResponse('any prompt');

      expect(response, isA<LlmResponse>());
      expect(response.text, '');
      expect(response.metadata, isNull);
    });

    group('categorizeEntry', () {
      test('returns first categoryId with zero confidence', () async {
        final result = await service.categorizeEntry(
          'some text',
          categoryIds: ['gratitude', 'positive'],
        );

        expect(result, isA<CategorizationResult>());
        expect(result.suggestedCategory, 'gratitude');
        expect(result.summary, '');
        expect(result.confidence, 0.0);
        expect(result.suggestedTags, isEmpty);
      });

      test('defaults to "positive" when no categoryIds provided', () async {
        final result = await service.categorizeEntry('some text');

        expect(result.suggestedCategory, 'positive');
      });
    });

    test('summarizeEntry returns the input text unchanged', () async {
      const input = 'Today was a good day';
      final result = await service.summarizeEntry(input);

      expect(result, input);
    });

    test('generateWeeklySummary returns empty string', () async {
      final result = await service.generateWeeklySummary([
        'Entry one',
        'Entry two',
      ]);

      expect(result, '');
    });

    test('dispose does not throw', () {
      expect(() => service.dispose(), returnsNormally);
    });

    test('implements LlmService', () {
      expect(service, isA<LlmService>());
    });
  });
}
