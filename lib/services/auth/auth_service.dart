import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
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
    // On web, google_sign_in's authenticate() is not supported (Credential
    // Manager is Android/iOS only). Use Firebase Auth's signInWithPopup which
    // handles the full OAuth flow via browser popup.
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    // On Android/iOS, use google_sign_in package with Credential Manager.
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
