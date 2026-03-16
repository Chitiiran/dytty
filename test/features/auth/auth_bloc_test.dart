import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/services/auth/auth_service.dart';

@GenerateNiceMocks([MockSpec<AuthService>(), MockSpec<User>()])
import 'auth_bloc_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late StreamController<User?> authStreamController;

  setUp(() {
    mockAuthService = MockAuthService();
    authStreamController = StreamController<User?>.broadcast();
    when(
      mockAuthService.authStateChanges,
    ).thenAnswer((_) => authStreamController.stream);
  });

  tearDown(() {
    authStreamController.close();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when stream fires with user',
      build: () => AuthBloc(authService: mockAuthService),
      act: (bloc) {
        final user = MockUser();
        when(user.uid).thenReturn('uid-123');
        when(user.displayName).thenReturn('Test User');
        when(user.email).thenReturn('test@example.com');
        when(user.photoURL).thenReturn(null);
        authStreamController.add(user);
      },
      expect: () => [
        isA<Authenticated>()
            .having((s) => s.uid, 'uid', 'uid-123')
            .having((s) => s.displayName, 'displayName', 'Test User'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits Unauthenticated when stream fires with null',
      build: () => AuthBloc(authService: mockAuthService),
      act: (bloc) {
        authStreamController.add(null);
      },
      expect: () => [const Unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthLoading then waits for stream on SignInWithGoogle',
      build: () => AuthBloc(authService: mockAuthService),
      setUp: () {
        when(
          mockAuthService.signInWithGoogle(),
        ).thenAnswer((_) async => throw UnimplementedError());
      },
      act: (bloc) => bloc.add(const SignInWithGoogle()),
      expect: () => [const AuthLoading(), isA<AuthError>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthError on sign-in failure',
      build: () => AuthBloc(authService: mockAuthService),
      setUp: () {
        when(
          mockAuthService.signInWithGoogle(),
        ).thenThrow(Exception('sign-in failed'));
      },
      act: (bloc) => bloc.add(const SignInWithGoogle()),
      expect: () => [
        const AuthLoading(),
        isA<AuthError>().having(
          (s) => s.message,
          'message',
          contains('sign-in failed'),
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'calls authService.signOut on SignOut',
      build: () => AuthBloc(authService: mockAuthService),
      setUp: () {
        when(mockAuthService.signOut()).thenAnswer((_) async {});
      },
      act: (bloc) => bloc.add(const SignOut()),
      verify: (_) {
        verify(mockAuthService.signOut()).called(1);
      },
    );
  });
}
