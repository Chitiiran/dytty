import 'package:dytty/core/constants/categories.dart';

class LlmResponse {
  final String text;
  final Map<String, dynamic>? metadata;

  const LlmResponse({required this.text, this.metadata});
}

class CategorizationResult {
  final JournalCategory suggestedCategory;
  final String summary;
  final double confidence;
  final List<String> suggestedTags;

  const CategorizationResult({
    required this.suggestedCategory,
    required this.summary,
    required this.confidence,
    this.suggestedTags = const [],
  });
}

abstract class LlmService {
  Future<LlmResponse> generateResponse(String prompt);

  Future<CategorizationResult> categorizeEntry(String text);

  Future<String> summarizeEntry(String text);

  Future<String> generateWeeklySummary(List<String> entries);

  void dispose();
}
