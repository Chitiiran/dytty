class VoiceNoteResult {
  final String categoryId;
  final String text;
  final String transcript;
  final List<String> tags;

  const VoiceNoteResult({
    required this.categoryId,
    required this.text,
    required this.transcript,
    this.tags = const [],
  });
}
