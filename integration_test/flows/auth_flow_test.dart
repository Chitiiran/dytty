import '../app_test_setup.dart';

void main() {
  patrolTest('emulator login -> home screen -> sign out', ($) async {
    await $.pumpWidgetAndSettle(const DyttyApp());

    final auth = AuthRobot($);

    // Verify login screen
    await auth.expectLoginScreen();

    // Tap emulator sign-in
    await auth.loginWithEmulator();

    // Verify home screen
    expect($('Dytty'), findsOneWidget);

    // Sign out via settings
    await auth.signOut();

    // Back on login screen
    await auth.expectLoginScreen();
  });
}
