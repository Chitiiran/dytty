import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dytty/services/auth/auth_service.dart';
import 'package:dytty/main.dart' show useEmulators;

// --- Events ---

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class SignInWithGoogle extends AuthEvent {
  const SignInWithGoogle();
}

class SignInAnonymously extends AuthEvent {
  const SignInAnonymously();
}

class SignOut extends AuthEvent {
  const SignOut();
}

class _AuthUserChanged extends AuthEvent {
  final String? uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const _AuthUserChanged({
    this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [uid, displayName, email, photoUrl];
}

// --- States ---

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const Authenticated({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [uid, displayName, email, photoUrl];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- Bloc ---

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<dynamic>? _authSub;

  AuthBloc({required AuthService authService})
    : _authService = authService,
      super(const AuthInitial()) {
    on<_AuthUserChanged>(_onAuthUserChanged);
    on<SignInWithGoogle>(_onSignInWithGoogle);
    on<SignInAnonymously>(_onSignInAnonymously);
    on<SignOut>(_onSignOut);

    _authSub = _authService.authStateChanges.listen((user) {
      add(
        _AuthUserChanged(
          uid: user?.uid,
          displayName: user?.displayName,
          email: user?.email,
          photoUrl: user?.photoURL,
        ),
      );
    });
  }

  void _onAuthUserChanged(_AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.uid != null) {
      emit(
        Authenticated(
          uid: event.uid!,
          displayName: event.displayName,
          email: event.email,
          photoUrl: event.photoUrl,
        ),
      );
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authService.signInWithGoogle();
      // State will update via _AuthUserChanged from stream
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInAnonymously(
    SignInAnonymously event,
    Emitter<AuthState> emit,
  ) async {
    if (!kDebugMode && !useEmulators) return;
    emit(const AuthLoading());
    try {
      await _authService.signInAnonymously();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    await _authService.signOut();
    // State will update via _AuthUserChanged from stream
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
