import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:dytty/features/voice_note/bloc/voice_note_bloc.dart';
import 'package:dytty/services/speech/speech_service.dart';
import '../../services/llm/fake_llm_service.dart';

/// Minimal fake speech service for log testing.
class _FakeSpeech extends SpeechService {
  void Function(SpeechRecognitionResult)? lastOnResult;

  @override
  Future<bool> initialize() async => true;

  @override
  bool get isAvailable => true;

  @override
  Future<void> startListening({
    required void Function(SpeechRecognitionResult) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 120),
  }) async {
    lastOnResult = onResult;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

void main() {
  late _FakeSpeech speech;
  late FakeLlmService llm;
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    speech = _FakeSpeech();
    llm = FakeLlmService();
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  group('[DYTTY] voice note logs', () {
    test('logs "Voice note state: listening" on StartListening', () async {
      final bloc = VoiceNoteBloc(speechService: speech, llmService: llm);
      bloc.add(const InitializeSpeech());
      await Future.delayed(Duration.zero);

      bloc.add(const StartListening());
      await Future.delayed(Duration.zero);

      expect(logs, contains('[DYTTY] Voice note state: listening'));
      await bloc.close();
    });

    test('logs "User said:" on speech result', () async {
      final bloc = VoiceNoteBloc(speechService: speech, llmService: llm);
      bloc.add(const InitializeSpeech());
      await Future.delayed(Duration.zero);
      bloc.add(const StartListening());
      await Future.delayed(Duration.zero);

      speech.lastOnResult!(
        SpeechRecognitionResult([
          SpeechRecognitionWords('hello world', ['hello world'], 0.95),
        ], true),
      );
      await Future.delayed(Duration.zero);

      expect(
        logs.any((l) => l.contains('[DYTTY] User said: hello world')),
        isTrue,
      );
      await bloc.close();
    });

    test('logs "Voice note state: transcriptReview" on final result', () async {
      final bloc = VoiceNoteBloc(speechService: speech, llmService: llm);
      bloc.add(const InitializeSpeech());
      await Future.delayed(Duration.zero);
      bloc.add(const StartListening());
      await Future.delayed(Duration.zero);

      speech.lastOnResult!(
        SpeechRecognitionResult([
          SpeechRecognitionWords('hello world', ['hello world'], 0.95),
        ], true),
      );
      await Future.delayed(Duration.zero);

      expect(logs, contains('[DYTTY] Voice note state: transcriptReview'));
      await bloc.close();
    });
  });
}
