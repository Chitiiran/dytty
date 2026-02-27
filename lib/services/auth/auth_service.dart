import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth;
  GoogleSignIn? _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn;

  // Lazy — avoids eager clientId assertion crash on web when no meta tag is set
  GoogleSignIn get _google => _googleSignIn ??= GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInAnonymously() async {
    assert(kDebugMode, 'signInAnonymously is for debug/emulator use only');
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
