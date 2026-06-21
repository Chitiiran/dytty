import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/gemini_llm_service.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/core/constants/reconcile_prompt.dart';

void main() {
  group('buildReconcilePrompt', () {
    test('includes transcript and saved entries with ids', () {
      final prompt = buildReconcilePrompt(
        'I felt proud finishing the run',
        const [
          SavedEntrySnapshot(
            entryId: 'e1',
            category: 'positive',
            text: 'Felt proud',
          ),
        ],
      );
      expect(prompt, contains('I felt proud finishing the run'));
      expect(prompt, contains('e1'));
      expect(prompt, contains('Felt proud'));
    });
    test('states the recall + recategorize-gap rule', () {
      final prompt = buildReconcilePrompt('x', const []).toLowerCase();
      // #231: recall gap-fill, now including items the live model saved
      // under the WRONG category (a category with no matching entry is a gap).
      expect(prompt, contains('not already saved'));
      expect(prompt, contains('same content and the same category'));
      expect(prompt, contains('different category'));
      // Still must not restate an item already saved under its CORRECT category.
      expect(prompt, contains('never restate an item already'));
    });

    test('asks for a JSON array of category/text/quote (schema-first)', () {
      final prompt = buildReconcilePrompt('x', const []);
      expect(prompt, contains('JSON array'));
      expect(prompt, contains('"quote"'));
    });
  });
  group('parseReconcileCalls', () {
    test('maps save_entry to add and edit_entry to reword', () {
      final calls = [
        {
          'name': 'save_entry',
          'args': {
            'category': 'negative',
            'text': 'rough day',
            'transcript': 'rough day',
          },
        },
        {
          'name': 'edit_entry',
          'args': {'entry_id': 'e1', 'text': 'Felt proud finishing the run'},
        },
      ];
      final items = parseReconcileCalls(calls);
      expect(items[0].action, ReconcileAction.add);
      expect(items[0].category, 'negative');
      expect(items[1].action, ReconcileAction.reword);
      expect(items[1].entryId, 'e1');
    });
    test('drops malformed calls (missing text)', () {
      final calls = [
        {
          'name': 'save_entry',
          'args': {'category': 'negative'},
        },
        {
          'name': 'save_entry',
          'args': {'category': 'positive', 'text': 'ok'},
        },
      ];
      final items = parseReconcileCalls(calls);
      expect(items, hasLength(1));
      expect(items.first.text, 'ok');
    });
  });
}
