// Firebase configuration for Dytty.
// API keys are injected via --dart-define at build time (see .env.example).
// Non-sensitive config (appId, projectId, etc.) stays in code.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _webApiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static final FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: '1:828440302945:web:e4627d230ff362a3392120',
    messagingSenderId: '828440302945',
    projectId: 'dytty-4b83d',
    authDomain: 'dytty-4b83d.firebaseapp.com',
    storageBucket: 'dytty-4b83d.firebasestorage.app',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: '1:828440302945:android:8a03bc6c01380939392120',
    messagingSenderId: '828440302945',
    projectId: 'dytty-4b83d',
    storageBucket: 'dytty-4b83d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    iosBundleId: 'YOUR_BUNDLE_ID',
  );
}
