import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps [SpeechToText] for constructor-injection and testability.
class SpeechService {
  final SpeechToText _speech;
  bool _isInitialized = false;

  SpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  /// Returns true if speech recognition is available on this device.
  Future<bool> initialize() async {
    _isInitialized = await _speech.initialize();
    return _isInitialized;
  }

  /// Starts listening. [onResult] fires for each partial/final result.
  ///
  /// [pauseFor] — how long to wait after silence before auto-stopping
  /// (default 5s, long enough for natural breath pauses).
  /// [listenFor] — max recording duration as a safety cap (default 120s).
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 120),
  }) async {
    if (!_isInitialized) return;
    await _speech.listen(
      onResult: onResult,
      pauseFor: pauseFor,
      listenFor: listenFor,
    );
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
