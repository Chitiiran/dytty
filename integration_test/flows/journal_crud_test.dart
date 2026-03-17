import '../app_test_setup.dart';

void main() {
  patrolTest('add and verify journal entry', ($) async {
    await $.pumpWidgetAndSettle(const DyttyApp());

    final auth = AuthRobot($);
    final home = HomeScreenRobot($);
    final journal = JournalScreenRobot($);

    // Login
    await auth.loginWithEmulator();

    // Navigate to journal
    await home.tapWriteJournal();

    // Verify empty state
    await journal.expectEmptyBanner();

    // Add entry to Positive Things
    await journal.addEntry('Positive Things', 'Had a great day');

    // Verify entry visible
    await journal.expectEntryVisible('Had a great day');
  });
}
