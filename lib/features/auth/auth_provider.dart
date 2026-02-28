import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dytty/main.dart' show useEmulators;
import 'package:dytty/services/auth/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _loading = true;
  String? _error;
  StreamSubscription<User?>? _authSub;

  AuthProvider({required AuthService authService})
      : _authService = authService {
    _authSub = _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  void _onAuthStateChanged(User? user) {
    _user = user;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() async {
    if (!useEmulators) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInAnonymously();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
