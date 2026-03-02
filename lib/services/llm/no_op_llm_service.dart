import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/llm/llm_service.dart';

/// No-op [LlmService] used when no API key is configured.
/// Returns sensible defaults so the app remains functional.
class NoOpLlmService implements LlmService {
  @override
  Future<LlmResponse> generateResponse(String prompt) async {
    return const LlmResponse(text: '');
  }

  @override
  Future<CategorizationResult> categorizeEntry(String text) async {
    return const CategorizationResult(
      suggestedCategory: JournalCategory.positive,
      summary: '',
      confidence: 0.0,
    );
  }

  @override
  Future<String> summarizeEntry(String text) async => text;

  @override
  Future<String> generateWeeklySummary(List<String> entries) async => '';

  @override
  void dispose() {}
}
