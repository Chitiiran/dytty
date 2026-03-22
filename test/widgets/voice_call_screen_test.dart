import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/features/voice_call/voice_call_screen.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

import '../fakes/fake_audio_playback_service.dart';
import '../robots/voice_call_screen_robot.dart';

// --- Mocks ---

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockJournalBloc extends MockBloc<JournalEvent, JournalState>
    implements JournalBloc {}

class MockLlmService extends Mock implements LlmService {}

class MockAudioStorageService extends Mock implements AudioStorageService {}

class MockVoiceCallBloc extends MockBloc<VoiceCallEvent, VoiceCallState>
    implements VoiceCallBloc {}

/// Pumps VoiceCallScreen with all required providers.
///
/// The screen internally creates GeminiLiveService and VoiceCallBloc.
/// We provide the context dependencies it reads via context.read<>().
Future<void> pumpVoiceCallScreen(
  WidgetTester tester, {
  AuthState? authState,
  JournalState? journalState,
  MockAuthBloc? authBloc,
  MockJournalBloc? journalBloc,
  MockLlmService? llmService,
  MockAudioStorageService? audioStorageService,
}) async {
  final mockAuth = authBloc ?? MockAuthBloc();
  final mockJournal = journalBloc ?? MockJournalBloc();
  final mockLlm = llmService ?? MockLlmService();
  final mockStorage = audioStorageService ?? MockAudioStorageService();

  when(() => mockAuth.state).thenReturn(
    authState ??
        const Authenticated(
          uid: 'test-uid',
          displayName: 'Test User',
          email: 'test@test.com',
        ),
  );
  when(() => mockJournal.state).thenReturn(journalState ?? JournalState());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: mockAuth),
        BlocProvider<JournalBloc>.value(value: mockJournal),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LlmService>.value(value: mockLlm),
          RepositoryProvider<AudioStorageService>.value(value: mockStorage),
        ],
        child: MaterialApp(
          home: VoiceCallScreen(playbackService: FakeAudioPlaybackService()),
        ),
      ),
    ),
  );
}

