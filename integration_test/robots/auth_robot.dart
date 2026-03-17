import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Robot class for authentication integration tests.
///
/// Provides emulator login/logout helpers for Patrol integration tests.
class AuthRobot {
  AuthRobot(this.$);
  final PatrolIntegrationTester $;

  Future<void> loginWithEmulator() async {
    await $('Sign in anonymously (emulator)').tap();
    await $.pumpAndSettle();
  }

  Future<void> expectLoginScreen() async {
    expect($('Your daily reflection journal'), findsOneWidget);
  }

  Future<void> signOut() async {
    await $(find.byTooltip('Settings')).tap();
    await $.pumpAndSettle();
    await $('Sign Out').tap();
    await $.pumpAndSettle();
  }
}
