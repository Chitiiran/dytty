import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

import '../../services/llm/fake_llm_service.dart';

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalBloc extends Mock implements JournalBloc {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

/// #232 follow-through: every persistence path of a call session must write
/// to the SAME pinned session date through ONE writer (the repository when
/// wired). Before these fixes: audio uploads were keyed to DateTime.now()
/// (wrong day for midnight-spanning calls), in-call edit_entry only worked
/// via the optional JournalBloc (same optionality trap as #224), and
/// reword/reject double-wrote through bloc events that target the user's
/// currently-SELECTED date — the wrong doc after calendar browsing.
void main() {
  late MockGeminiLiveService mockService;
  late MockJournalRepository mockRepo;
  late MockJournalBloc mockJournalBloc;
  late MockAudioStorageService mockStorage;
  late FakeLlmService fakeLlm;

  late StreamController<Transcript> transcriptController;
  late StreamController<FunctionCall> toolCallController;
  late StreamController<GeminiLiveState> stateController;
  late StreamController<Uint8List> audioController;
  late StreamController<int> latencyController;
  late StreamController<void> interruptController;

  setUpAll(() {
    registerFallbackValue(const UpdateEntry(entryId: '', text: ''));
    registerFallbackValue(const DeleteEntry(''));
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockService = MockGeminiLiveService();
    mockRepo = MockJournalRepository();
    mockJournalBloc = MockJournalBloc();
    mockStorage = MockAudioStorageService();
    fakeLlm = FakeLlmService();

    transcriptController = StreamController<Transcript>.broadcast();
    toolCallController = StreamController<FunctionCall>.broadcast();
    stateController = StreamController<GeminiLiveState>.broadcast();
    audioController = StreamController<Uint8List>.broadcast();
    latencyController = StreamController<int>.broadcast();
    interruptController = StreamController<void>.broadcast();

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
    when(
      () => mockService.latencyStream,
    ).thenAnswer((_) => latencyController.stream);
    when(
      () => mockService.interruptStream,
    ).thenAnswer((_) => interruptController.stream);
    when(() => mockService.dispose()).thenReturn(null);
    when(() => mockService.disconnect()).thenAnswer((_) async {});
    when(() => mockService.connect()).thenAnswer((_) async {});
    when(() => mockService.sendAudio(any())).thenReturn(null);
    when(() => mockService.latencyP50).thenReturn(null);
    when(() => mockService.latencyP95).thenReturn(null);
    when(
      () => mockService.sendToolResponse(any(), any(), any()),
    ).thenAnswer((_) async {});

    when(
      () => mockRepo.addCategoryEntry(
        any(),
        any(),
        any(),
        source: any(named: 'source'),
        transcript: any(named: 'transcript'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer(
      (inv) async => CategoryEntry(
        id: 'new1',
        categoryId: inv.positionalArguments[1] as String,
        text: inv.positionalArguments[2] as String,
        source: 'voice',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    when(
      () => mockRepo.updateCategoryEntry(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockRepo.deleteCategoryEntry(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockStorage.uploadCallAudio(
        uid: any(named: 'uid'),
        date: any(named: 'date'),
        audioData: any(named: 'audioData'),
      ),
    ).thenAnswer((_) async => 'https://audio.example/x.pcm');
  });

  tearDown(() {
    transcriptController.close();
    toolCallController.close();
    stateController.close();
    audioController.close();
    latencyController.close();
    interruptController.close();
  });

  group('audio upload date (#232 parity)', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'uploads call audio under the pinned session date, not today',
      build: () => VoiceCallBloc(
        service: mockService,
        journalRepository: mockRepo,
        audioStorage: mockStorage,
        uid: 'u1',
      ),
      act: (bloc) async {
        bloc.debugSetSessionDate('2020-01-01');
        bloc.sendAudio(Uint8List.fromList([1, 2, 3]));
        bloc.add(const EndCall());
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockStorage.uploadCallAudio(
            uid: 'u1',
            date: '2020-01-01',
            audioData: any(named: 'audioData'),
          ),
        ).called(1);
      },
    );
  });

  group('in-call edit_entry persistence', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'writes through the repository under the session date when wired',
      build: () => VoiceCallBloc(
        service: mockService,
        journalRepository: mockRepo,
        uid: 'u1',
      ),
      act: (bloc) async {
        bloc.debugSetSessionDate('2020-01-01');
        bloc.add(
          ToolCallReceived(
            FunctionCall('edit_entry', {'entry_id': 'e1', 'text': 'better'}),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockRepo.updateCategoryEntry('2020-01-01', 'e1', 'better'),
        ).called(1);
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'does not double-write via JournalBloc when the repository is wired',
      build: () => VoiceCallBloc(
        service: mockService,
        journalBloc: mockJournalBloc,
        journalRepository: mockRepo,
        uid: 'u1',
      ),
      act: (bloc) async {
        bloc.add(
          ToolCallReceived(
            FunctionCall('edit_entry', {'entry_id': 'e1', 'text': 'better'}),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockRepo.updateCategoryEntry(any(), 'e1', 'better'),
        ).called(1);
        verifyNever(() => mockJournalBloc.add(any(that: isA<UpdateEntry>())));
      },
    );
  });

  group('lifecycle robustness', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'retry after a connection error does not duplicate subscriptions',
      build: () => VoiceCallBloc(service: mockService),
      act: (bloc) async {
        bloc.add(const StartCall());
        await Future<void>.delayed(Duration.zero);
        // Connection drops...
        stateController.add(GeminiLiveState.error);
        await Future<void>.delayed(Duration.zero);
        // ...user retries. Before the fix this re-subscribed every service
        // stream without cancelling the old listeners, so each service event
        // was handled twice for the rest of the session.
        bloc.add(const StartCall());
        await Future<void>.delayed(Duration.zero);
        transcriptController.add(
          const Transcript(speaker: Speaker.user, text: 'once', isFinal: true),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(
          bloc.state.transcripts.length,
          1,
          reason:
              'One service transcript event must produce exactly one '
              'bubble; duplicates mean stale subscriptions survived retry.',
        );
      },
    );

    test('closing the bloc mid-upload does not throw emit-after-close', () {
      return runZonedGuarded(
        () async {
          final uploadGate = Completer<String>();
          when(
            () => mockStorage.uploadCallAudio(
              uid: any(named: 'uid'),
              date: any(named: 'date'),
              audioData: any(named: 'audioData'),
            ),
          ).thenAnswer((_) => uploadGate.future);

          final bloc = VoiceCallBloc(
            service: mockService,
            audioStorage: mockStorage,
            uid: 'u1',
          );
          // A transcript makes _onEndCall reach its trailing
          // add(ReconcileSession) — the add-after-close hazard under test.
          bloc.add(
            const TranscriptReceived(
              Transcript(speaker: Speaker.user, text: 'hello', isFinal: true),
            ),
          );
          bloc.sendAudio(Uint8List.fromList([1]));
          bloc.add(const EndCall());
          await Future<void>.delayed(const Duration(milliseconds: 5));
          // Screen popped (Done button) while the upload is still in flight.
          await bloc.close();
          uploadGate.complete('https://audio.example/late.pcm');
          await Future<void>.delayed(const Duration(milliseconds: 5));
        },
        (error, stack) {
          fail('emit after close leaked out of the handler: $error');
        },
      );
    });
  });

  group('mute privacy', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'muted mic audio is neither sent nor recorded for upload',
      build: () => VoiceCallBloc(
        service: mockService,
        journalRepository: mockRepo,
        audioStorage: mockStorage,
        uid: 'u1',
      ),
      act: (bloc) async {
        bloc.add(const ToggleMute());
        await Future<void>.delayed(Duration.zero);
        bloc.sendAudio(Uint8List.fromList([9, 9, 9]));
      },
      verify: (bloc) {
        verifyNever(() => mockService.sendAudio(any()));
        expect(
          bloc.recordedAudio,
          isNull,
          reason:
              'Muted audio must not be buffered — the buffer is uploaded '
              'to Cloud Storage after the call (privacy).',
        );
      },
    );
  });

  group('reword/reject single-writer (#232)', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'reword persists via repository only — no JournalBloc UpdateEntry',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.reword,
            category: 'positive',
            text: 'complete text',
            sourceTranscript: 'src',
            entryId: 'e1',
          ),
        ];
        return VoiceCallBloc(
          service: mockService,
          journalBloc: mockJournalBloc,
          journalRepository: mockRepo,
          llmService: fakeLlm,
          uid: 'u1',
        );
      },
      seed: () => const VoiceCallState().copyWith(
        savedEntries: const [
          SavedEntry(
            entryId: 'e1',
            categoryId: 'positive',
            text: 'partial',
            transcript: 'src',
          ),
        ],
      ),
      act: (bloc) => bloc.add(const ReconcileSession(transcript: 'You: hi')),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockRepo.updateCategoryEntry(any(), 'e1', any()),
        ).called(1);
        verifyNever(() => mockJournalBloc.add(any(that: isA<UpdateEntry>())));
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'reject deletes via repository only, even without uid',
      build: () => VoiceCallBloc(
        service: mockService,
        journalBloc: mockJournalBloc,
        journalRepository: mockRepo,
      ),
      seed: () => const VoiceCallState().copyWith(
        savedEntries: const [
          SavedEntry(
            entryId: 'e1',
            categoryId: 'positive',
            text: 't',
            transcript: 's',
          ),
        ],
      ),
      act: (bloc) async {
        bloc.debugSetSessionDate('2020-01-01');
        bloc.add(const RejectReconciledEntry('e1'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verify(
          () => mockRepo.deleteCategoryEntry('2020-01-01', 'e1'),
        ).called(1);
        verifyNever(() => mockJournalBloc.add(any(that: isA<DeleteEntry>())));
      },
    );
  });
}
