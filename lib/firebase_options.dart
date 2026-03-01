// GENERATED FILE — DO NOT EDIT MANUALLY.
// Run `flutterfire configure` to regenerate this file with your Firebase project config.
//
// This is a placeholder. The app will not run until you configure Firebase:
//   1. Install FlutterFire CLI: dart pub global activate flutterfire_cli
//   2. Run: flutterfire configure
//   3. This file will be overwritten with your actual Firebase config.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDAD_KjyGm2yuY7I3qg8ODfodvRwVakwyQ',
    appId: '1:828440302945:web:e4627d230ff362a3392120',
    messagingSenderId: '828440302945',
    projectId: 'dytty-4b83d',
    authDomain: 'dytty-4b83d.firebaseapp.com',
    storageBucket: 'dytty-4b83d.firebasestorage.app',
  );

  // TODO: Replace with your actual Firebase config from `flutterfire configure`

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    iosBundleId: 'YOUR_BUNDLE_ID',
  );
}
