import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:dytty/features/voice_note/bloc/voice_note_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';
import '../../services/llm/fake_llm_service.dart';

/// A [SpeechService] that simulates availability for testing.
///
/// Captures [onResult] callback and duration params so tests can
/// drive speech results and verify configuration.
class FakeSpeechService extends SpeechService {
  final bool simulateAvailable;

  /// Captured callback from the last [startListening] call.
  void Function(SpeechRecognitionResult result)? lastOnResult;

  /// Captured duration params from the last [startListening] call.
  Duration? lastPauseFor;
  Duration? lastListenFor;

  FakeSpeechService({this.simulateAvailable = true});

  @override
  Future<bool> initialize() async => simulateAvailable;

  @override
  bool get isAvailable => simulateAvailable;

  @override
  Future<void> startListening({
    required void Function(SpeechRecognitionResult result) onResult,
    Duration pauseFor = const Duration(seconds: 5),
    Duration listenFor = const Duration(seconds: 120),
  }) async {
    lastOnResult = onResult;
    lastPauseFor = pauseFor;
    lastListenFor = listenFor;
  }

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
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      act: (bloc) => bloc.add(const InitializeSpeech()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.ready,
        ),
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
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.unavailable,
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'CategorizeTranscript -> processing -> reviewing with LLM results',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.listening,
        transcript: 'I had a great day at the park',
      ),
      act: (bloc) => bloc.add(const CategorizeTranscript()),
      expect: () => [
        // processing
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.processing,
        ),
        // reviewing with FakeLlmService results
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.suggestedCategory, 'suggestedCategory', 'positive')
            .having((s) => s.suggestedTags, 'suggestedTags', ['fake', 'test'])
            .having((s) => s.confidence, 'confidence', 0.95),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'UpdateCategory changes suggested category',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        suggestedCategory: 'positive',
      ),
      act: (bloc) => bloc.add(const UpdateCategory('gratitude')),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.suggestedCategory,
          'suggestedCategory',
          'gratitude',
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'UpdateText changes summary text',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        summary: 'Original summary',
      ),
      act: (bloc) => bloc.add(const UpdateText('Edited summary')),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.summary,
          'summary',
          'Edited summary',
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'StartListening emits listening status',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(status: VoiceNoteStatus.ready),
      act: (bloc) => bloc.add(const StartListening()),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.listening)
            .having((s) => s.transcript, 'transcript', ''),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'StopListening with transcript emits transcriptReview',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.listening,
        transcript: 'I feel grateful today',
      ),
      act: (bloc) => bloc.add(const StopListening()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.transcriptReview,
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'StopListening with empty transcript returns to ready',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.listening,
        transcript: '',
      ),
      act: (bloc) => bloc.add(const StopListening()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.ready,
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      '_SpeechResultReceived with finalResult emits transcriptReview',
      build: () {
        final bloc = VoiceNoteBloc(
          speechService: speechService,
          llmService: llmService,
        );
        return bloc;
      },
      seed: () => const VoiceNoteState(status: VoiceNoteStatus.ready),
      act: (bloc) async {
        bloc.add(const StartListening());
        await Future<void>.delayed(Duration.zero);
        // Simulate a final speech result via the captured callback
        speechService.lastOnResult?.call(
          SpeechRecognitionResult(
            [
              SpeechRecognitionWords('Hello world', ['Hello world'], 0.95),
            ],
            true, // finalResult
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // listening from StartListening
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.listening,
        ),
        // transcript update from _SpeechResultReceived
        isA<VoiceNoteState>().having(
          (s) => s.transcript,
          'transcript',
          'Hello world',
        ),
        // transcriptReview (no auto-categorization)
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.transcriptReview,
        ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'RequestCategorization from transcriptReview triggers processing -> reviewing',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.transcriptReview,
        transcript: 'I had a great day at the park',
      ),
      act: (bloc) => bloc.add(const RequestCategorization()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.processing,
        ),
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having(
              (s) => s.suggestedCategory,
              'suggestedCategory',
              'positive',
            ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'CategorizeTranscript times out and emits reviewing with transcript as summary',
      build: () {
        final slowLlm = _SlowLlmService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: slowLlm,
          categorizationTimeout: const Duration(milliseconds: 50),
        );
      },
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.transcriptReview,
        transcript: 'I want to add entry',
      ),
      act: (bloc) => bloc.add(const CategorizeTranscript()),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.processing,
        ),
        // On timeout, falls back to reviewing with no category (user picks manually)
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.summary, 'summary', 'I want to add entry')
            .having((s) => s.suggestedCategory, 'suggestedCategory', null),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'UpdateTranscript changes transcript text',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        transcript: 'Original transcript from STT',
        summary: 'Original summary',
      ),
      act: (bloc) => bloc.add(
        const UpdateTranscript('Original transcript from STT, plus edits'),
      ),
      expect: () => [
        isA<VoiceNoteState>()
            .having(
              (s) => s.transcript,
              'transcript',
              'Original transcript from STT, plus edits',
            )
            .having((s) => s.transcriptEdited, 'transcriptEdited', true),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ReconcileSummary calls LLM with original and edited transcript',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        originalTranscript: 'I had a great day at the park',
        transcript: 'I had a great day at the park with my dog',
        summary: 'Old summary',
        transcriptEdited: true,
      ),
      act: (bloc) => bloc.add(const ReconcileSummary()),
      expect: () => [
        // reconciling state
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.reconciling,
        ),
        // back to reviewing with reconciled summary
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.summary, 'summary', isNotEmpty),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ReconcileSummary times out and falls back to edited transcript',
      build: () {
        final slowLlm = _SlowLlmService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: slowLlm,
          categorizationTimeout: const Duration(milliseconds: 50),
        );
      },
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        originalTranscript: 'Original text',
        transcript: 'Edited text by user',
        summary: 'Old summary',
        transcriptEdited: true,
      ),
      act: (bloc) => bloc.add(const ReconcileSummary()),
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.reconciling,
        ),
        // Falls back to edited transcript as summary
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.summary, 'summary', 'Edited text by user'),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ReconcileSummary skipped when transcript not edited',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        transcript: 'I had a great day',
        summary: 'Great day',
        transcriptEdited: false,
      ),
      act: (bloc) => bloc.add(const ReconcileSummary()),
      expect: () => [],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ResetVoiceNote returns to ready',
      build: () =>
          VoiceNoteBloc(speechService: speechService, llmService: llmService),
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

/// LLM service that never completes, simulating a hang.
class _SlowLlmService implements LlmService {
  @override
  Future<CategorizationResult> categorizeEntry(
    String text, {
    List<String> categoryIds = const ['positive'],
  }) {
    return Completer<CategorizationResult>().future; // never completes
  }

  @override
  Future<LlmResponse> generateResponse(String prompt) async =>
      const LlmResponse(text: '');

  @override
  Future<String> summarizeEntry(String text) async => '';

  @override
  Future<String> reconcileSummary(
    String originalTranscript,
    String editedTranscript,
  ) {
    return Completer<String>().future; // never completes
  }

  @override
  Future<String> generateWeeklySummary(List<String> entries) async => '';

  @override
  void dispose() {}
}
