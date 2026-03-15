import 'package:flutter_test/flutter_test.dart';

/// Robot for interacting with and asserting on the DailyJournalScreen widget.
class JournalScreenRobot {
  JournalScreenRobot(this.tester);
  final WidgetTester tester;

  void expectDateHeader(String dateText) {
    expect(find.text(dateText), findsOneWidget);
  }

  void expectCategoryCardVisible(String categoryName) {
    expect(find.text(categoryName), findsOneWidget);
  }

  void expectEntryVisible(String text) {
    expect(find.text(text), findsOneWidget);
  }

  void expectEmptyBanner() {
    expect(find.text('Time to reflect'), findsOneWidget);
  }

  void expectEmptyBannerGone() {
    expect(find.text('Time to reflect'), findsNothing);
  }

  Future<void> tapPreviousDay() async {
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
  }

  Future<void> tapNextDay() async {
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
  }

  Future<void> tapAddEntry(String categoryName) async {
    await tester.tap(find.byTooltip('Add $categoryName entry'));
    await tester.pumpAndSettle();
  }
}
