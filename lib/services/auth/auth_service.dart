import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dytty/main.dart' show useEmulators;

class AuthService {
  final FirebaseAuth _auth;
  GoogleSignIn? _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn;

  bool _initialized = false;

  GoogleSignIn get _google => _googleSignIn ??= GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    if (!_google.supportsAuthenticate()) {
      throw Exception('Google Sign-In is not supported on this platform');
    }

    // google_sign_in 7.x requires initialize() before authenticate().
    // On Android, it auto-resolves serverClientId from google-services.json.
    if (!_initialized) {
      await _google.initialize();
      _initialized = true;
    }
    final googleUser = await _google.authenticate();

    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInAnonymously() async {
    assert(
      kDebugMode || useEmulators,
      'signInAnonymously is for debug/emulator use only',
    );
    return _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // Only sign out of Google if it was previously initialized
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
  }
}
