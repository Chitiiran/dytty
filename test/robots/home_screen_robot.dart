import 'package:flutter_test/flutter_test.dart';

/// Robot for interacting with and asserting on the HomeScreen widget.
class HomeScreenRobot {
  HomeScreenRobot(this.tester);
  final WidgetTester tester;

  void expectGreetingVisible(String name) {
    expect(find.textContaining(name), findsOneWidget);
  }

  void expectNudgeCardVisible() {
    expect(find.textContaining("haven't journaled"), findsOneWidget);
  }

  void expectNudgeCardGone() {
    expect(find.textContaining("haven't journaled"), findsNothing);
  }

  void expectProgressVisible(int filled, int total) {
    expect(find.textContaining('$filled/$total'), findsOneWidget);
  }

  void expectMicFabVisible() {
    expect(find.byTooltip('Record voice note'), findsOneWidget);
  }

  void expectSettingsButtonVisible() {
    expect(find.byTooltip('Settings'), findsOneWidget);
  }

  void expectTodayButtonVisible() {
    expect(find.text("Write Today's Journal"), findsOneWidget);
  }

  void expectDailyCallButtonVisible() {
    expect(find.text('Start Daily Call'), findsOneWidget);
  }

  Future<void> tapSettings() async {
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> tapTodayButton() async {
    await tester.tap(find.text("Write Today's Journal"));
    await tester.pumpAndSettle();
  }
}
