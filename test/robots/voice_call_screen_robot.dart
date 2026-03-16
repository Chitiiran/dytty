import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

/// Robot for interacting with and asserting on the VoiceCallScreen widget.
class VoiceCallScreenRobot {
  VoiceCallScreenRobot(this.tester);
  final WidgetTester tester;

  /// Gets the internal VoiceCallBloc from the widget tree.
  /// The screen provides it via BlocProvider.value in its build method.
  VoiceCallBloc get bloc {
    final element = tester.element(find.byType(Scaffold).first);
    return BlocProvider.of<VoiceCallBloc>(element);
  }

  // --- Idle state assertions ---

  void expectIdleState() {
    expect(find.text('Daily Call'), findsOneWidget);
    expect(find.text('Ready to connect'), findsOneWidget);
    expect(find.text('Start Call'), findsOneWidget);
  }

  void expectStartCallButtonVisible() {
    expect(find.text('Start Call'), findsOneWidget);
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
  }

  void expectNoActiveControls() {
    expect(find.byIcon(Icons.call_end_rounded), findsNothing);
  }

  void expectNoSavedEntriesIndicator() {
    expect(find.textContaining('entries saved'), findsNothing);
    expect(find.textContaining('entry saved'), findsNothing);
  }

  void expectNoLatencyIndicator() {
    expect(find.textContaining('ms'), findsNothing);
  }

  void expectNoTimeWarning() {
    expect(find.textContaining('remaining'), findsNothing);
  }

  // --- Post-call summary assertions ---

  void expectPostCallSummary() {
    expect(find.text('Call Summary'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  }

  void expectDurationStat(String formatted) {
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text(formatted), findsOneWidget);
  }

  void expectEntriesStat(int count) {
    expect(find.text('Entries'), findsOneWidget);
    expect(find.text('$count'), findsOneWidget);
  }

  void expectLatencyStat(int ms) {
    expect(find.text('Latency'), findsOneWidget);
    expect(find.text('${ms}ms'), findsOneWidget);
  }

  void expectNoLatencyStat() {
    expect(find.text('Latency'), findsNothing);
  }

  void expectNoEntriesCapturedMessage() {
    expect(
      find.text('No entries were captured during this session.'),
      findsOneWidget,
    );
  }

  void expectCapturedEntriesHeader() {
    expect(find.text('Captured entries'), findsOneWidget);
  }

  void expectGenerateSummaryButton() {
    expect(find.text('Generate Summary'), findsOneWidget);
  }

  void expectNoGenerateSummaryButton() {
    expect(find.text('Generate Summary'), findsNothing);
  }

  void expectSessionSummaryText(String text) {
    expect(find.text('Session Summary'), findsOneWidget);
    expect(find.text(text), findsOneWidget);
  }

  // --- Actions ---

  /// Dispatches EndCall to the internal bloc and pumps until settled.
  Future<void> endCall() async {
    bloc.add(const EndCall());
    await tester.pumpAndSettle();
  }

  /// Dispatches a TranscriptReceived event.
  Future<void> addTranscript(Speaker speaker, String text) async {
    bloc.add(TranscriptReceived(Transcript(speaker: speaker, text: text)));
    await tester.pumpAndSettle();
  }

  Future<void> tapDone() async {
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }
}
