import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:dytty/features/voice_note/bloc/voice_note_bloc.dart';
import 'package:dytty/services/speech/speech_service.dart';
import '../../services/llm/fake_llm_service.dart';

/// A [SpeechService] that simulates availability for testing.
class FakeSpeechService extends SpeechService {
  final bool simulateAvailable;

  FakeSpeechService({this.simulateAvailable = true});

  @override
  Future<bool> initialize() async => simulateAvailable;

  @override
  bool get isAvailable => simulateAvailable;

  @override
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
  }) async {}

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

void main() {
  late FakeSpeechService speechService;
  late FakeLlmService llmService;

  setUp(() {
    speechService = FakeSpeechService();
    llmService = FakeLlmService();
  });

  group('VoiceNoteBloc', () {
    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'InitializeSpeech -> ready when available',
      build: () => VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      ),
      act: (bloc) => bloc.add(const InitializeSpeech()),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.ready),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'InitializeSpeech -> unavailable when not available',
      build: () {
        speechService = FakeSpeechService(simulateAvailable: false);
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: llmService,
        );
      },
      act: (bloc) => bloc.add(const InitializeSpeech()),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.unavailable),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'CategorizeTranscript -> processing -> reviewing with LLM results',
      build: () => VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      ),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.listening,
        transcript: 'I had a great day at the park',
      ),
      act: (bloc) => bloc.add(const CategorizeTranscript()),
      expect: () => [
        // processing
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.processing),
        // reviewing with FakeLlmService results
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having(
              (s) => s.suggestedCategory,
              'suggestedCategory',
              'positive',
            )
            .having(
              (s) => s.suggestedTags,
              'suggestedTags',
              ['fake', 'test'],
            )
            .having((s) => s.confidence, 'confidence', 0.95),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'UpdateCategory changes suggested category',
      build: () => VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      ),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        suggestedCategory: 'positive',
      ),
      act: (bloc) => bloc.add(const UpdateCategory('gratitude')),
      expect: () => [
        isA<VoiceNoteState>()
            .having(
              (s) => s.suggestedCategory,
              'suggestedCategory',
              'gratitude',
            ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'UpdateText changes summary text',
      build: () => VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      ),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        summary: 'Original summary',
      ),
      act: (bloc) => bloc.add(const UpdateText('Edited summary')),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.summary, 'summary', 'Edited summary'),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ResetVoiceNote returns to ready',
      build: () => VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      ),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        transcript: 'some text',
        summary: 'some summary',
        suggestedCategory: 'positive',
      ),
      act: (bloc) => bloc.add(const ResetVoiceNote()),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.ready)
            .having((s) => s.transcript, 'transcript', '')
            .having((s) => s.summary, 'summary', ''),
      ],
    );
  });
}
