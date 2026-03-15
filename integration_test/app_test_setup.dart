/// Common setup for Patrol integration tests.
///
/// All integration test flows should import this file for shared configuration.
/// Tests run against a debug build with Firebase emulators enabled.
library;

// Patrol integration tests will use this setup once patrol is added
// to dev_dependencies and the CLI is configured.
//
// Usage in test files:
//   import 'package:dytty/app.dart';
//   import '../app_test_setup.dart';
//
//   void main() {
//     patrolTest('description', ($) async {
//       await $.pumpWidgetAndSettle(const DyttyApp());
//       // test steps...
//     });
//   }
//
// Prerequisites:
//   - Android emulator running
//   - Firebase emulators running (Auth :9099, Firestore :8080)
//   - Build with: --dart-define=USE_EMULATORS=true
