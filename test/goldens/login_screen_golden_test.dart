import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/auth/login_screen.dart';
import 'golden_test_helper.dart';

// Golden tests for LoginScreen.
//
// Inter font is bundled in assets/fonts/ and runtime fetching is disabled
// in test/flutter_test_config.dart, so GoogleFonts.inter() uses local files.
// Run: flutter test --update-goldens test/goldens/ to regenerate baselines.

void main() {
  group('LoginScreen golden tests', () {
    testWidgets('default state', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const LoginScreen(),
          authState: const Unauthenticated(),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/login_screen_default.png'),
      );
    });

    testWidgets('loading state', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const LoginScreen(),
          authState: const AuthLoading(),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/login_screen_loading.png'),
      );
    });

    testWidgets('error state', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const LoginScreen(),
          authState: const AuthError('Sign-in failed. Please try again.'),
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/login_screen_error.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const LoginScreen(),
          authState: const Unauthenticated(),
          themeMode: ThemeMode.dark,
          size: const Size(400, 800),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('fixtures/login_screen_dark.png'),
      );
    });
  });
}
