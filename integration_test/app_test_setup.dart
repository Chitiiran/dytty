/// Common setup for Patrol integration tests.
///
/// All integration test flows should import this file for shared configuration.
/// Tests run against a debug build with Firebase emulators enabled
/// (--dart-define=USE_EMULATORS=true).
library;

export 'package:patrol/patrol.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:dytty/app.dart';

export 'robots/auth_robot.dart';
export 'robots/home_screen_robot.dart';
export 'robots/journal_screen_robot.dart';
