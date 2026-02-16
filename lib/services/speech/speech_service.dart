/// Provider-agnostic speech-to-text interface
abstract class SpeechService {
  /// Whether STT is available on this device
  Future<bool> isAvailable();

  /// Start listening. Calls [onResult] with partial/final transcripts.
  /// [onDone] is called when listening stops.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    String? localeId,
  });

  /// Stop listening
  Future<void> stopListening();

  /// Whether currently listening
  bool get isListening;
}
