import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'fake_llm_service.dart';

void main() {
  test('fake returns scripted reconciled items', () async {
    final fake = FakeLlmService()
      ..reconcileResult = const [
        ReconciledItem(
          action: ReconcileAction.add,
          category: 'negative',
          text: 'Had a rough day at work',
          sourceTranscript: 'rough day at work',
        ),
      ];
    final result = await fake.reconcileSession('transcript', const []);
    expect(result, hasLength(1));
    expect(result.first.action, ReconcileAction.add);
  });
}
