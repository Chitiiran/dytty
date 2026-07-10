import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/features/voice_call/voice_call_screen.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/llm/no_op_llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

/// #224 regression guard.
///
/// The reconcile/reword pipeline requires VoiceCallBloc to be constructed with
/// a JournalRepository — `_onReconcileSession` silently no-ops without one.
/// The feature shipped dead once because every test built the bloc directly
/// with a mock repo while the SCREEN built it without any. This test pins the
/// production construction path: pump the real screen, grab the bloc it
/// created, assert the repository is wired.
void main() {
  testWidgets(
    'VoiceCallScreen constructs its bloc WITH a journal repository (#224)',
    (tester) async {
      final authBloc = MockAuthBloc();
      whenListen(
        authBloc,
        const Stream<AuthState>.empty(),
        initialState: const Authenticated(uid: 'wiring-test-uid'),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider(
              create: (_) => JournalBloc(
                repository: JournalRepository(
                  uid: 'wiring-test-uid',
                  firestore: FakeFirebaseFirestore(),
                ),
              ),
            ),
          ],
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<LlmService>(create: (_) => NoOpLlmService()),
              RepositoryProvider<AudioStorageService>(
                create: (_) => MockAudioStorageService(),
              ),
            ],
            child: const MaterialApp(home: VoiceCallScreen()),
          ),
        ),
      );

      // Read from a descendant of the screen's internal BlocProvider.value —
      // the screen's own element sits above it.
      final ctx = tester.element(find.byType(Scaffold).first);
      final bloc = ctx.read<VoiceCallBloc>();
      expect(
        bloc.hasJournalRepository,
        isTrue,
        reason:
            'Screen-built VoiceCallBloc has no JournalRepository: '
            'post-call reconciliation is a silent no-op in production '
            'and in-call saves cannot capture Firestore ids (#224).',
      );
    },
  );
}
