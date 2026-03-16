import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Robot for interacting with and asserting on the SettingsScreen widget.
class SettingsScreenRobot {
  SettingsScreenRobot(this.tester);
  final WidgetTester tester;

  /// Scrolls the ListView until [finder] is visible.
  Future<void> scrollTo(Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  void expectTitleVisible() {
    expect(find.text('Settings'), findsOneWidget);
  }

  void expectProfileVisible(String name, String email) {
    expect(find.text(name), findsOneWidget);
    expect(find.text(email), findsOneWidget);
  }

  void expectInitialsVisible(String initial) {
    expect(find.text(initial), findsOneWidget);
  }

  void expectSectionVisible(String label) {
    expect(find.text(label), findsOneWidget);
  }

  void expectThemeOptions() {
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  }

  void expectThemeSelected(String label) {
    final tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );
    expect(tile, findsOneWidget);
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  }

  void expectThemeNotSelected(String label) {
    final tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );
    expect(tile, findsOneWidget);
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
  }

  void expectHideEntriesToggle() {
    expect(find.text('Hide entries'), findsOneWidget);
    expect(find.text('Show entries in weekly review only'), findsOneWidget);
  }

  void expectDailyReminderToggle() {
    expect(find.text('Daily reminder'), findsOneWidget);
  }

  void expectDailyCallToggle() {
    expect(find.text('Daily call reminder'), findsOneWidget);
  }

  void expectReminderTimeVisible() {
    expect(find.text('Reminder time'), findsOneWidget);
  }

  void expectReminderTimeNotVisible() {
    expect(find.text('Reminder time'), findsNothing);
  }

  void expectCallTimeVisible() {
    expect(find.text('Call time'), findsOneWidget);
  }

  void expectCallTimeNotVisible() {
    expect(find.text('Call time'), findsNothing);
  }

  void expectSignOutButton() {
    expect(find.text('Sign Out'), findsOneWidget);
  }

  void expectVersionVisible(String version) {
    expect(find.text(version), findsOneWidget);
  }

  void expectLicensesTile() {
    expect(find.text('Licenses'), findsOneWidget);
  }

  void expectNoProfileSection() {
    expect(find.text('Test User'), findsNothing);
  }

  Future<void> tapSignOut() async {
    await tester.tap(find.text('Sign Out'));
    await tester.pump();
  }

  Future<void> tapThemeOption(String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }
}
