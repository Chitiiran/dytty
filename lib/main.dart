import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dytty/app.dart';
import 'firebase_options.dart';

/// Set via --dart-define=USE_EMULATORS=true for E2E testing builds
const useEmulators = bool.fromEnvironment('USE_EMULATORS') || kDebugMode;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

  // Enable semantics for accessibility tree (needed for Playwright testing)
  SemanticsBinding.instance.ensureSemantics();

  runApp(const DyttyApp());
}
