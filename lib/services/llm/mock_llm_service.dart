import 'package:dytty/core/constants/categories.dart';
import 'package:dytty/services/llm/llm_service.dart';

/// Mock LLM that follows a scripted conversation flow through the 5 categories
class MockLlmService implements LlmService {
  static const _categoryPrompts = {
    JournalCategory.positive: "That's great to hear! Now, tell me about something positive that happened today.",
    JournalCategory.negative: "Thank you for sharing. Was there anything challenging or difficult about today?",
    JournalCategory.gratitude: "I appreciate you being open about that. What are you grateful for today?",
    JournalCategory.beauty: "Beautiful. What did you find beautiful today? It could be anything - a sight, a sound, a moment.",
    JournalCategory.identity: "Lovely. Last question - based purely on your actions today, who would you say you are?",
  };

  int _questionIndex = 0;
  final _categories = JournalCategory.values;

  @override
  Future<String> chat(List<LlmMessage> messages) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (messages.isEmpty || messages.length == 1) {
      _questionIndex = 0;
      return "Hi! I'd love to hear about your day. ${_categoryPrompts[_categories[0]]}";
    }

    // Count user messages to determine which category to ask about next
    final userMessages = messages.where((m) => m.role == 'user').length;
    _questionIndex = userMessages;

    if (_questionIndex >= _categories.length) {
      return "Thank you for sharing your reflections today. I've captured your entries across all five categories. Take a moment to review them and make any edits you'd like.";
    }

    return _categoryPrompts[_categories[_questionIndex]]!;
  }

  @override
  Future<List<ExtractedEntry>> extractEntries(String transcript) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // In mock mode, we create a simple entry per category from the transcript
    // A real LLM would actually parse the transcript intelligently
    final lines = transcript
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final entries = <ExtractedEntry>[];
    for (var i = 0; i < _categories.length && i < lines.length; i++) {
      entries.add(ExtractedEntry(
        category: _categories[i],
        text: lines[i].trim(),
      ));
    }

    return entries;
  }
}
