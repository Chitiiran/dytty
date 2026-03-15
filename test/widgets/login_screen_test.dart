import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/auth/login_screen.dart';

import '../helpers/pump_app.dart';
import '../robots/login_screen_robot.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;

  late LoginScreenRobot robot;

  group('LoginScreen', () {
    testWidgets('displays title and subtitle', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        authState: const Unauthenticated(),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = LoginScreenRobot(tester);
      robot.expectTitleVisible();
      robot.expectSubtitleVisible();
    });

    testWidgets('Google sign-in button is visible', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        authState: const Unauthenticated(),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = LoginScreenRobot(tester);
      robot.expectGoogleSignInVisible();
    });

    testWidgets('loading state shows spinner', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        authState: const AuthLoading(),
      );
      // Pump enough for animations but not pumpAndSettle (spinner animates)
      await tester.pump(const Duration(seconds: 1));

      robot = LoginScreenRobot(tester);
      robot.expectLoadingSpinner();
    });

    testWidgets('error state shows error message', (tester) async {
      await tester.pumpApp(
        const LoginScreen(),
        authState: const AuthError('Sign-in failed'),
      );
      await tester.pump(const Duration(seconds: 1));

      robot = LoginScreenRobot(tester);
      robot.expectErrorMessage('Sign-in failed');
    });
  });
}
