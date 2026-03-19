import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test configuration. Automatically loaded by the Flutter test
/// framework before any test in the `test/` directory.
///
/// - Disables Google Fonts runtime fetching (use bundled Inter from assets/fonts/)
/// - Disables flutter_animate durations globally so all animations (including
///   looping/repeating ones) complete instantly. This prevents pumpAndSettle()
///   from hanging on widgets with pulse, shimmer, or orbit animations.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  Animate.restartOnHotReload = false;
  Animate.defaultDuration = Duration.zero;
  return testMain();
}
