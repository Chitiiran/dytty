import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

import '../../services/llm/fake_llm_service.dart';

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalBloc extends Mock implements JournalBloc {}

/// #250: the production call path writes repository-direct (id capture,
/// #224/#232) and previously never told JournalBloc — home progress icons
/// and the calendar circle stayed stale after a call saved entries. Every
/// successful repo write must be mirrored as a state-only absorb event
/// under the session date.
void main() {
  late MockGeminiLiveService mockService;
  late MockJournalRepository mockRepo;
  late MockJournalBloc mockJournalBloc;
  late FakeLlmService fakeLlm;

  late StreamController<Transcript> transcriptController;
  late StreamController<FunctionCall> toolCallController;
  late StreamController<GeminiLiveState> stateController;
  late StreamController<Uint8List> audioController;
  late StreamController<int> latencyController;
  late StreamController<void> interruptController;

  setUpAll(() {
    registerFallbackValue(
      ExternalEntryAdded(
        entry: CategoryEntry(
          id: 'x',
          categoryId: 'positive',
          text: 'x',
          createdAt: DateTime(2026),
        ),
        date: DateTime(2026),
      ),
    );
    registerFallbackValue(
      ExternalEntryRemoved(
        entryId: 'x',
        categoryId: 'positive',
        date: DateTime(2026),
      ),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockService = MockGeminiLiveService();
    mockRepo = MockJournalRepository();
    mockJournalBloc = MockJournalBloc();
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
  });

  tearDown(() {
    transcriptController.close();
    toolCallController.close();
    stateController.close();
    audioController.close();
    latencyController.close();
    interruptController.close();
  });

  group('save_entry propagation', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'in-call save dispatches ExternalEntryAdded under the session date',
      build: () => VoiceCallBloc(
        service: mockService,
        journalBloc: mockJournalBloc,
        journalRepository: mockRepo,
        uid: 'u1',
      ),
      act: (bloc) async {
        bloc.debugSetSessionDate('2020-01-03');
        bloc.add(
          ToolCallReceived(
            FunctionCall('save_entry', {
              'category': 'positive',
              'text': 'saved in call',
              'transcript': 'src',
            }),
          ),
        );
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        final dispatched = verify(
          () => mockJournalBloc.add(captureAny()),
        ).captured;
        final absorb = dispatched.whereType<ExternalEntryAdded>().single;
        expect(absorb.entry.id, 'new1');
        expect(absorb.entry.categoryId, 'positive');
        expect(DateFormat('yyyy-MM-dd').format(absorb.date), '2020-01-03');
        // Single writer holds: absorb event only, no persisting bloc event.
        expect(dispatched.whereType<AddVoiceEntry>(), isEmpty);
      },
    );

    test(
      'save_entry updates real JournalBloc home aggregates (#250 repro)',
      () async {
        final journalBloc = JournalBloc(repository: mockRepo);
        final bloc = VoiceCallBloc(
          service: mockService,
          journalBloc: journalBloc,
          journalRepository: mockRepo,
          uid: 'u1',
        );
        bloc.add(
          ToolCallReceived(
            FunctionCall('save_entry', {
              'category': 'positive',
              'text': 'call entry',
              'transcript': 'src',
            }),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          journalBloc.state.todayCategoryCounts['positive'],
          1,
          reason:
              'home ring reads todayCategoryCounts — a call save must reach '
              'it without restart (#250)',
        );
        expect(journalBloc.state.journaledToday, isTrue);
        await bloc.close();
        await journalBloc.close();
      },
    );
  });

  group('reconcile-add propagation', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'post-call reconcile add dispatches ExternalEntryAdded',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'gratitude',
            text: 'missed item',
            sourceTranscript: 'src',
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
      act: (bloc) async {
        bloc.debugSetSessionDate('2020-01-03');
        bloc.add(const ReconcileSession(transcript: 'You: hi'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        final dispatched = verify(
          () => mockJournalBloc.add(captureAny()),
        ).captured;
        final absorb = dispatched.whereType<ExternalEntryAdded>().single;
        expect(absorb.entry.categoryId, 'gratitude');
        expect(DateFormat('yyyy-MM-dd').format(absorb.date), '2020-01-03');
      },
    );
  });

  group('reject propagation', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'post-call reject dispatches ExternalEntryRemoved, not DeleteEntry',
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
        bloc.debugSetSessionDate('2020-01-03');
        bloc.add(const RejectReconciledEntry('e1'));
      },
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        final dispatched = verify(
          () => mockJournalBloc.add(captureAny()),
        ).captured;
        final removed = dispatched.whereType<ExternalEntryRemoved>().single;
        expect(removed.entryId, 'e1');
        expect(removed.categoryId, 'positive');
        expect(DateFormat('yyyy-MM-dd').format(removed.date), '2020-01-03');
        expect(dispatched.whereType<DeleteEntry>(), isEmpty);
        verify(
          () => mockRepo.deleteCategoryEntry('2020-01-03', 'e1'),
        ).called(1);
      },
    );
  });

  group('no double-count paths', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'edit_entry dispatches no absorb event (text-only, no aggregate change)',
      build: () => VoiceCallBloc(
        service: mockService,
        journalBloc: mockJournalBloc,
        journalRepository: mockRepo,
      ),
      act: (bloc) => bloc.add(
        ToolCallReceived(
          FunctionCall('edit_entry', {'entry_id': 'e1', 'text': 'better'}),
        ),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (_) {
        verifyNever(
          () => mockJournalBloc.add(any(that: isA<ExternalEntryAdded>())),
        );
      },
    );
  });
}
