/// Patrol integration test: Journal CRUD flow.
///
/// Tests add entry -> verify visible -> edit -> verify updated -> delete.
///
/// Requires:
///   - patrol and patrol_finders in dev_dependencies
///   - Android emulator with Firebase emulators running
library;

// TODO(#45): Implement once patrol is added to dev_dependencies
//
// void main() {
//   patrolTest('add, edit, and delete journal entry', ($) async {
//     await $.pumpWidgetAndSettle(const DyttyApp());
//
//     // Login
//     await $('Sign in anonymously (emulator)').tap();
//     await $.pumpAndSettle();
//
//     // Navigate to journal
//     await $("Write Today's Journal").tap();
//     await $.pumpAndSettle();
//
//     // Add entry to Positive Things
//     await $(find.byTooltip('Add Positive Things entry')).tap();
//     await $.pumpAndSettle();
//     await $.native.enterText('Had a great day');
//     await $('Save').tap();
//     await $.pumpAndSettle();
//
//     // Verify entry visible
//     expect($('Had a great day'), findsOneWidget);
//   });
// }
