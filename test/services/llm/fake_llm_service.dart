import 'package:dytty/services/llm/llm_service.dart';

/// Fake implementation of [LlmService] for testing consumers.
/// Returns predictable, hardcoded responses.
class FakeLlmService implements LlmService {
  int callCount = 0;

  @override
  Future<LlmResponse> generateResponse(String prompt) async {
    callCount++;
    return const LlmResponse(
      text: 'Fake LLM response',
      metadata: {'fake': true},
    );
  }

  @override
  Future<CategorizationResult> categorizeEntry(String text,
      {List<String> categoryIds = const ['positive']}) async {
    callCount++;
    return const CategorizationResult(
      suggestedCategory: 'positive',
      summary: 'Fake categorization summary',
      confidence: 0.95,
      suggestedTags: ['fake', 'test'],
    );
  }

  @override
  Future<String> summarizeEntry(String text) async {
    callCount++;
    return 'Fake summary of: $text';
  }

  @override
  Future<String> generateWeeklySummary(List<String> entries) async {
    callCount++;
    return 'Fake weekly summary of ${entries.length} entries.';
  }

  @override
  void dispose() {}
}
