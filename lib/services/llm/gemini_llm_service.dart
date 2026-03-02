import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/llm/llm_service.dart';

class GeminiLlmService implements LlmService {
  late final GenerativeModel _model;

  GeminiLlmService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
  }

  @override
  Future<LlmResponse> generateResponse(String prompt) async {
    final response = await _model.generateContent([Content.text(prompt)]);
    return LlmResponse(text: response.text ?? '');
  }

  @override
  Future<CategorizationResult> categorizeEntry(String text) async {
    final categories = JournalCategory.values.map((c) => c.name).join(', ');
    final prompt = '''
Categorize this journal entry into one of these categories: $categories.

Entry: "$text"

Respond with valid JSON only, no markdown:
{"category": "<category_name>", "summary": "<1-sentence summary>", "confidence": <0.0-1.0>, "tags": ["<tag1>", "<tag2>"]}
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    final json = jsonDecode(response.text ?? '{}') as Map<String, dynamic>;

    final categoryName = json['category'] as String? ?? 'positive';
    final category = JournalCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => JournalCategory.positive,
    );

    return CategorizationResult(
      suggestedCategory: category,
      summary: json['summary'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      suggestedTags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  @override
  Future<String> summarizeEntry(String text) async {
    final prompt =
        'Summarize this journal entry in one concise sentence:\n\n"$text"';
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  @override
  Future<String> generateWeeklySummary(List<String> entries) async {
    final entriesText = entries
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    final prompt = '''
Summarize these journal entries from the past week into a brief, insightful weekly review (3-5 sentences). Highlight themes, growth, and patterns.

Entries:
$entriesText
''';

    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  @override
  void dispose() {
    // GenerativeModel doesn't require cleanup
  }
}
