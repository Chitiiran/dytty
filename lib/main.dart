import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dytty/app.dart';
import 'package:dytty/services/app_check/app_check_initializer.dart';
import 'package:dytty/services/notification/notification_service.dart';
import 'firebase_options.dart';

/// Set via --dart-define=USE_EMULATORS=true for E2E testing builds.
/// In debug mode, emulators are opt-in (not automatic) so Android dev
/// can use real Firebase with Google Sign-In.
const useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Set via `--dart-define=GEMINI_API_KEY=...` to enable LLM categorization
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

late final NotificationService notificationService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // google-services.json auto-initializes on Android; safe to ignore duplicate.
    if (e.code != 'duplicate-app') rethrow;
  }

  // Arm App Check before any Firebase AI Logic call (#274). Google deactivated
  // AI Logic on this project while the app sent placeholder tokens, which
  // killed the daily call with WebSocket 1008 the moment the session went
  // active. Failure is non-fatal — journaling works without the call.
  await initializeAppCheck(
    isDebug: kDebugMode,
    activate: (config) => FirebaseAppCheck.instance.activate(
      providerAndroid: config.android,
      providerApple: config.apple,
    ),
  );

  if (useEmulators) {
    // Android emulator uses 10.0.2.2 to reach host machine's localhost
    final emulatorHost = kIsWeb
        ? 'localhost'
        : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
  }

  // Enable Firestore offline persistence for cache-first reads.
  // Skip when using emulators (emulators don't support persistence).
  if (!useEmulators) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600, // 100 MB
    );
  }

  // Portrait lock only on mobile — Platform check is unsafe on web
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  notificationService = NotificationService();
  await notificationService.init();

  // Enable semantics for accessibility tree (needed for Playwright testing)
  SemanticsBinding.instance.ensureSemantics();

  runApp(const DyttyApp());
}
