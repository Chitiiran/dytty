import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/core/constants/review_questions.dart';

void main() {
  group('reviewQuestions', () {
    test('contains all 5 journal categories', () {
      expect(reviewQuestions.keys, containsAll(JournalCategory.values));
      expect(reviewQuestions.length, 5);
    });

    test('each category has exactly 2 questions', () {
      for (final entry in reviewQuestions.entries) {
        expect(
          entry.value.length,
          2,
          reason: '${entry.key} should have exactly 2 review questions',
        );
      }
    });

    test('all questions are non-empty strings', () {
      for (final entry in reviewQuestions.entries) {
        for (final question in entry.value) {
          expect(
            question,
            isNotEmpty,
            reason: '${entry.key} has an empty question',
          );
        }
      }
    });
  });
}
