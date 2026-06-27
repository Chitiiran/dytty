import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';

void main() {
  group('SavedEntry', () {
    test('exposes an entryId field', () {
      const e = SavedEntry(
        entryId: 'abc',
        categoryId: 'positive',
        text: 't',
        transcript: 'tr',
      );
      expect(e.entryId, 'abc');
    });

    test('defaults reconciliation markers to false', () {
      const e = SavedEntry(categoryId: 'positive', text: 't', transcript: 'tr');
      expect(e.addedByAi, isFalse);
      expect(e.rewordedByAi, isFalse);
      expect(e.entryId, isNull);
    });

    test('copyWith updates entryId, text, rewordedByAi only', () {
      const e = SavedEntry(
        categoryId: 'negative',
        text: 'old',
        transcript: 'tr',
      );
      final updated = e.copyWith(
        entryId: 'e1',
        text: 'new',
        rewordedByAi: true,
      );
      expect(updated.entryId, 'e1');
      expect(updated.text, 'new');
      expect(updated.rewordedByAi, isTrue);
      expect(updated.categoryId, 'negative'); // unchanged
      expect(updated.addedByAi, isFalse); // unchanged
    });
  });
}
