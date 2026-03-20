import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:record/record.dart';

import 'package:dytty/features/category_detail/review_call_controller.dart';
import 'package:dytty/features/category_detail/bloc/category_detail_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

// --- Mocks ---

class MockCategoryDetailBloc
    extends MockBloc<CategoryDetailEvent, CategoryDetailState>
    implements CategoryDetailBloc {}

class MockJournalBloc extends MockBloc<JournalEvent, JournalState>
    implements JournalBloc {}

class MockLlmService extends Mock implements LlmService {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

class MockVoiceCallBloc extends MockBloc<VoiceCallEvent, VoiceCallState>
    implements VoiceCallBloc {}

void main() {
  late MockCategoryDetailBloc mockDetailBloc;
  late MockJournalBloc mockJournalBloc;
  late MockLlmService mockLlmService;
  late MockAudioStorageService mockAudioStorage;

  setUpAll(() {
    registerFallbackValue(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
  });

  setUp(() {
    mockDetailBloc = MockCategoryDetailBloc();
    mockJournalBloc = MockJournalBloc();
    mockLlmService = MockLlmService();
    mockAudioStorage = MockAudioStorageService();

    when(() => mockDetailBloc.state).thenReturn(const CategoryDetailState());
  });

  ReviewCallController createController({
    String categoryId = 'positive',
    String? uid = 'test-user',
    void Function(String)? onError,
    AudioRecorder Function()? recorderFactory,
    AudioPlaybackService Function()? playbackFactory,
    GeminiLiveService Function()? geminiServiceFactory,
    VoiceCallBloc Function({
      required GeminiLiveService service,
      required JournalBloc journalBloc,
      required LlmService llmService,
      required AudioStorageService audioStorage,
      required String? uid,
    })?
    voiceCallBlocFactory,
  }) {
    return ReviewCallController(
      detailBloc: mockDetailBloc,
      journalBloc: mockJournalBloc,
      llmService: mockLlmService,
      audioStorage: mockAudioStorage,
      uid: uid,
      categoryId: categoryId,
      onError: onError ?? (_) {},
      recorderFactory: recorderFactory,
      playbackFactory: playbackFactory,
      geminiServiceFactory: geminiServiceFactory,
      voiceCallBlocFactory: voiceCallBlocFactory,
    );
  }

  group('ReviewCallController', () {
    test(
      'initial state: callActive is false, muted is false, elapsed is null',
      () {
        final controller = createController();

        expect(controller.callActive, false);
        expect(controller.muted, false);
        expect(controller.elapsed, isNull);
        expect(controller.voiceCallBloc, isNull);

        controller.dispose();
      },
    );

    test('dispose cleans up without error when no call is active', () {
      final controller = createController();

      // Should not throw
      expect(() => controller.dispose(), returnsNormally);
    });

    test('startCall sets callActive to true and notifies listeners', () async {
      final mockRecorder = MockAudioRecorder();
      final mockPlayback = MockAudioPlaybackService();
      final mockGemini = MockGeminiLiveService();
      final mockVoiceBloc = MockVoiceCallBloc();

      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockPlayback.init(
          sampleRate: any(named: 'sampleRate'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.connect(
          systemPrompt: any(named: 'systemPrompt'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.audioStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());
      when(
        () => mockRecorder.startStream(any()),
      ).thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => mockVoiceBloc.state).thenReturn(const VoiceCallState());
      when(
        () => mockVoiceBloc.stream,
      ).thenAnswer((_) => const Stream<VoiceCallState>.empty());
      when(
        () => mockVoiceBloc.audioOutputStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());

      // Cleanup stubs for dispose
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      when(() => mockPlayback.dispose()).thenReturn(null);
      when(() => mockGemini.dispose()).thenReturn(null);
      when(() => mockVoiceBloc.close()).thenAnswer((_) async {});

      bool notified = false;
      final controller = createController(
        recorderFactory: () => mockRecorder,
        playbackFactory: () => mockPlayback,
        geminiServiceFactory: () => mockGemini,
        voiceCallBlocFactory:
            ({
              required GeminiLiveService service,
              required JournalBloc journalBloc,
              required LlmService llmService,
              required AudioStorageService audioStorage,
              required String? uid,
            }) => mockVoiceBloc,
      );
      controller.addListener(() => notified = true);

      await controller.startCall();

      expect(controller.callActive, true);
      expect(notified, true);
      expect(controller.voiceCallBloc, mockVoiceBloc);

      controller.dispose();
    });

    test('startCall does nothing when recorder permission denied', () async {
      final mockRecorder = MockAudioRecorder();

      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});

      bool notified = false;
      final controller = createController(recorderFactory: () => mockRecorder);
      controller.addListener(() => notified = true);

      await controller.startCall();

      expect(controller.callActive, false);
      expect(notified, false);

      controller.dispose();
    });

    test('endCall sets callActive to false', () async {
      final mockRecorder = MockAudioRecorder();
      final mockPlayback = MockAudioPlaybackService();
      final mockGemini = MockGeminiLiveService();
      final mockVoiceBloc = MockVoiceCallBloc();

      // Set up startCall mocks
      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockPlayback.init(
          sampleRate: any(named: 'sampleRate'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.connect(
          systemPrompt: any(named: 'systemPrompt'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.audioStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());
      when(
        () => mockRecorder.startStream(any()),
      ).thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => mockVoiceBloc.state).thenReturn(const VoiceCallState());
      when(
        () => mockVoiceBloc.stream,
      ).thenAnswer((_) => const Stream<VoiceCallState>.empty());
      when(
        () => mockVoiceBloc.audioOutputStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());

      // Set up endCall mocks
      when(() => mockRecorder.stop()).thenAnswer((_) async => null);
      when(() => mockPlayback.stop()).thenAnswer((_) async {});

      // Cleanup stubs for dispose
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      when(() => mockPlayback.dispose()).thenReturn(null);
      when(() => mockGemini.dispose()).thenReturn(null);
      when(() => mockVoiceBloc.close()).thenAnswer((_) async {});

      final controller = createController(
        recorderFactory: () => mockRecorder,
        playbackFactory: () => mockPlayback,
        geminiServiceFactory: () => mockGemini,
        voiceCallBlocFactory:
            ({
              required GeminiLiveService service,
              required JournalBloc journalBloc,
              required LlmService llmService,
              required AudioStorageService audioStorage,
              required String? uid,
            }) => mockVoiceBloc,
      );

      await controller.startCall();
      expect(controller.callActive, true);

      await controller.endCall();
      expect(controller.callActive, false);

      controller.dispose();
    });

    test('error during connect calls onError callback', () async {
      final mockRecorder = MockAudioRecorder();
      final mockPlayback = MockAudioPlaybackService();
      final mockGemini = MockGeminiLiveService();
      final mockVoiceBloc = MockVoiceCallBloc();

      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockPlayback.init(
          sampleRate: any(named: 'sampleRate'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.connect(
          systemPrompt: any(named: 'systemPrompt'),
          tools: any(named: 'tools'),
        ),
      ).thenThrow(Exception('Connection refused'));
      when(
        () => mockGemini.audioStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());
      when(
        () => mockRecorder.startStream(any()),
      ).thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => mockVoiceBloc.state).thenReturn(const VoiceCallState());
      when(
        () => mockVoiceBloc.stream,
      ).thenAnswer((_) => const Stream<VoiceCallState>.empty());
      when(
        () => mockVoiceBloc.audioOutputStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());

      // endCall mocks (called after connect failure)
      when(() => mockRecorder.stop()).thenAnswer((_) async => null);
      when(() => mockPlayback.stop()).thenAnswer((_) async {});

      // Cleanup stubs for dispose
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      when(() => mockPlayback.dispose()).thenReturn(null);
      when(() => mockGemini.dispose()).thenReturn(null);
      when(() => mockVoiceBloc.close()).thenAnswer((_) async {});

      String? errorMessage;
      final controller = createController(
        onError: (msg) => errorMessage = msg,
        recorderFactory: () => mockRecorder,
        playbackFactory: () => mockPlayback,
        geminiServiceFactory: () => mockGemini,
        voiceCallBlocFactory:
            ({
              required GeminiLiveService service,
              required JournalBloc journalBloc,
              required LlmService llmService,
              required AudioStorageService audioStorage,
              required String? uid,
            }) => mockVoiceBloc,
      );

      await controller.startCall();

      expect(errorMessage, contains('Connection refused'));
      // Call should not remain active after error
      expect(controller.callActive, false);

      controller.dispose();
    });

    test('dispose cleans up active call resources', () async {
      final mockRecorder = MockAudioRecorder();
      final mockPlayback = MockAudioPlaybackService();
      final mockGemini = MockGeminiLiveService();
      final mockVoiceBloc = MockVoiceCallBloc();

      when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
      when(
        () => mockPlayback.init(
          sampleRate: any(named: 'sampleRate'),
          channels: any(named: 'channels'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.connect(
          systemPrompt: any(named: 'systemPrompt'),
          tools: any(named: 'tools'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockGemini.audioStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());
      when(
        () => mockRecorder.startStream(any()),
      ).thenAnswer((_) async => const Stream<Uint8List>.empty());
      when(() => mockVoiceBloc.state).thenReturn(const VoiceCallState());
      when(
        () => mockVoiceBloc.stream,
      ).thenAnswer((_) => const Stream<VoiceCallState>.empty());
      when(
        () => mockVoiceBloc.audioOutputStream,
      ).thenAnswer((_) => const Stream<Uint8List>.empty());

      // Cleanup mocks
      when(() => mockRecorder.dispose()).thenAnswer((_) async {});
      when(() => mockPlayback.dispose()).thenReturn(null);
      when(() => mockGemini.dispose()).thenReturn(null);
      // Note: AudioPlaybackService.dispose and GeminiLiveService.dispose return void
      when(() => mockVoiceBloc.close()).thenAnswer((_) async {});

      final controller = createController(
        recorderFactory: () => mockRecorder,
        playbackFactory: () => mockPlayback,
        geminiServiceFactory: () => mockGemini,
        voiceCallBlocFactory:
            ({
              required GeminiLiveService service,
              required JournalBloc journalBloc,
              required LlmService llmService,
              required AudioStorageService audioStorage,
              required String? uid,
            }) => mockVoiceBloc,
      );

      await controller.startCall();
      expect(controller.callActive, true);

      controller.dispose();

      verify(() => mockRecorder.dispose()).called(1);
      verify(() => mockPlayback.dispose()).called(1);
      verify(() => mockGemini.dispose()).called(1);
      verify(() => mockVoiceBloc.close()).called(1);
    });
  });
}
