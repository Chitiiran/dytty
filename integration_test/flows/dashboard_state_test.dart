import '../app_test_setup.dart';

void main() {
  patrolTest('progress updates after adding entry', ($) async {
    await $.pumpWidgetAndSettle(const DyttyApp());

    final auth = AuthRobot($);
    final home = HomeScreenRobot($);
    final journal = JournalScreenRobot($);

    // Login
    await auth.loginWithEmulator();

    // Verify nudge card visible (no entries yet)
    await home.expectNudgeCardVisible();

    // Navigate to journal and add entry
    await home.tapWriteJournal();
    await journal.addEntry('Positive Things', 'Had a great day');

    // Go back to home via app bar back button
    await $(find.byTooltip('Back')).tap();
    await $.pumpAndSettle();

    // Nudge card should be gone, progress should show 1/5
    await home.expectNudgeCardGone();
    await home.expectProgress(1, 5);
  });
}
