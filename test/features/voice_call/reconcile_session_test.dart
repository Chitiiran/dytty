import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dytty/data/models/category_entry.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

import '../../services/llm/fake_llm_service.dart';

class MockGeminiLiveService extends Mock implements GeminiLiveService {}

class MockJournalRepository extends Mock implements JournalRepository {}

void main() {
  late MockGeminiLiveService mockService;
  late MockJournalRepository mockRepo;
  late FakeLlmService fakeLlm;

  late StreamController<Transcript> transcriptController;
  late StreamController<FunctionCall> toolCallController;
  late StreamController<GeminiLiveState> stateController;
  late StreamController<Uint8List> audioController;
  late StreamController<int> latencyController;
  late StreamController<void> interruptController;

  // Counter so each created entry gets a distinct id.
  var _idCounter = 0;

  setUp(() {
    mockService = MockGeminiLiveService();
    mockRepo = MockJournalRepository();
    fakeLlm = FakeLlmService();
    _idCounter = 0;

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
    when(() => mockService.latencyP50).thenReturn(null);
    when(() => mockService.latencyP95).thenReturn(null);

    // Repository add returns a CategoryEntry with a fresh id.
    when(
      () => mockRepo.addCategoryEntry(
        any(),
        any(),
        any(),
        source: any(named: 'source'),
        transcript: any(named: 'transcript'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      _idCounter++;
      return CategoryEntry(
        id: 'new$_idCounter',
        categoryId: invocation.positionalArguments[1] as String,
        text: invocation.positionalArguments[2] as String,
        source: 'voice',
        createdAt: DateTime(2026, 1, 1),
      );
    });
  });

  tearDown(() {
    transcriptController.close();
    toolCallController.close();
    stateController.close();
    audioController.close();
    latencyController.close();
    interruptController.close();
  });

  VoiceCallBloc buildBloc() => VoiceCallBloc(
    service: mockService,
    journalRepository: mockRepo,
    llmService: fakeLlm,
    uid: 'u1',
  );

  // Seed a bloc's state with pre-saved entries via copyWith on its state.
  VoiceCallState seedState(List<SavedEntry> entries) =>
      const VoiceCallState().copyWith(savedEntries: entries);

  group('ReconcileSession', () {
    // Scenario 6: post-call ADDs a missed item.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'adds missed items returned by reconcileSession',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'negative',
            text: 'Had a rough day at work',
            sourceTranscript: 'rough day at work',
          ),
        ];
        return buildBloc();
      },
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'positive',
          text: 'Felt proud',
          transcript: '',
        ),
      ]),
      act: (b) => b.add(const ReconcileSession(transcript: 'long monologue')),
      verify: (b) {
        final added = b.state.savedEntries.where((e) => e.addedByAi).toList();
        expect(added, hasLength(1));
        expect(added.first.categoryId, 'negative');
        expect(added.first.entryId, isNotNull);
      },
    );

    // Scenario 7: post-call REWORDS an existing entry by id.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'rewords an existing entry by id',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.reword,
            entryId: 'e1',
            text: 'Paid for a sub I dislike but needed it for FIFA',
          ),
        ];
        return buildBloc();
      },
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'negative',
          text: 'Paid for a sub',
          transcript: '',
        ),
      ]),
      act: (b) =>
          b.add(const ReconcileSession(transcript: 'full FIFA sentence')),
      verify: (b) {
        final e = b.state.savedEntries.firstWhere((e) => e.entryId == 'e1');
        expect(e.rewordedByAi, isTrue);
        expect(e.text, contains('FIFA'));
      },
    );

    // Scenario 8: no changes when reconcile returns empty.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'makes no changes when reconcile returns empty',
      build: () {
        fakeLlm.reconcileResult = const [];
        return buildBloc();
      },
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'positive',
          text: 'Felt proud',
          transcript: '',
        ),
      ]),
      act: (b) => b.add(const ReconcileSession(transcript: 't')),
      verify: (b) {
        expect(b.state.savedEntries.where((e) => e.addedByAi), isEmpty);
        expect(b.state.savedEntries, hasLength(1));
      },
    );

    // Mechanical dedup backstop: drop an add matching existing
    // (category + normalized text), even if the LLM ignored the dedup rule.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'drops a duplicate add via mechanical backstop',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'positive',
            text: 'Felt Proud!', // same as existing after normalization
          ),
        ];
        return buildBloc();
      },
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'positive',
          text: 'felt proud',
          transcript: '',
        ),
      ]),
      act: (b) => b.add(const ReconcileSession(transcript: 't')),
      verify: (b) {
        expect(b.state.savedEntries.where((e) => e.addedByAi), isEmpty);
        expect(b.state.savedEntries, hasLength(1));
      },
    );

    // Unknown reword id is skipped, not crashed.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'skips reword for an unknown entry id',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.reword,
            entryId: 'does-not-exist',
            text: 'whatever',
          ),
        ];
        return buildBloc();
      },
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'positive',
          text: 'proud',
          transcript: '',
        ),
      ]),
      act: (b) => b.add(const ReconcileSession(transcript: 't')),
      verify: (b) {
        expect(b.state.savedEntries.where((e) => e.rewordedByAi), isEmpty);
      },
    );

    // Idempotency: a second ReconcileSession is a no-op.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'runs reconciliation only once per session',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'beauty',
            text: 'The sunset was unreal',
          ),
        ];
        return buildBloc();
      },
      seed: () => seedState(const []),
      act: (b) async {
        b.add(const ReconcileSession(transcript: 't'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        b.add(const ReconcileSession(transcript: 't'));
      },
      verify: (b) {
        expect(b.state.savedEntries.where((e) => e.addedByAi), hasLength(1));
      },
    );
  });

  group('EndCall triggers reconciliation', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'reconciles using the full transcript when the call ends',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'beauty',
            text: 'The sunset was unreal',
            sourceTranscript: 'the sunset was unreal',
          ),
        ];
        return buildBloc();
      },
      seed: () => const VoiceCallState().copyWith(
        transcripts: const [
          Transcript(
            speaker: Speaker.user,
            text: 'the sunset was unreal',
            isFinal: true,
          ),
        ],
      ),
      act: (b) => b.add(const EndCall()),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, VoiceCallStatus.ended);
        expect(b.state.savedEntries.where((e) => e.addedByAi), hasLength(1));
      },
    );

    blocTest<VoiceCallBloc, VoiceCallState>(
      'does not reconcile when transcript is empty',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'beauty',
            text: 'never added',
          ),
        ];
        return buildBloc();
      },
      seed: () => const VoiceCallState(),
      act: (b) => b.add(const EndCall()),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.savedEntries, isEmpty);
      },
    );
  });

  group('AcceptAllReconciled', () {
    blocTest<VoiceCallBloc, VoiceCallState>(
      'clears AI markers without removing entries',
      build: buildBloc,
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'beauty',
          text: 'sunset',
          transcript: '',
          addedByAi: true,
        ),
        SavedEntry(
          entryId: 'e2',
          categoryId: 'negative',
          text: 'rough',
          transcript: '',
          rewordedByAi: true,
        ),
      ]),
      act: (b) => b.add(const AcceptAllReconciled()),
      verify: (b) {
        expect(b.state.savedEntries, hasLength(2));
        expect(b.state.savedEntries.any((e) => e.addedByAi), isFalse);
        expect(b.state.savedEntries.any((e) => e.rewordedByAi), isFalse);
      },
    );
  });

  group('RejectReconciledEntry', () {
    setUp(() {
      when(
        () => mockRepo.deleteCategoryEntry(any(), any()),
      ).thenAnswer((_) async {});
    });

    blocTest<VoiceCallBloc, VoiceCallState>(
      'removes the entry from the post-call list',
      build: buildBloc,
      seed: () => seedState(const [
        SavedEntry(
          entryId: 'e1',
          categoryId: 'beauty',
          text: 'sunset',
          transcript: '',
          addedByAi: true,
        ),
        SavedEntry(
          entryId: 'e2',
          categoryId: 'positive',
          text: 'keep me',
          transcript: '',
        ),
      ]),
      act: (b) => b.add(const RejectReconciledEntry('e1')),
      verify: (b) {
        expect(b.state.savedEntries, hasLength(1));
        expect(b.state.savedEntries.first.entryId, 'e2');
        verify(() => mockRepo.deleteCategoryEntry(any(), 'e1')).called(1);
      },
    );
  });
}
