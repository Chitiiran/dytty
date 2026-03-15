/// Robot class for HomeScreen integration tests.
///
/// Encapsulates interaction patterns so test flows read like user stories.
/// Shared between Patrol integration tests and widget tests.
library;

// TODO(#45): Implement with Patrol finders once patrol is in dev_dependencies
//
// class HomeScreenRobot {
//   HomeScreenRobot(this.$);
//   final PatrolIntegrationTester $;
//
//   Future<void> expectNudgeCardVisible() async {
//     expect($(RegExp('haven.*journaled')), findsOneWidget);
//   }
//
//   Future<void> expectNudgeCardGone() async {
//     expect($(RegExp('haven.*journaled')), findsNothing);
//   }
//
//   Future<void> expectProgress(int filled, int total) async {
//     expect($('$filled/$total'), findsOneWidget);
//   }
//
//   Future<void> tapWriteJournal() async {
//     await $("Write Today's Journal").tap();
//     await $.pumpAndSettle();
//   }
//
//   Future<void> tapSettings() async {
//     await $(find.byTooltip('Settings')).tap();
//     await $.pumpAndSettle();
//   }
//
//   Future<void> tapMicFab() async {
//     await $(find.byTooltip('Record voice note')).tap();
//     await $.pumpAndSettle();
//   }
// }
