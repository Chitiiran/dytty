import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

// --- Mocks ---

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

class MockJournalBloc extends Mock implements JournalBloc {}

class MockLlmService extends Mock implements LlmService {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

// --- Fallback values for mocktail ---

void main() {
  late MockGeminiLiveService mockService;
  late MockJournalBloc mockJournalBloc;
  late MockLlmService mockLlmService;
  late MockAudioStorageService mockAudioStorage;

  // Stream controllers to drive mock service streams
  late StreamController<Transcript> transcriptController;
  late StreamController<FunctionCall> toolCallController;
  late StreamController<GeminiLiveState> stateController;
  late StreamController<Uint8List> audioController;

  setUpAll(() {
    registerFallbackValue(
      const AddVoiceEntry(categoryId: '', text: '', transcript: ''),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockService = MockGeminiLiveService();
    mockJournalBloc = MockJournalBloc();
    mockLlmService = MockLlmService();
    mockAudioStorage = MockAudioStorageService();

    transcriptController = StreamController<Transcript>.broadcast();
    toolCallController = StreamController<FunctionCall>.broadcast();
    stateController = StreamController<GeminiLiveState>.broadcast();
    audioController = StreamController<Uint8List>.broadcast();

    when(
      () => mockService.transcriptStream,
    ).thenAnswer((_) => transcriptController.stream);
    when(
      () => mockService.toolCallStream,
    ).thenAnswer((_) => toolCallController.stream);
    when(
      () => mockService.stateStream,
    ).thenAnswer((_) => stateController.stream);
    when(
      () => mockService.audioStream,
    ).thenAnswer((_) => audioController.stream);
    when(() => mockService.lastLatencyMs).thenReturn(null);
    when(() => mockService.connect()).thenAnswer((_) async {});
    when(() => mockService.disconnect()).thenAnswer((_) async {});
    when(() => mockService.dispose()).thenReturn(null);
    when(() => mockService.sendAudio(any())).thenReturn(null);
    when(
      () => mockService.sendToolResponse(any(), any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    transcriptController.close();
    toolCallController.close();
    stateController.close();
    audioController.close();
  });

  VoiceCallBloc buildBloc({
    JournalBloc? journalBloc,
    LlmService? llmService,
    AudioStorageService? audioStorage,
    String? uid,
  }) {
    return VoiceCallBloc(
      service: mockService,
      journalBloc: journalBloc,
      llmService: llmService,
      audioStorage: audioStorage,
      uid: uid,
    );
  }

  group('VoiceCallBloc initial state', () {
    test('has idle status and empty collections', () {
      final bloc = buildBloc();
      expect(bloc.state.status, VoiceCallStatus.idle);
      expect(bloc.state.transcripts, isEmpty);
      expect(bloc.state.savedEntries, isEmpty);
      expect(bloc.state.latencyMs, isNull);
      expect(bloc.state.elapsed, Duration.zero);
      expect(bloc.state.error, isNull);
      expect(bloc.state.showTimeWarning, false);
      expect(bloc.state.audioUrl, isNull);
      expect(bloc.state.uploadingAudio, false);
      expect(bloc.state.sessionSummary, isNull);
      expect(bloc.state.generatingSummary, false);
      bloc.close();
    });
  });

  group('StartCall', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'emits connecting then starts service connection',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const StartCall()),
      expect: () => [
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.connecting)
            .having((s) => s.transcripts, 'transcripts', isEmpty)
            .having((s) => s.savedEntries, 'savedEntries', isEmpty)
            .having((s) => s.elapsed, 'elapsed', Duration.zero)
            .having((s) => s.showTimeWarning, 'showTimeWarning', false),
      ],
      verify: (_) {
        verify(() => mockService.connect()).called(1);
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'emits error when service.connect() throws',
      setUp: () {
        when(
          () => mockService.connect(),
        ).thenThrow(Exception('connection failed'));
      },
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const StartCall()),
      expect: () => [
        // connecting
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.connecting,
        ),
        // error
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.error)
            .having((s) => s.error, 'error', contains('connection failed')),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'clears previous state on new StartCall',
      seed: () => const VoiceCallState(
        status: VoiceCallStatus.ended,
        latencyMs: 150,
        elapsed: Duration(minutes: 3),
        showTimeWarning: true,
      ),
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const StartCall()),
      expect: () => [
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.connecting)
            .having((s) => s.elapsed, 'elapsed', Duration.zero)
            .having((s) => s.showTimeWarning, 'showTimeWarning', false)
            .having((s) => s.transcripts, 'transcripts', isEmpty)
            .having((s) => s.savedEntries, 'savedEntries', isEmpty),
      ],
    );
  });

  group('EndCall', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'emits ending then ended without audio upload when no storage configured',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(const EndCall()),
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ending,
        ),
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ended,
        ),
      ],
      verify: (_) {
        verify(() => mockService.disconnect()).called(1);
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'uploads audio when storage is configured and audio was recorded',
      setUp: () {
        when(
          () => mockAudioStorage.uploadCallAudio(
            uid: any(named: 'uid'),
            date: any(named: 'date'),
            audioData: any(named: 'audioData'),
          ),
        ).thenAnswer((_) async => 'https://storage.example.com/audio.pcm');
      },
      build: () => buildBloc(audioStorage: mockAudioStorage, uid: 'test-user'),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) {
        // Simulate recorded audio by calling sendAudio before EndCall
        bloc.sendAudio(Uint8List.fromList([1, 2, 3]));
        bloc.add(const EndCall());
      },
      expect: () => [
        // ending
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ending,
        ),
        // ended + uploading
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.ended)
            .having((s) => s.uploadingAudio, 'uploadingAudio', true),
        // upload complete
        isA<VoiceCallState>()
            .having(
              (s) => s.audioUrl,
              'audioUrl',
              'https://storage.example.com/audio.pcm',
            )
            .having((s) => s.uploadingAudio, 'uploadingAudio', false),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'handles audio upload failure gracefully',
      setUp: () {
        when(
          () => mockAudioStorage.uploadCallAudio(
            uid: any(named: 'uid'),
            date: any(named: 'date'),
            audioData: any(named: 'audioData'),
          ),
        ).thenThrow(Exception('upload failed'));
      },
      build: () => buildBloc(audioStorage: mockAudioStorage, uid: 'test-user'),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) {
        bloc.sendAudio(Uint8List.fromList([1, 2, 3]));
        bloc.add(const EndCall());
      },
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ending,
        ),
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.ended)
            .having((s) => s.uploadingAudio, 'uploadingAudio', true),
        // Upload failed but uploadingAudio set to false, no audioUrl
        isA<VoiceCallState>()
            .having((s) => s.uploadingAudio, 'uploadingAudio', false)
            .having((s) => s.audioUrl, 'audioUrl', isNull),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'triggers summary generation when llmService and transcripts are present',
      setUp: () {
        when(
          () => mockLlmService.generateResponse(any()),
        ).thenAnswer((_) async => const LlmResponse(text: 'Test summary'));
      },
      build: () => buildBloc(llmService: mockLlmService),
      seed: () => VoiceCallState(
        status: VoiceCallStatus.active,
        transcripts: [
          const Transcript(speaker: Speaker.user, text: 'Hello'),
          const Transcript(speaker: Speaker.ai, text: 'Hi there'),
        ],
      ),
      act: (bloc) => bloc.add(const EndCall()),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // ending
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ending,
        ),
        // ended
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ended,
        ),
        // generating summary
        isA<VoiceCallState>().having(
          (s) => s.generatingSummary,
          'generatingSummary',
          true,
        ),
        // summary complete
        isA<VoiceCallState>()
            .having((s) => s.sessionSummary, 'sessionSummary', 'Test summary')
            .having((s) => s.generatingSummary, 'generatingSummary', false),
      ],
    );
  });

  group('TranscriptReceived', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'appends transcript to list',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) {
        bloc.add(
          const TranscriptReceived(
            Transcript(speaker: Speaker.user, text: 'Hello'),
          ),
        );
        bloc.add(
          const TranscriptReceived(
            Transcript(speaker: Speaker.ai, text: 'Hi there'),
          ),
        );
      },
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.transcripts.length,
          'transcripts.length',
          1,
        ),
        isA<VoiceCallState>().having(
          (s) => s.transcripts.length,
          'transcripts.length',
          2,
        ),
      ],
    );
  });

  group('ToolCallReceived', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'save_entry tool call creates SavedEntry and dispatches to JournalBloc',
      build: () => buildBloc(journalBloc: mockJournalBloc),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(
        ToolCallReceived(
          FunctionCall('save_entry', {
            'category': 'gratitude',
            'text': 'I am grateful for friends',
            'transcript': 'I said I am grateful for friends',
          }, id: 'call-1'),
        ),
      ),
      expect: () => [
        isA<VoiceCallState>()
            .having((s) => s.savedEntries.length, 'savedEntries.length', 1)
            .having(
              (s) => s.savedEntries.first.categoryId,
              'categoryId',
              'gratitude',
            )
            .having(
              (s) => s.savedEntries.first.text,
              'text',
              'I am grateful for friends',
            )
            .having(
              (s) => s.savedEntries.first.transcript,
              'transcript',
              'I said I am grateful for friends',
            ),
      ],
      verify: (_) {
        verify(
          () => mockJournalBloc.add(
            any(
              that: isA<AddVoiceEntry>()
                  .having((e) => e.categoryId, 'categoryId', 'gratitude')
                  .having((e) => e.text, 'text', 'I am grateful for friends')
                  .having((e) => e.tags, 'tags', ['voice-call']),
            ),
          ),
        ).called(1);

        verify(
          () => mockService.sendToolResponse('save_entry', 'call-1', {
            'status': 'saved',
            'category': 'gratitude',
          }),
        ).called(1);
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'save_entry with missing args uses defaults',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(
        ToolCallReceived(FunctionCall('save_entry', {}, id: 'call-2')),
      ),
      expect: () => [
        isA<VoiceCallState>()
            .having(
              (s) => s.savedEntries.first.categoryId,
              'categoryId',
              'positive',
            )
            .having((s) => s.savedEntries.first.text, 'text', '')
            .having((s) => s.savedEntries.first.transcript, 'transcript', ''),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'non-save_entry tool calls are ignored',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(
        ToolCallReceived(
          FunctionCall('unknown_tool', {'key': 'value'}, id: 'call-3'),
        ),
      ),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'accumulates multiple saved entries',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) {
        bloc.add(
          ToolCallReceived(
            FunctionCall('save_entry', {
              'category': 'positive',
              'text': 'First',
              'transcript': 'first transcript',
            }),
          ),
        );
        bloc.add(
          ToolCallReceived(
            FunctionCall('save_entry', {
              'category': 'beauty',
              'text': 'Second',
              'transcript': 'second transcript',
            }),
          ),
        );
      },
      expect: () => [
        isA<VoiceCallState>().having((s) => s.savedEntries.length, 'length', 1),
        isA<VoiceCallState>().having((s) => s.savedEntries.length, 'length', 2),
      ],
    );
  });

  group('ServiceStateChanged', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'active state transitions connecting -> active',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.connecting),
      act: (bloc) =>
          bloc.add(const ServiceStateChanged(GeminiLiveState.active)),
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.active,
        ),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'active state does not change if already active',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) =>
          bloc.add(const ServiceStateChanged(GeminiLiveState.active)),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'error state emits error status',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(const ServiceStateChanged(GeminiLiveState.error)),
      expect: () => [
        isA<VoiceCallState>()
            .having((s) => s.status, 'status', VoiceCallStatus.error)
            .having((s) => s.error, 'error', 'Connection error'),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'idle state during active call triggers EndCall',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) => bloc.add(const ServiceStateChanged(GeminiLiveState.idle)),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        // EndCall is dispatched internally, leading to ending then ended
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ending,
        ),
        isA<VoiceCallState>().having(
          (s) => s.status,
          'status',
          VoiceCallStatus.ended,
        ),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'idle state when not active does nothing',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.idle),
      act: (bloc) => bloc.add(const ServiceStateChanged(GeminiLiveState.idle)),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'connecting state does nothing (default case)',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.connecting),
      act: (bloc) =>
          bloc.add(const ServiceStateChanged(GeminiLiveState.connecting)),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'disconnecting state does nothing (default case)',
      build: () => buildBloc(),
      seed: () => const VoiceCallState(status: VoiceCallStatus.active),
      act: (bloc) =>
          bloc.add(const ServiceStateChanged(GeminiLiveState.disconnecting)),
      expect: () => [],
    );
  });

  group('LatencyUpdated', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'updates latencyMs in state',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const LatencyUpdated(150)),
      expect: () => [
        isA<VoiceCallState>().having((s) => s.latencyMs, 'latencyMs', 150),
      ],
    );
  });

  group('GenerateSessionSummary', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'generates summary via LLM service',
      setUp: () {
        when(
          () => mockLlmService.generateResponse(any()),
        ).thenAnswer((_) async => const LlmResponse(text: 'Nice session'));
      },
      build: () => buildBloc(llmService: mockLlmService),
      seed: () => const VoiceCallState(status: VoiceCallStatus.ended),
      act: (bloc) =>
          bloc.add(const GenerateSessionSummary(['You: Hi', 'AI: Hello'])),
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.generatingSummary,
          'generatingSummary',
          true,
        ),
        isA<VoiceCallState>()
            .having((s) => s.sessionSummary, 'sessionSummary', 'Nice session')
            .having((s) => s.generatingSummary, 'generatingSummary', false),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'does nothing without LLM service',
      build: () => buildBloc(),
      act: (bloc) => bloc.add(const GenerateSessionSummary(['You: Hi'])),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'does nothing with empty transcripts',
      build: () => buildBloc(llmService: mockLlmService),
      act: (bloc) => bloc.add(const GenerateSessionSummary([])),
      expect: () => [],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'handles LLM service error gracefully',
      setUp: () {
        when(
          () => mockLlmService.generateResponse(any()),
        ).thenThrow(Exception('LLM error'));
      },
      build: () => buildBloc(llmService: mockLlmService),
      seed: () => const VoiceCallState(status: VoiceCallStatus.ended),
      act: (bloc) => bloc.add(const GenerateSessionSummary(['You: Hi'])),
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.generatingSummary,
          'generatingSummary',
          true,
        ),
        isA<VoiceCallState>()
            .having((s) => s.generatingSummary, 'generatingSummary', false)
            .having((s) => s.sessionSummary, 'sessionSummary', isNull),
      ],
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'skips empty summary from NoOpLlmService',
      setUp: () {
        when(
          () => mockLlmService.generateResponse(any()),
        ).thenAnswer((_) async => const LlmResponse(text: '   '));
      },
      build: () => buildBloc(llmService: mockLlmService),
      seed: () => const VoiceCallState(status: VoiceCallStatus.ended),
      act: (bloc) => bloc.add(const GenerateSessionSummary(['You: Hi'])),
      expect: () => [
        isA<VoiceCallState>().having(
          (s) => s.generatingSummary,
          'generatingSummary',
          true,
        ),
        isA<VoiceCallState>()
            .having((s) => s.generatingSummary, 'generatingSummary', false)
            .having((s) => s.sessionSummary, 'sessionSummary', isNull),
      ],
    );
  });

  group('sendAudio', () {
    test('accumulates audio and forwards to service', () {
      final bloc = buildBloc();
      final data = Uint8List.fromList([10, 20, 30]);
      bloc.sendAudio(data);
      bloc.sendAudio(data);

      verify(() => mockService.sendAudio(data)).called(2);
      expect(bloc.recordedAudio, isNotNull);
      expect(bloc.recordedAudio!.length, 6);
      bloc.close();
    });

    test('recordedAudio is null when no audio recorded', () {
      final bloc = buildBloc();
      expect(bloc.recordedAudio, isNull);
      bloc.close();
    });
  });

  group('audioOutputStream', () {
    test('delegates to service audioStream', () {
      final bloc = buildBloc();
      expect(bloc.audioOutputStream, audioController.stream);
      bloc.close();
    });
  });

  group('VoiceCallState', () {
    test('timeRemaining is session limit minus elapsed', () {
      const state = VoiceCallState(elapsed: Duration(minutes: 3));
      expect(state.timeRemaining, const Duration(minutes: 7));
    });

    test('timeRemaining is zero when elapsed exceeds limit', () {
      const state = VoiceCallState(elapsed: Duration(minutes: 11));
      expect(state.timeRemaining, Duration.zero);
    });

    test('isNearTimeout is true at 9 minutes', () {
      const state = VoiceCallState(elapsed: Duration(minutes: 9));
      expect(state.isNearTimeout, true);
    });

    test('isNearTimeout is false at 8 minutes', () {
      const state = VoiceCallState(elapsed: Duration(minutes: 8));
      expect(state.isNearTimeout, false);
    });

    test('copyWith preserves values when no arguments given', () {
      const original = VoiceCallState(
        status: VoiceCallStatus.active,
        latencyMs: 100,
        elapsed: Duration(minutes: 2),
        showTimeWarning: true,
        uploadingAudio: true,
        generatingSummary: true,
      );
      final copied = original.copyWith();
      expect(copied.status, VoiceCallStatus.active);
      expect(copied.latencyMs, 100);
      expect(copied.elapsed, const Duration(minutes: 2));
      expect(copied.showTimeWarning, true);
      expect(copied.uploadingAudio, true);
      expect(copied.generatingSummary, true);
      // Note: error is cleared by copyWith when not passed (by design)
    });

    test('copyWith overrides specific fields', () {
      const original = VoiceCallState(status: VoiceCallStatus.idle);
      final copied = original.copyWith(
        status: VoiceCallStatus.active,
        latencyMs: 200,
        error: 'some error',
        audioUrl: 'https://example.com/audio.pcm',
        sessionSummary: 'Great session',
      );
      expect(copied.status, VoiceCallStatus.active);
      expect(copied.latencyMs, 200);
      expect(copied.error, 'some error');
      expect(copied.audioUrl, 'https://example.com/audio.pcm');
      expect(copied.sessionSummary, 'Great session');
    });

    test('props includes all fields for equality', () {
      const state1 = VoiceCallState(latencyMs: 100);
      const state2 = VoiceCallState(latencyMs: 100);
      const state3 = VoiceCallState(latencyMs: 200);
      expect(state1, state2);
      expect(state1, isNot(state3));
    });
  });

  group('VoiceCallEvent props', () {
    test('StartCall instances are equal', () {
      expect(const StartCall(), const StartCall());
    });

    test('EndCall instances are equal', () {
      expect(const EndCall(), const EndCall());
    });

    test('TranscriptReceived with same transcript are equal', () {
      const t = Transcript(speaker: Speaker.user, text: 'Hi');
      expect(const TranscriptReceived(t), const TranscriptReceived(t));
    });

    test('ToolCallReceived with same function call are equal', () {
      final fc = FunctionCall('save_entry', {'text': 'hi'}, id: 'id1');
      expect(ToolCallReceived(fc), ToolCallReceived(fc));
    });

    test('ServiceStateChanged with same state are equal', () {
      expect(
        const ServiceStateChanged(GeminiLiveState.active),
        const ServiceStateChanged(GeminiLiveState.active),
      );
    });

    test('ServiceStateChanged with different states are not equal', () {
      expect(
        const ServiceStateChanged(GeminiLiveState.active),
        isNot(const ServiceStateChanged(GeminiLiveState.error)),
      );
    });

    test('LatencyUpdated with same value are equal', () {
      expect(const LatencyUpdated(100), const LatencyUpdated(100));
    });

    test('LatencyUpdated with different values are not equal', () {
      expect(const LatencyUpdated(100), isNot(const LatencyUpdated(200)));
    });

    test('GenerateSessionSummary with same transcripts are equal', () {
      expect(
        const GenerateSessionSummary(['a', 'b']),
        const GenerateSessionSummary(['a', 'b']),
      );
    });

    test('GenerateSessionSummary with different transcripts are not equal', () {
      expect(
        const GenerateSessionSummary(['a']),
        isNot(const GenerateSessionSummary(['b'])),
      );
    });
  });

  group('SavedEntry', () {
    test('stores all fields correctly', () {
      const entry = SavedEntry(
        categoryId: 'positive',
        text: 'Great day',
        transcript: 'I had a great day',
      );
      expect(entry.categoryId, 'positive');
      expect(entry.text, 'Great day');
      expect(entry.transcript, 'I had a great day');
    });
  });

  group('close', () {
    test('disposes service and cancels timer', () async {
      final bloc = buildBloc();
      bloc.add(const StartCall());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await bloc.close();
      verify(() => mockService.dispose()).called(1);
    });
  });
}
