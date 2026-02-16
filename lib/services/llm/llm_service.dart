import 'package:dytty/core/constants/categories.dart';

/// A single message in the LLM conversation
class LlmMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  LlmMessage({required this.role, required this.content});
}

/// Extracted entry from conversation
class ExtractedEntry {
  final JournalCategory category;
  final String text;

  ExtractedEntry({required this.category, required this.text});
}

/// Provider-agnostic LLM interface for journal conversations
abstract class LlmService {
  /// Send conversation history and get next assistant response
  Future<String> chat(List<LlmMessage> messages);

  /// Extract categorized entries from a conversation transcript
  Future<List<ExtractedEntry>> extractEntries(String transcript);
}
