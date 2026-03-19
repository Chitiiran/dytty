import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/review_prompts.dart';
import 'package:dytty/data/models/category_entry.dart';

void main() {
  group('buildReviewPrompt', () {
    test('includes category name', () {
      final prompt = buildReviewPrompt('Positive Things', [
        'Is the feeling lasting?',
        'Did you take action?',
      ], []);

      expect(prompt, contains('Positive Things'));
    });

    test('includes both review questions', () {
      final prompt = buildReviewPrompt('Gratitude', [
        'Grateful for good things?',
        'Is your ability improving?',
      ], []);

      expect(prompt, contains('Grateful for good things?'));
      expect(prompt, contains('Is your ability improving?'));
    });

    test('includes entry text from provided entries', () {
      final entries = [
        CategoryEntry(
          id: 'e1',
          categoryId: 'positive',
          text: 'Had a great morning run',
          createdAt: DateTime(2026, 3, 18),
        ),
        CategoryEntry(
          id: 'e2',
          categoryId: 'positive',
          text: 'Got promoted at work',
          createdAt: DateTime(2026, 3, 17),
        ),
      ];

      final prompt = buildReviewPrompt('Positive Things', [
        'Q1?',
        'Q2?',
      ], entries);

      expect(prompt, contains('Had a great morning run'));
      expect(prompt, contains('Got promoted at work'));
    });

    test('mentions save_entry and edit_entry tools', () {
      final prompt = buildReviewPrompt('Beauty', ['Q1?', 'Q2?'], []);

      expect(prompt, contains('save_entry'));
      expect(prompt, contains('edit_entry'));
    });

    test('handles empty entries list', () {
      final prompt = buildReviewPrompt('Identity', ['Q1?', 'Q2?'], []);

      // Should not throw, and still include questions
      expect(prompt, contains('Q1?'));
      expect(prompt, contains('Q2?'));
    });
  });
}
