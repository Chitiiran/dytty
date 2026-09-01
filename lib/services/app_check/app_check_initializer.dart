import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Signature for arming App Check. Injectable so provider selection is
/// testable without a live Firebase app.
typedef AppCheckActivator = Future<void> Function(AppCheckConfig config);

/// The App Check attestation providers a build installs.
///
/// Google deactivated Firebase AI Logic on this project because the app
/// installed no App Check provider and therefore sent placeholder tokens — the
/// daily call died with WebSocket 1008 the moment the session went active
/// (#274). Every build must now attest for real.
@immutable
class AppCheckConfig {
  /// Provider used on Android.
  final AndroidAppCheckProvider android;

  /// Provider used on iOS/macOS.
  final AppleAppCheckProvider apple;

  const AppCheckConfig({required this.android, required this.apple});

  /// Debug builds attest with the debug provider — each device's token is
  /// registered in the Firebase console. Release builds use real platform
  /// attestation, which is what enforcement exists to check; shipping the
  /// debug provider to release would make enforcement accept anything.
  factory AppCheckConfig.forBuild({required bool isDebug}) => isDebug
      ? const AppCheckConfig(
          android: AndroidDebugProvider(),
          apple: AppleDebugProvider(),
        )
      : const AppCheckConfig(
          android: AndroidPlayIntegrityProvider(),
          apple: AppleAppAttestProvider(),
        );
}

/// Arm App Check for this build. Returns whether attestation was activated.
///
/// A failure is logged and swallowed: journaling works without the daily call,
/// so a device that cannot attest must still get a usable app rather than a
/// crash on launch.
Future<bool> initializeAppCheck({
  required bool isDebug,
  required AppCheckActivator activate,
}) async {
  try {
    await activate(AppCheckConfig.forBuild(isDebug: isDebug));
    return true;
  } catch (e) {
    debugPrint('App Check activation failed: $e');
    return false;
  }
}
