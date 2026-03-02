import 'package:dytty/core/constants/categories.dart';

class VoiceNoteResult {
  final JournalCategory category;
  final String text;
  final String transcript;
  final List<String> tags;

  const VoiceNoteResult({
    required this.category,
    required this.text,
    required this.transcript,
    this.tags = const [],
  });
}