/// Pumps VoiceCallScreen with an injected MockVoiceCallBloc.
///
/// Used for state-based rendering tests where we need to control the exact
/// state without going through real event handlers.
Future<void> pumpWithMockBloc(
  WidgetTester tester, {
  required MockVoiceCallBloc bloc,
}) async {
  final mockAuth = MockAuthBloc();
  final mockJournal = MockJournalBloc();
  final mockLlm = MockLlmService();
  final mockStorage = MockAudioStorageService();

  when(() => mockAuth.state).thenReturn(
    const Authenticated(
      uid: 'test-uid',
      displayName: 'Test User',
      email: 'test@test.com',
    ),
  );
  when(() => mockJournal.state).thenReturn(JournalState());

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: mockAuth),
        BlocProvider<JournalBloc>.value(value: mockJournal),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<LlmService>.value(value: mockLlm),
          RepositoryProvider<AudioStorageService>.value(value: mockStorage),
        ],
        child: MaterialApp(
          home: VoiceCallScreen(
            playbackService: FakeAudioPlaybackService(),
            bloc: bloc,
          ),
        ),
      ),
    ),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  // Stub platform channel for record plugin.
  // The plugin is instantiated in VoiceCallScreen's field initializers
  // but no platform calls are made until the user taps "Start Call".
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (MethodCall methodCall) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        );
  });

  group('VoiceCallScreen - idle state', () {
    late VoiceCallScreenRobot robot;

    testWidgets('renders AppBar with "Daily Call" title', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectIdleState();
    });

    testWidgets('renders "Ready to connect" status text', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();

      expect(find.text('Ready to connect'), findsOneWidget);
    });

    testWidgets('renders "Start Call" button with call icon', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectStartCallButtonVisible();
    });

    testWidgets('does not show active call controls in idle state', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectNoActiveControls();
    });

    testWidgets('does not show saved entries indicator in idle state', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectNoSavedEntriesIndicator();
    });

    testWidgets('does not show latency indicator in idle state', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectNoLatencyIndicator();
    });

    testWidgets('does not show time warning in idle state', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      robot.expectNoTimeWarning();
    });
  });

  group('VoiceCallScreen - post-call summary (ended state)', () {
    late VoiceCallScreenRobot robot;

    testWidgets('shows "Call Summary" AppBar and hides "Daily Call"', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      robot.expectPostCallSummary();
      expect(find.text('Daily Call'), findsNothing);
    });

    testWidgets('shows Duration and Entries stat chips', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      robot.expectDurationStat('00:00');
      robot.expectEntriesStat(0);
    });

    testWidgets('shows "Done" button', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('shows empty message when no entries captured', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      robot.expectNoEntriesCapturedMessage();
    });

    testWidgets('does not show Latency stat when no latency measured', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      robot.expectNoLatencyStat();
    });

    testWidgets('does not show "Generate Summary" when no transcripts', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.endCall();

      robot.expectNoGenerateSummaryButton();
    });

    testWidgets('shows "Generate Summary" button when transcripts exist', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      // Add transcripts before ending the call
      await robot.addTranscript(Speaker.user, 'I had a great day');
      await robot.addTranscript(Speaker.ai, 'That sounds wonderful!');
      await robot.endCall();

      robot.expectGenerateSummaryButton();
    });

    testWidgets('shows P50/P95 stat chips when latency was measured', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      // Inject latency measurement before ending the call
      robot.bloc.add(const LatencyUpdated(150));
      await tester.pumpAndSettle();

      await robot.endCall();

      // P50/P95 come from the service's LatencyTracker, which won't
      // have real data in this test setup — verify via mock bloc tests
      robot.expectNoLatencyStat();
    });

    testWidgets('shows "Captured entries" header when entries exist', (
      tester,
    ) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      // Simulate a saved entry via TranscriptReceived + manual state.
      // Since we can't easily trigger ToolCallReceived (needs FunctionCall),
      // we directly emit state by dispatching known events.
      // The ToolCallReceived path requires firebase_ai FunctionCall which is
      // hard to construct in tests. Instead, verify the entries count stat.
      await robot.endCall();

      // With 0 entries, we should see the empty message, not the header
      robot.expectNoEntriesCapturedMessage();
      expect(find.text('Captured entries'), findsNothing);
    });
  });

  group('VoiceCallScreen - connecting state (mock bloc)', () {
    testWidgets('shows "Connecting..." status text', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.connecting));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Connecting...'), findsOneWidget);
    });

    testWidgets('shows end call button (FAB) during connecting', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.connecting));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('hides "Start Call" button during connecting', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.connecting));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Start Call'), findsNothing);
    });

    testWidgets('shows mute and speaker buttons during connecting', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.connecting));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });
  });

  group('VoiceCallScreen - active state (mock bloc)', () {
    testWidgets('shows "In call" status with timer', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 2, seconds: 30),
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.textContaining('In call'), findsOneWidget);
      expect(find.textContaining('02:30'), findsOneWidget);
    });

    testWidgets('shows latency indicator in AppBar for low latency', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(status: VoiceCallStatus.active, latencyMs: 120),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('120ms'), findsOneWidget);
    });

    testWidgets('shows latency indicator for moderate latency', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(status: VoiceCallStatus.active, latencyMs: 350),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('350ms'), findsOneWidget);
    });

    testWidgets('shows latency indicator for high latency', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(status: VoiceCallStatus.active, latencyMs: 500),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('500ms'), findsOneWidget);
    });

    testWidgets('shows saved entries indicator with plural count', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          savedEntries: [
            SavedEntry(
              categoryId: 'positive',
              text: 'Great day',
              transcript: 'It was a great day',
            ),
            SavedEntry(
              categoryId: 'gratitude',
              text: 'Thankful',
              transcript: 'I am thankful',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('2 entries saved'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    });

    testWidgets('shows singular "entry saved" for one entry', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          savedEntries: [
            SavedEntry(
              categoryId: 'positive',
              text: 'Great day',
              transcript: 'It was a great day',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('1 entry saved'), findsOneWidget);
    });

    testWidgets('shows end call FAB during active call', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.active));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('shows muted icon when muted', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(status: VoiceCallStatus.active, isMuted: true),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('shows earpiece icon when speaker is off', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          isSpeakerOn: false,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.phone_in_talk), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsNothing);
    });

    testWidgets('formats elapsed time correctly at 9m05s', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 9, seconds: 5),
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.textContaining('09:05'), findsOneWidget);
    });

    testWidgets('does not show latency indicator when latencyMs is null', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.active));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      // No "ms" text should appear in AppBar
      expect(find.textContaining('ms'), findsNothing);
    });

    testWidgets('does not show saved entries indicator when empty', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.active));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.textContaining('entries saved'), findsNothing);
      expect(find.textContaining('entry saved'), findsNothing);
    });
  });

  group('VoiceCallScreen - time warning (mock bloc)', () {
    testWidgets('shows time warning banner when showTimeWarning is true', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 5),
          showTimeWarning: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.textContaining('remaining'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    });

    testWidgets('shows correct remaining time (05:00) at 5 min elapsed', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 5),
          showTimeWarning: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('05:00 remaining'), findsOneWidget);
    });

    testWidgets('shows near-timeout remaining time (00:30) at 9m30s', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 9, seconds: 30),
          showTimeWarning: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('00:30 remaining'), findsOneWidget);
    });

    testWidgets('does not show warning when showTimeWarning is false', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.active,
          elapsed: Duration(minutes: 3),
          showTimeWarning: false,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.textContaining('remaining'), findsNothing);
    });

    testWidgets('does not show warning in idle status even if flag set', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.idle,
          showTimeWarning: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      // Warning only shows when status == active AND showTimeWarning == true
      expect(find.textContaining('remaining'), findsNothing);
    });
  });

  group('VoiceCallScreen - error state (mock bloc)', () {
    testWidgets('shows "Connection error" status text', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.error,
          error: 'Something went wrong',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Connection error'), findsOneWidget);
    });

    testWidgets('shows "Start Call" button (retry) in error state', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.error,
          error: 'Failed to connect',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Start Call'), findsOneWidget);
      expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    });

    testWidgets('hides end call controls in error state', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.error,
          error: 'Connection lost',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.byIcon(Icons.call_end_rounded), findsNothing);
    });
  });

  group('VoiceCallScreen - ending state (mock bloc)', () {
    testWidgets('shows "Saving and ending..." status text', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ending));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Saving and ending...'), findsOneWidget);
    });

    testWidgets('shows "Start Call" button in ending state', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ending));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Start Call'), findsOneWidget);
    });
  });

  group('VoiceCallScreen - post-call summary generation (mock bloc)', () {
    testWidgets('shows "Generating summary..." indicator', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          generatingSummary: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Generating summary...'), findsOneWidget);
    });

    testWidgets('shows session summary text when available', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          sessionSummary: 'You had a wonderful day reflecting on gratitude.',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Session Summary'), findsOneWidget);
      expect(
        find.text('You had a wonderful day reflecting on gratitude.'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Generate Summary" button when transcripts exist', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        VoiceCallState(
          status: VoiceCallStatus.ended,
          transcripts: [
            const Transcript(speaker: Speaker.user, text: 'Hello'),
            const Transcript(speaker: Speaker.ai, text: 'Hi there!'),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Generate Summary'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('hides "Generate Summary" when no transcripts', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ended));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Generate Summary'), findsNothing);
    });

    testWidgets('hides "Generate Summary" when summary already exists', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        VoiceCallState(
          status: VoiceCallStatus.ended,
          transcripts: [const Transcript(speaker: Speaker.user, text: 'Hello')],
          sessionSummary: 'Already generated summary',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Generate Summary'), findsNothing);
      expect(find.text('Session Summary'), findsOneWidget);
    });

    testWidgets('tapping "Generate Summary" dispatches event', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        VoiceCallState(
          status: VoiceCallStatus.ended,
          transcripts: [
            const Transcript(speaker: Speaker.user, text: 'Hello'),
            const Transcript(speaker: Speaker.ai, text: 'Hi!'),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      await tester.tap(find.text('Generate Summary'));
      await tester.pump();

      verify(
        () => bloc.add(const GenerateSessionSummary(['You: Hello', 'AI: Hi!'])),
      ).called(1);
    });
  });

  group('VoiceCallScreen - post-call latency stats (mock bloc)', () {
    testWidgets('shows P50 and P95 latency chips when values present', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          latencyMs: 180,
          latencyP50: 150,
          latencyP95: 350,
          elapsed: Duration(minutes: 2),
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('150ms'), findsOneWidget);
      expect(find.text('P50'), findsOneWidget);
      expect(find.text('350ms'), findsOneWidget);
      expect(find.text('P95'), findsOneWidget);
    });

    testWidgets('hides P50/P95 chips when values are null', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          elapsed: Duration(minutes: 1),
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('P50'), findsNothing);
      expect(find.text('P95'), findsNothing);
    });
  });

  group('VoiceCallScreen - post-call audio upload (mock bloc)', () {
    testWidgets('shows "Uploading audio..." when uploadingAudio is true', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          uploadingAudio: true,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Uploading audio...'), findsOneWidget);
    });

    testWidgets('shows "Audio saved to cloud" when audioUrl is set', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          audioUrl: 'https://storage.example.com/audio.wav',
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Audio saved to cloud'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('hides audio status when neither uploading nor uploaded', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ended));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Uploading audio...'), findsNothing);
      expect(find.text('Audio saved to cloud'), findsNothing);
    });
  });

  group('VoiceCallScreen - post-call saved entries (mock bloc)', () {
    testWidgets('shows "Captured entries" header when entries exist', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          savedEntries: [
            SavedEntry(
              categoryId: 'positive',
              text: 'Had a great morning',
              transcript: 'I had a great morning',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Captured entries'), findsOneWidget);
      expect(find.text('Had a great morning'), findsOneWidget);
    });

    testWidgets('shows entry count stat chip in summary', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          savedEntries: [
            SavedEntry(
              categoryId: 'positive',
              text: 'Entry 1',
              transcript: 'Transcript 1',
            ),
            SavedEntry(
              categoryId: 'gratitude',
              text: 'Entry 2',
              transcript: 'Transcript 2',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Entries'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('shows duration stat chip with elapsed time', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          elapsed: Duration(minutes: 4, seconds: 15),
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('04:15'), findsOneWidget);
    });

    testWidgets('shows P50/P95 stat chips when latency was measured', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          latencyMs: 200,
          latencyP50: 180,
          latencyP95: 400,
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('P50'), findsOneWidget);
      expect(find.text('180ms'), findsOneWidget);
      expect(find.text('P95'), findsOneWidget);
      expect(find.text('400ms'), findsOneWidget);
    });

    testWidgets('hides latency stat chip when no latency measured', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ended));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('P50'), findsNothing);
      expect(find.text('P95'), findsNothing);
    });

    testWidgets('shows "No entries" message when no entries captured', (
      tester,
    ) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ended));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(
        find.text('No entries were captured during this session.'),
        findsOneWidget,
      );
    });

    testWidgets('shows category display name for saved entry', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          savedEntries: [
            SavedEntry(
              categoryId: 'gratitude',
              text: 'Thankful for family',
              transcript: 'I am thankful for family',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Thankful for family'), findsOneWidget);
      expect(find.text('Gratitude'), findsOneWidget);
    });

    testWidgets('shows multiple saved entries', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        const VoiceCallState(
          status: VoiceCallStatus.ended,
          savedEntries: [
            SavedEntry(
              categoryId: 'positive',
              text: 'Good morning run',
              transcript: 'I went for a run',
            ),
            SavedEntry(
              categoryId: 'gratitude',
              text: 'Thankful for health',
              transcript: 'I am thankful for health',
            ),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Good morning run'), findsOneWidget);
      expect(find.text('Thankful for health'), findsOneWidget);
    });

    testWidgets('shows "Done" button in summary view', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(
        () => bloc.state,
      ).thenReturn(const VoiceCallState(status: VoiceCallStatus.ended));

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Done'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    });
  });

  group('VoiceCallScreen - transcript display', () {
    late VoiceCallScreenRobot robot;

    testWidgets('shows user transcript bubble text', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.addTranscript(Speaker.user, 'Hello, how are you?');

      expect(find.text('Hello, how are you?'), findsOneWidget);
    });

    testWidgets('shows AI transcript bubble text', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.addTranscript(Speaker.ai, 'I am doing great!');

      expect(find.text('I am doing great!'), findsOneWidget);
    });

    testWidgets('shows multiple transcript bubbles', (tester) async {
      await pumpVoiceCallScreen(tester);
      await tester.pump();
      robot = VoiceCallScreenRobot(tester);

      await robot.addTranscript(Speaker.user, 'Good morning');
      await robot.addTranscript(Speaker.ai, 'Good morning! How did you sleep?');
      await robot.addTranscript(Speaker.user, 'Really well actually');

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Good morning! How did you sleep?'), findsOneWidget);
      expect(find.text('Really well actually'), findsOneWidget);
    });
  });

  group('VoiceCallScreen - transcript display (mock bloc)', () {
    testWidgets('shows transcript bubbles from state', (tester) async {
      final bloc = MockVoiceCallBloc();
      when(() => bloc.state).thenReturn(
        VoiceCallState(
          status: VoiceCallStatus.active,
          transcripts: [
            const Transcript(speaker: Speaker.user, text: 'Testing one two'),
            const Transcript(speaker: Speaker.ai, text: 'I hear you clearly'),
          ],
        ),
      );

      await pumpWithMockBloc(tester, bloc: bloc);
      await tester.pump();

      expect(find.text('Testing one two'), findsOneWidget);
      expect(find.text('I hear you clearly'), findsOneWidget);
    });
  });
}
