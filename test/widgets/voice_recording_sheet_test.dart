import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dytty/data/models/category_config.dart';
import 'package:dytty/features/settings/cubit/category_cubit.dart';
import 'package:dytty/features/voice_note/widgets/voice_recording_sheet.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/speech/speech_service.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../helpers/pump_app.dart';

class MockSpeechToText extends Mock implements SpeechToText {}

class MockLlmService extends Mock implements LlmService {}

/// Creates a [SpeechRecognitionResult] with the given words and finality.
SpeechRecognitionResult _makeSpeechResult(String words, bool isFinal) {
  return SpeechRecognitionResult([
    SpeechRecognitionWords(words, null, 0.95),
  ], isFinal);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

  late MockSpeechToText mockStt;
  late MockLlmService mockLlm;
  late MockCategoryCubit mockCategoryCubit; // from pump_app.dart

  setUp(() {
    mockStt = MockSpeechToText();
    mockLlm = MockLlmService();
    mockCategoryCubit = MockCategoryCubit();

    // Default: speech unavailable (safest — no infinite listening loop)
    when(() => mockStt.initialize()).thenAnswer((_) async => false);
    when(() => mockStt.isListening).thenReturn(false);
    when(() => mockStt.cancel()).thenAnswer((_) async {});
    when(() => mockStt.stop()).thenAnswer((_) async {});
    when(() => mockLlm.dispose()).thenReturn(null);
    when(() => mockCategoryCubit.state).thenReturn(
      CategoryState(categories: CategoryConfig.defaults, loaded: true),
    );
  });

  /// Builds a widget tree with all required providers, then taps a button
  /// to open the voice recording sheet via the real [showVoiceRecordingSheet].
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<SpeechService>(
              create: (_) => SpeechService(speech: mockStt),
            ),
            RepositoryProvider<LlmService>(create: (_) => mockLlm),
          ],
          child: BlocProvider<CategoryCubit>.value(
            value: mockCategoryCubit,
            child: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showVoiceRecordingSheet(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    // Use pump with duration because CircularProgressIndicator is infinite
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// Configures STT mocks so that [listen] immediately fires a final result
  /// with [transcript], skipping past the listening state to transcriptReview.
  void setupSttWithImmediateFinalResult(String transcript) {
    when(() => mockStt.initialize()).thenAnswer((_) async => true);
    when(
      () => mockStt.listen(
        onResult: any(named: 'onResult'),
        pauseFor: any(named: 'pauseFor'),
        listenFor: any(named: 'listenFor'),
      ),
    ).thenAnswer((invocation) async {
      final onResult =
          invocation.namedArguments[#onResult]
              as void Function(SpeechRecognitionResult);
      // Fire a final result immediately so the bloc transitions
      // listening -> transcriptReview, avoiding the flutter_animate timer.
      onResult(_makeSpeechResult(transcript, true));
    });
  }

  /// Opens the sheet with STT configured to immediately produce a final
  /// transcript, then waits for the transcriptReview state to appear.
  Future<void> openSheetToTranscriptReview(
    WidgetTester tester,
    String transcript,
  ) async {
    setupSttWithImmediateFinalResult(transcript);
    await openSheet(tester);
    // Let the bloc process the speech result and rebuild
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('VoiceRecordingSheet', () {
    testWidgets('shows "Speech unavailable" when STT init fails', (
      tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Speech unavailable'), findsOneWidget);
      expect(
        find.text('Speech recognition is not supported on this device.'),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows mic-off icon when unavailable', (tester) async {
      await openSheet(tester);

      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
    });

    testWidgets(
      'shows listening state when STT is available',
      (tester) async {
        when(() => mockStt.initialize()).thenAnswer((_) async => true);
        when(
          () => mockStt.listen(
            onResult: any(named: 'onResult'),
            pauseFor: any(named: 'pauseFor'),
            listenFor: any(named: 'listenFor'),
          ),
        ).thenAnswer((_) async {});

        await openSheet(tester);

        // Should transition through ready -> listening (auto-start)
        expect(find.text('Listening...'), findsOneWidget);
        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.text('Start speaking...'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      },
      // flutter_animate's repeating mic pulse creates pending timers
      skip: true,
    );

    testWidgets('shows error state with error message', (tester) async {
      // Make init throw an error
      when(() => mockStt.initialize()).thenThrow(Exception('STT failed'));

      await openSheet(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('shows drag handle', (tester) async {
      await openSheet(tester);

      // The drag handle is a 40x4 container
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints?.maxWidth == 40 &&
              w.constraints?.maxHeight == 4,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Close button dismisses the sheet', (tester) async {
      await openSheet(tester);

      expect(find.text('Speech unavailable'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Speech unavailable'), findsNothing);
    });

    testWidgets('error state shows custom error message', (tester) async {
      when(
        () => mockStt.initialize(),
      ).thenThrow(Exception('Microphone permission denied'));

      await openSheet(tester);

      expect(find.text('Something went wrong'), findsOneWidget);
      // Error message includes the exception text
      expect(
        find.textContaining('Microphone permission denied'),
        findsOneWidget,
      );
    });

    testWidgets('Try Again in error state re-initializes speech', (
      tester,
    ) async {
      when(() => mockStt.initialize()).thenThrow(Exception('STT failed'));

      await openSheet(tester);

      // Verify error state
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Second init succeeds and STT immediately fires a final result
      // to move past the listening state (avoiding flutter_animate timers).
      when(() => mockStt.initialize()).thenAnswer((_) async => true);
      when(
        () => mockStt.listen(
          onResult: any(named: 'onResult'),
          pauseFor: any(named: 'pauseFor'),
          listenFor: any(named: 'listenFor'),
        ),
      ).thenAnswer((invocation) async {
        final onResult =
            invocation.namedArguments[#onResult]
                as void Function(SpeechRecognitionResult);
        onResult(_makeSpeechResult('recovered text', true));
      });

      // Tap Try Again
      await tester.tap(find.text('Try Again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      // Error state should be gone -- now in transcriptReview
      expect(find.text('Something went wrong'), findsNothing);
      expect(find.text('Review transcript'), findsOneWidget);
    });
  });

  group('TranscriptReview state', () {
    testWidgets('shows title, transcript field, and action buttons', (
      tester,
    ) async {
      await openSheetToTranscriptReview(tester, 'I had a great day today');

      expect(find.text('Review transcript'), findsOneWidget);
      // TextField should be pre-filled with the transcript
      expect(
        find.widgetWithText(TextField, 'I had a great day today'),
        findsOneWidget,
      );
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Summarize'), findsOneWidget);
    });

    testWidgets('Discard button dismisses the sheet', (tester) async {
      await openSheetToTranscriptReview(tester, 'Some transcript text');

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Sheet should be gone
      expect(find.text('Review transcript'), findsNothing);
    });

    testWidgets('Summarize button transitions to processing state', (
      tester,
    ) async {
      await openSheetToTranscriptReview(tester, 'I felt grateful today');

      // Use a Completer so the future never completes (no pending timer)
      final completer = Completer<CategorizationResult>();
      when(
        () => mockLlm.categorizeEntry(
          any(),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.tap(find.text('Summarize'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Should now show processing state
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.text('I felt grateful today'), findsOneWidget);
      expect(find.text('Categorizing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(
        const CategorizationResult(
          suggestedCategory: 'gratitude',
          summary: 'Felt grateful',
          confidence: 0.9,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('transcript edit field has hint text', (tester) async {
      await openSheetToTranscriptReview(tester, 'Hello world');

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.decoration?.hintText,
        'Edit transcript before summarizing...',
      );
    });

    testWidgets('Summarize icon is auto_awesome_rounded', (tester) async {
      await openSheetToTranscriptReview(tester, 'Test transcript');

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });

  group('Reviewing state', () {
    /// Opens sheet, gets to transcriptReview, then taps Summarize and
    /// lets the LLM mock return a result to reach the reviewing state.
    Future<void> openSheetToReviewing(
      WidgetTester tester, {
      String transcript = 'I had a great day today',
      String summary = 'Had a great day',
      String category = 'positive',
      List<String> tags = const ['happy'],
    }) async {
      await openSheetToTranscriptReview(tester, transcript);

      when(
        () => mockLlm.categorizeEntry(
          any(),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer(
        (_) async => CategorizationResult(
          suggestedCategory: category,
          summary: summary,
          confidence: 0.9,
          suggestedTags: tags,
        ),
      );

      await tester.tap(find.text('Summarize'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows title, summary field, category chips, and buttons', (
      tester,
    ) async {
      await openSheetToReviewing(tester);

      expect(find.text('Review your note'), findsOneWidget);
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('summary field is pre-filled with LLM result', (tester) async {
      await openSheetToReviewing(tester, summary: 'AI-generated summary');

      expect(
        find.widgetWithText(TextField, 'AI-generated summary'),
        findsOneWidget,
      );
    });

    testWidgets('shows all category chips from active categories', (
      tester,
    ) async {
      await openSheetToReviewing(tester);

      // CategoryConfig.defaults has 5 categories
      for (final cat in CategoryConfig.defaults) {
        expect(find.text(cat.displayName), findsOneWidget);
      }
    });

    testWidgets('suggested category chip is selected', (tester) async {
      await openSheetToReviewing(tester, category: 'positive');

      // Find the ChoiceChip for "Positive Things" and verify it's selected
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Positive Things'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('tapping a different category chip selects it', (tester) async {
      await openSheetToReviewing(tester, category: 'positive');

      // Tap the "Gratitude" chip
      await tester.tap(find.text('Gratitude'));
      await tester.pump();

      // Gratitude should now be selected
      final gratitudeChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Gratitude'),
      );
      expect(gratitudeChip.selected, isTrue);
    });

    testWidgets('Discard button dismisses the sheet', (tester) async {
      await openSheetToReviewing(tester);

      // Scroll the Discard button into view (it's at the bottom of the sheet)
      await tester.ensureVisible(find.text('Discard'));
      await tester.pump();
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Review your note'), findsNothing);
    });

    testWidgets('Save button is enabled when category is selected', (
      tester,
    ) async {
      await openSheetToReviewing(tester, category: 'positive');

      await tester.ensureVisible(find.text('Save'));
      await tester.pump();

      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('transcript expandable is collapsed by default', (
      tester,
    ) async {
      await openSheetToReviewing(tester);

      // "Transcript" label should be visible
      expect(find.text('Transcript'), findsOneWidget);
      // Expand icon should show
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
      // The transcript edit field inside the expandable should NOT be visible
      // (only the summary TextField should be present, plus the expandable one
      //  which is hidden)
      expect(find.text('Edit transcript...'), findsNothing);
    });

    testWidgets('tapping transcript header expands it', (tester) async {
      await openSheetToReviewing(tester);

      // Tap the transcript header to expand
      await tester.tap(find.text('Transcript'));
      await tester.pump();

      // Should now show expand_less icon
      expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);
      // The transcript edit field should appear with hint text
      expect(
        find.widgetWithText(TextField, 'I had a great day today'),
        findsOneWidget,
      );
    });

    testWidgets('Save button dismisses sheet with result', (tester) async {
      await openSheetToReviewing(
        tester,
        transcript: 'My transcript',
        summary: 'My summary',
        category: 'gratitude',
      );

      // Scroll the Save button into view (it's at the bottom of the sheet)
      await tester.ensureVisible(find.text('Save'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sheet should be dismissed
      expect(find.text('Review your note'), findsNothing);
    });
  });

  group('Processing state', () {
    testWidgets('shows transcript text and categorizing indicator', (
      tester,
    ) async {
      await openSheetToTranscriptReview(
        tester,
        'Today I noticed a beautiful sunset',
      );

      // Use a Completer so the future never completes (no pending timer)
      final completer = Completer<CategorizationResult>();
      when(
        () => mockLlm.categorizeEntry(
          any(),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenAnswer((_) => completer.future);

      await tester.tap(find.text('Summarize'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Processing...'), findsOneWidget);
      expect(find.text('Today I noticed a beautiful sunset'), findsOneWidget);
      expect(find.text('Categorizing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(
        const CategorizationResult(
          suggestedCategory: 'beauty',
          summary: 'Beautiful sunset',
          confidence: 0.9,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('LLM error during categorization', () {
    testWidgets('shows error state when LLM throws', (tester) async {
      await openSheetToTranscriptReview(tester, 'Some text');

      when(
        () => mockLlm.categorizeEntry(
          any(),
          categoryIds: any(named: 'categoryIds'),
        ),
      ).thenThrow(Exception('LLM API error'));

      await tester.tap(find.text('Summarize'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.textContaining('Failed to categorize'), findsOneWidget);
    });
  });
}
