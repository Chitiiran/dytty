import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps [SpeechToText] for constructor-injection and testability.
class SpeechService {
  final SpeechToText _speech;
  bool _isInitialized = false;

  SpeechService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  /// Returns true if speech recognition is available on this device.
  Future<bool> initialize() async {
    _isInitialized = await _speech.initialize();
    return _isInitialized;
  }

  /// Starts listening. [onResult] fires for each partial/final result.
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
  }) async {
    if (!_isInitialized) return;
    await _speech.listen(onResult: onResult);
  }

  /// Stops listening and finalizes the last result.
  Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Cancels listening without finalizing.
  Future<void> cancel() async {
    await _speech.cancel();
  }

  void dispose() {
    _speech.cancel();
  }
}
