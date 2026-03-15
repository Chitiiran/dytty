/// Patrol integration test: Dashboard state management.
///
/// Tests that adding entries updates progress card and nudge card state
/// across screens (journal -> home).
///
/// Requires:
///   - patrol and patrol_finders in dev_dependencies
///   - Android emulator with Firebase emulators running
library;

// TODO(#45): Implement once patrol is added to dev_dependencies
//
// void main() {
//   patrolTest('progress updates after adding entry', ($) async {
//     await $.pumpWidgetAndSettle(const DyttyApp());
//
//     // Login
//     await $('Sign in anonymously (emulator)').tap();
//     await $.pumpAndSettle();
//
//     // Verify nudge card visible (no entries yet)
//     expect($(RegExp('haven.*journaled')), findsOneWidget);
//
//     // Navigate to journal and add entry
//     await $("Write Today's Journal").tap();
//     await $.pumpAndSettle();
//     await $(find.byTooltip('Add Positive Things entry')).tap();
//     // ...add entry flow...
//
//     // Go back to home
//     await $.native.pressBack();
//     await $.pumpAndSettle();
//
//     // Nudge card should be gone, progress should show 1/5
//     expect($(RegExp('haven.*journaled')), findsNothing);
//     expect($('1/5'), findsOneWidget);
//   });
// }
