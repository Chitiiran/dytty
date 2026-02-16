import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:dytty/services/speech/speech_service.dart';

/// Uses the device's built-in speech recognition via speech_to_text package
class DeviceSpeechService implements SpeechService {
  final _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  @override
  Future<bool> isAvailable() async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
    return _initialized;
  }

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    String? localeId,
  }) async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
    if (!_initialized) return;

    _listening = true;
    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
        if (result.finalResult) {
          _listening = false;
          onDone();
        }
      },
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
    await _speech.stop();
  }

  @override
  bool get isListening => _listening;
}
