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

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'InitializeSpeech emits error when initialize throws',
      build: () {
        speechService = _ThrowingSpeechService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: llmService,
        );
      },
      act: (bloc) => bloc.add(const InitializeSpeech()),
      expect: () => [
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.error)
            .having(
              (s) => s.error,
              'error',
              contains('Failed to initialize speech'),
            ),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'CategorizeTranscript emits error when LLM throws non-timeout exception',
      build: () {
        final errorLlm = _ErrorLlmService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: errorLlm,
        );
      },
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.transcriptReview,
        transcript: 'Some journal text',
      ),
      act: (bloc) => bloc.add(const CategorizeTranscript()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.processing,
        ),
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.error)
            .having((s) => s.error, 'error', contains('Failed to categorize')),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'CategorizeTranscript uses transcript as summary when LLM returns empty summary',
      build: () {
        final emptySummaryLlm = _EmptySummaryLlmService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: emptySummaryLlm,
        );
      },
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.transcriptReview,
        transcript: 'My original text here',
      ),
      act: (bloc) => bloc.add(const CategorizeTranscript()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.processing,
        ),
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.summary, 'summary', 'My original text here'),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      'ReconcileSummary falls back to transcript on non-timeout error',
      build: () {
        final errorLlm = _ErrorLlmService();
        return VoiceNoteBloc(
          speechService: speechService,
          llmService: errorLlm,
        );
      },
      seed: () => const VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        originalTranscript: 'Original words',
        transcript: 'Edited words by user',
        summary: 'Old summary',
        transcriptEdited: true,
      ),
      act: (bloc) => bloc.add(const ReconcileSummary()),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.reconciling,
        ),
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.reviewing)
            .having((s) => s.summary, 'summary', 'Edited words by user'),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      '_SpeechResultReceived with final but empty text stays in listening',
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
        // Simulate a final speech result with empty text
        speechService.lastOnResult?.call(
          SpeechRecognitionResult(
            [
              SpeechRecognitionWords('', [''], 0.0),
            ],
            true, // finalResult
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // listening from StartListening (transcript='')
        // _SpeechResultReceived emits transcript='' again but bloc deduplicates
        // so only 1 state: listening. No transcriptReview because text is empty.
        isA<VoiceNoteState>()
            .having((s) => s.status, 'status', VoiceNoteStatus.listening)
            .having((s) => s.transcript, 'transcript', ''),
      ],
    );

    blocTest<VoiceNoteBloc, VoiceNoteState>(
      '_SpeechResultReceived with non-final result stays in listening',
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
        speechService.lastOnResult?.call(
          SpeechRecognitionResult(
            [
              SpeechRecognitionWords('Hello wor', ['Hello wor'], 0.8),
            ],
            false, // not final
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<VoiceNoteState>().having(
          (s) => s.status,
          'status',
          VoiceNoteStatus.listening,
        ),
        // transcript updated but stays listening (not final)
        isA<VoiceNoteState>()
            .having((s) => s.transcript, 'transcript', 'Hello wor')
            .having((s) => s.status, 'status', VoiceNoteStatus.listening),
      ],
    );

    test('close disposes speech service', () async {
      final bloc = VoiceNoteBloc(
        speechService: speechService,
        llmService: llmService,
      );
      await bloc.close();
      // FakeSpeechService.dispose() is called - no throw expected
    });
  });

  group('VoiceNoteState', () {
    test('copyWith preserves values when no arguments given', () {
      const original = VoiceNoteState(
        status: VoiceNoteStatus.reviewing,
        transcript: 'hello',
        originalTranscript: 'original',
        summary: 'sum',
        suggestedCategory: 'positive',
        suggestedTags: ['tag1'],
        confidence: 0.9,
        transcriptEdited: true,
      );
      final copied = original.copyWith();
      expect(copied.status, VoiceNoteStatus.reviewing);
      expect(copied.transcript, 'hello');
      expect(copied.originalTranscript, 'original');
      expect(copied.summary, 'sum');
      expect(copied.suggestedCategory, 'positive');
      expect(copied.suggestedTags, ['tag1']);
      expect(copied.confidence, 0.9);
      expect(copied.transcriptEdited, true);
      // error is cleared by design when not passed
      expect(copied.error, isNull);
    });

    test('props includes all fields for equality', () {
      const s1 = VoiceNoteState(transcript: 'a', confidence: 0.5);
      const s2 = VoiceNoteState(transcript: 'a', confidence: 0.5);
      const s3 = VoiceNoteState(transcript: 'b', confidence: 0.5);
      expect(s1, s2);
      expect(s1, isNot(s3));
    });
  });

  group('VoiceNoteEvent props', () {
    test('UpdateCategory instances with same id are equal', () {
      expect(
        const UpdateCategory('positive'),
        const UpdateCategory('positive'),
      );
    });

    test('UpdateCategory instances with different ids are not equal', () {
      expect(
        const UpdateCategory('positive'),
        isNot(const UpdateCategory('negative')),
      );
    });

    test('UpdateText instances with same text are equal', () {
      expect(const UpdateText('hello'), const UpdateText('hello'));
    });

    test('UpdateTranscript instances with same text are equal', () {
      expect(const UpdateTranscript('hi'), const UpdateTranscript('hi'));
    });
  });
}

/// Speech service that throws on initialize.
class _ThrowingSpeechService extends FakeSpeechService {
  _ThrowingSpeechService() : super(simulateAvailable: true);

  @override
  Future<bool> initialize() async {
    throw Exception('Microphone permission denied');
  }
}

/// LLM service that throws a non-timeout error.
class _ErrorLlmService implements LlmService {
  @override
  Future<CategorizationResult> categorizeEntry(
    String text, {
    List<String> categoryIds = const ['positive'],
  }) async {
    throw Exception('Network error');
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
  ) async {
    throw Exception('Reconcile failed');
  }

  @override
  Future<String> generateWeeklySummary(List<String> entries) async => '';

  @override
  void dispose() {}
}

/// LLM service that returns empty summary in categorization.
class _EmptySummaryLlmService implements LlmService {
  @override
  Future<CategorizationResult> categorizeEntry(
    String text, {
    List<String> categoryIds = const ['positive'],
  }) async {
    return const CategorizationResult(
      suggestedCategory: 'positive',
      summary: '',
      confidence: 0.8,
      suggestedTags: [],
    );
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
  ) async => '';

  @override
  Future<String> generateWeeklySummary(List<String> entries) async => '';

  @override
  void dispose() {}
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
