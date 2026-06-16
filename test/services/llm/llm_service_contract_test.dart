import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/llm_service.dart';

void main() {
  group('ReconciledItem', () {
    test('add item carries category, text, transcript, no entryId', () {
      const item = ReconciledItem(
        action: ReconcileAction.add,
        category: 'gratitude',
        text: 'Grateful for the help',
        sourceTranscript: 'my friend helped me',
      );
      expect(item.action, ReconcileAction.add);
      expect(item.entryId, isNull);
      expect(item.category, 'gratitude');
    });

    test('reword item carries entryId and new text', () {
      const item = ReconciledItem(
        action: ReconcileAction.reword,
        entryId: 'abc123',
        text: 'Paid for a subscription I dislike, but needed it for FIFA',
      );
      expect(item.action, ReconcileAction.reword);
      expect(item.entryId, 'abc123');
    });
  });

  group('SavedEntrySnapshot', () {
    test('carries entryId, category, text', () {
      const snap = SavedEntrySnapshot(
        entryId: 'e1',
        category: 'positive',
        text: 'Felt proud',
      );
      expect(snap.entryId, 'e1');
      expect(snap.category, 'positive');
      expect(snap.text, 'Felt proud');
    });
  });
}
