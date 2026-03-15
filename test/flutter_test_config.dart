import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration. Automatically loaded by the Flutter test
/// framework before any test in the `test/` directory.
///
/// Disables Google Fonts runtime fetching so that tests use the bundled
/// Inter font files from assets/fonts/ instead of making HTTP requests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  return testMain();
}
