import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
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

    // #231: the lead from #224 was "an in-call save suppresses the post-call
    // reconcile". This locks in that reconcile STILL runs when an in-call
    // entry is already present — it dispatches on any non-empty transcript,
    // independent of in-call saves, and only ADDS the missed item.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'reconciles even when an in-call entry is already saved',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'gratitude',
            text: 'Grateful my sister called',
            sourceTranscript: 'sister called',
          ),
        ];
        return buildBloc();
      },
      seed: () => const VoiceCallState().copyWith(
        // An entry already saved DURING the call (origin in-call).
        savedEntries: const [
          SavedEntry(
            entryId: 'e1',
            categoryId: 'negative',
            text: 'Work was brutal',
            transcript: '',
          ),
        ],
        transcripts: const [
          Transcript(
            speaker: Speaker.user,
            text: 'work was brutal but grateful my sister called',
            isFinal: true,
          ),
        ],
      ),
      act: (b) => b.add(const EndCall()),
      wait: const Duration(milliseconds: 50),
      verify: (b) {
        expect(b.state.status, VoiceCallStatus.ended);
        // The pre-saved in-call entry is untouched...
        expect(
          b.state.savedEntries.any(
            (e) => e.entryId == 'e1' && !e.addedByAi && !e.rewordedByAi,
          ),
          isTrue,
        );
        // ...and the missed item was added by reconcile.
        final added = b.state.savedEntries.where((e) => e.addedByAi).toList();
        expect(added, hasLength(1));
        expect(added.first.categoryId, 'gratitude');
      },
    );

    // #232 (Gemini review): reconcile-add must write with a session date key
    // (yyyy-MM-dd), not crash/use a malformed key. Captures the date arg the
    // repository received and asserts it is a well-formed date string.
    blocTest<VoiceCallBloc, VoiceCallState>(
      'reconcile-add writes a yyyy-MM-dd session date key',
      build: () {
        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'beauty',
            text: 'The sky was gorgeous',
            sourceTranscript: 'sky',
          ),
        ];
        return buildBloc();
      },
      seed: () => const VoiceCallState().copyWith(
        transcripts: const [
          Transcript(speaker: Speaker.user, text: 'sky', isFinal: true),
        ],
      ),
      act: (b) => b.add(const EndCall()),
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        final captured = verify(
          () => mockRepo.addCategoryEntry(
            captureAny(),
            any(),
            any(),
            source: any(named: 'source'),
            transcript: any(named: 'transcript'),
            tags: any(named: 'tags'),
          ),
        ).captured;
        expect(captured, isNotEmpty);
        expect(captured.first, matches(r'^\d{4}-\d{2}-\d{2}$'));
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

  group('harness logging', () {
    test(
      'logs structured entry + reconciliation lines for verify.py',
      () async {
        final logs = <String>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) logs.add(message);
        };
        addTearDown(() => debugPrint = original);

        fakeLlm.reconcileResult = const [
          ReconciledItem(
            action: ReconcileAction.add,
            category: 'negative',
            text: 'Paid for a subscription I dislike',
            sourceTranscript: 'subscription i dislike',
          ),
          ReconciledItem(
            action: ReconcileAction.reword,
            entryId: 'e1',
            text: 'Happy participating in FIFA',
          ),
        ];
        final bloc = buildBloc();
        bloc.emit(
          const VoiceCallState().copyWith(
            savedEntries: const [
              SavedEntry(
                entryId: 'e1',
                categoryId: 'gratitude',
                text: 'FIFA',
                transcript: '',
              ),
            ],
          ),
        );
        bloc.add(const ReconcileSession(transcript: 'the FIFA sentence'));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          logs.any(
            (l) => l.contains(
              '[DYTTY] Entry saved: negative (origin: reconciled-add)',
            ),
          ),
          isTrue,
          reason: 'should log reconciled-add with category',
        );
        expect(
          logs.any((l) => l.contains('[DYTTY] Entry reworded: gratitude')),
          isTrue,
        );
        expect(
          logs.any(
            (l) => l.contains(
              '[DYTTY] Reconciliation complete: 1 added, 1 reworded',
            ),
          ),
          isTrue,
        );
        await bloc.close();
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
