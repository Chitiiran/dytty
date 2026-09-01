import 'package:dytty/services/app_check/app_check_initializer.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCheckConfig.forBuild', () {
    test(
      'release builds attest with Play Integrity, never the debug provider',
      () {
        final config = AppCheckConfig.forBuild(isDebug: false);

        expect(config.android, isA<AndroidPlayIntegrityProvider>());
        expect(config.android.type, 'playIntegrity');
        expect(config.apple, isA<AppleAppAttestProvider>());
      },
    );

    test('debug builds use the debug provider so registered tokens work', () {
      final config = AppCheckConfig.forBuild(isDebug: true);

      expect(config.android, isA<AndroidDebugProvider>());
      expect(config.android.type, 'debug');
      expect(config.apple, isA<AppleDebugProvider>());
    });
  });

  group('initializeAppCheck', () {
    test('activates with the config resolved for the build mode', () async {
      final activated = <AppCheckConfig>[];

      final ok = await initializeAppCheck(
        isDebug: false,
        activate: (config) async => activated.add(config),
      );

      expect(ok, isTrue);
      expect(activated, hasLength(1));
      expect(activated.single.android.type, 'playIntegrity');
    });

    test('reports failure without throwing when activation fails', () async {
      // #274: App Check is required for Firebase AI Logic, but a failure to
      // attest must not stop the app from starting — journaling still works
      // without the daily call.
      final ok = await initializeAppCheck(
        isDebug: true,
        activate: (_) async => throw Exception('attestation unavailable'),
      );

      expect(ok, isFalse);
    });
  });
}
