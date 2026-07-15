import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:dytty/data/repositories/journal_repository.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/features/voice_call/voice_call_screen.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/llm/no_op_llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockVoiceCallBloc extends MockBloc<VoiceCallEvent, VoiceCallState>
    implements VoiceCallBloc {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

class MockAudioRecorder extends Mock implements AudioRecorder {}

/// #251: the call screen auto-connects on entry. No Ready state, no Start
/// Call button — the mic FAB IS the start gesture. Tests inject a recorder
/// whose permission check resolves to false, so the auto-attempt lands in
/// the deterministic PermissionDenied path — reaching it proves the screen
/// started the call by itself.
void main() {
  setUpAll(() {
    registerFallbackValue(const EndCall());
  });

  AudioRecorder deniedRecorder() {
    final recorder = MockAudioRecorder();
    when(recorder.hasPermission).thenAnswer((_) async => false);
    when(recorder.dispose).thenAnswer((_) async {});
    return recorder;
  }

  Widget harness({VoiceCallBloc? bloc, ThemeData? theme}) {
    final authBloc = MockAuthBloc();
    whenListen(
      authBloc,
      const Stream<AuthState>.empty(),
      initialState: const Authenticated(uid: 'autoconnect-test-uid'),
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider(
          create: (_) => JournalBloc(
            repository: JournalRepository(
              uid: 'autoconnect-test-uid',
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
        child: MaterialApp(
          theme: theme,
          home: VoiceCallScreen(bloc: bloc, recorderFactory: deniedRecorder),
        ),
      ),
    );
  }

  testWidgets('pumping the screen attempts the call without any tap (#251)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(); // post-frame auto-start
    await tester.pump(); // PermissionDenied reduces

    final ctx = tester.element(find.byType(Scaffold).first);
    final bloc = ctx.read<VoiceCallBloc>();
    expect(
      bloc.state.status,
      VoiceCallStatus.error,
      reason:
          'Auto-connect must fire on entry: the injected recorder denies '
          'permission, so reaching the error state proves the screen '
          'started the call by itself.',
    );
    expect(bloc.state.error, 'Microphone permission needed');
  });

  testWidgets('auto-start arms exactly once — rebuilds do not re-dispatch', (
    tester,
  ) async {
    final callBloc = MockVoiceCallBloc();
    whenListen(
      callBloc,
      const Stream<VoiceCallState>.empty(),
      initialState: const VoiceCallState(),
    );

    await tester.pumpWidget(harness(bloc: callBloc, theme: ThemeData.light()));
    await tester.pump();
    // Dependency change → didChangeDependencies fires again; the once-guard
    // must hold.
    await tester.pumpWidget(harness(bloc: callBloc, theme: ThemeData.dark()));
    await tester.pump();

    verify(() => callBloc.add(any())).called(1);
  });

  testWidgets('Ready state and Start Call button no longer exist', (
    tester,
  ) async {
    final callBloc = MockVoiceCallBloc();
    whenListen(
      callBloc,
      const Stream<VoiceCallState>.empty(),
      initialState: const VoiceCallState(), // idle
    );

    await tester.pumpWidget(harness(bloc: callBloc));
    await tester.pump();

    expect(find.text('Start Call'), findsNothing);
    expect(find.bySemanticsLabel('Start Call'), findsNothing);
    expect(find.text('Ready to connect'), findsNothing);
    // idle renders as already-connecting: auto-start makes idle transient
    expect(find.text('Connecting...'), findsOneWidget);
  });
}
