import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/category_detail/widgets/call_controls_overlay.dart';

void main() {
  group('CallControlsOverlay', () {
    testWidgets('renders mute toggle and end call button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControlsOverlay(
              isMuted: false,
              onToggleMute: () {},
              onEndCall: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    });

    testWidgets('shows mic_off icon when muted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControlsOverlay(
              isMuted: true,
              onToggleMute: () {},
              onEndCall: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_off), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('calls onToggleMute when mute button tapped', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControlsOverlay(
              isMuted: false,
              onToggleMute: () => toggled = true,
              onEndCall: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.mic));
      expect(toggled, true);
    });

    testWidgets('calls onEndCall when end button tapped', (tester) async {
      bool ended = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControlsOverlay(
              isMuted: false,
              onToggleMute: () {},
              onEndCall: () => ended = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.call_end_rounded));
      expect(ended, true);
    });

    testWidgets('shows elapsed time when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallControlsOverlay(
              isMuted: false,
              onToggleMute: () {},
              onEndCall: () {},
              elapsed: const Duration(minutes: 2, seconds: 30),
            ),
          ),
        ),
      );

      expect(find.text('02:30'), findsOneWidget);
    });
  });
}
