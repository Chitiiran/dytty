/// Robot class for authentication integration tests.
///
/// Provides emulator login/logout helpers for Patrol integration tests.
library;

// TODO(#45): Implement with Patrol finders once patrol is in dev_dependencies
//
// class AuthRobot {
//   AuthRobot(this.$);
//   final PatrolIntegrationTester $;
//
//   Future<void> loginWithEmulator() async {
//     await $('Sign in anonymously (emulator)').tap();
//     await $.pumpAndSettle();
//   }
//
//   Future<void> expectLoginScreen() async {
//     expect($('Your daily reflection journal'), findsOneWidget);
//   }
//
//   Future<void> signOut() async {
//     await $(find.byTooltip('Settings')).tap();
//     await $.pumpAndSettle();
//     await $('Sign Out').tap();
//     await $.pumpAndSettle();
//   }
// }
