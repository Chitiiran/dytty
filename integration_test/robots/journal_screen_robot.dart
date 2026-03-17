import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Robot class for DailyJournalScreen integration tests.
///
/// Provides entry CRUD and navigation helpers for Patrol integration tests.
class JournalScreenRobot {
  JournalScreenRobot(this.$);
  final PatrolIntegrationTester $;

  Future<void> addEntry(String categoryName, String text) async {
    await $(find.byTooltip('Add $categoryName entry')).tap();
    await $.pumpAndSettle();
    // Enter text and save
    await $.platform.mobile.enterTextByIndex(text, index: 0);
    await $('Save').tap();
    await $.pumpAndSettle();
  }

  Future<void> expectEntryVisible(String text) async {
    expect($(text), findsOneWidget);
  }

  Future<void> tapPreviousDay() async {
    await $(find.byTooltip('Previous day')).tap();
    await $.pumpAndSettle();
  }

  Future<void> tapNextDay() async {
    await $(find.byTooltip('Next day')).tap();
    await $.pumpAndSettle();
  }

  Future<void> expectEmptyBanner() async {
    expect($('Time to reflect'), findsOneWidget);
  }
}
