import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Robot for interacting with and asserting on the LoginScreen widget.
class LoginScreenRobot {
  LoginScreenRobot(this.tester);
  final WidgetTester tester;

  void expectTitleVisible() {
    expect(find.text('Dytty'), findsOneWidget);
  }

  void expectSubtitleVisible() {
    expect(find.text('Your daily reflection journal'), findsOneWidget);
  }

  void expectGoogleSignInVisible() {
    expect(find.text('Continue with Google'), findsOneWidget);
  }

  void expectEmulatorSignInVisible() {
    expect(find.text('Sign in anonymously (emulator)'), findsOneWidget);
  }

  void expectLoadingSpinner() {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }

  void expectErrorMessage(String message) {
    expect(find.text(message), findsOneWidget);
  }

  Future<void> tapGoogleSignIn() async {
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }
}
