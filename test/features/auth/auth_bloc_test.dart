import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/services/auth/auth_service.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
  MockSpec<User>(),
  MockSpec<UserCredential>(),
])
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

    group('SignInAnonymously', () {
      blocTest<AuthBloc, AuthState>(
        'emits AuthLoading then waits for stream on success (debug mode)',
        build: () => AuthBloc(authService: mockAuthService),
        setUp: () {
          when(
            mockAuthService.signInAnonymously(),
          ).thenAnswer((_) async => MockUserCredential());
        },
        act: (bloc) => bloc.add(const SignInAnonymously()),
        expect: () => [const AuthLoading()],
        verify: (_) {
          verify(mockAuthService.signInAnonymously()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits AuthLoading then AuthError on failure',
        build: () => AuthBloc(authService: mockAuthService),
        setUp: () {
          when(
            mockAuthService.signInAnonymously(),
          ).thenThrow(Exception('anon-sign-in failed'));
        },
        act: (bloc) => bloc.add(const SignInAnonymously()),
        expect: () => [
          const AuthLoading(),
          isA<AuthError>().having(
            (s) => s.message,
            'message',
            contains('anon-sign-in failed'),
          ),
        ],
      );
    });

    group('Event equality', () {
      test('SignInWithGoogle instances are equal', () {
        expect(const SignInWithGoogle(), equals(const SignInWithGoogle()));
        expect(const SignInWithGoogle().props, equals([]));
      });

      test('SignInAnonymously instances are equal', () {
        expect(const SignInAnonymously(), equals(const SignInAnonymously()));
        expect(const SignInAnonymously().props, equals([]));
      });

      test('SignOut instances are equal', () {
        expect(const SignOut(), equals(const SignOut()));
        expect(const SignOut().props, equals([]));
      });
    });

    group('State equality', () {
      test('AuthInitial instances are equal', () {
        expect(const AuthInitial(), equals(const AuthInitial()));
        expect(const AuthInitial().props, equals([]));
      });

      test('AuthLoading instances are equal', () {
        expect(const AuthLoading(), equals(const AuthLoading()));
      });

      test('Unauthenticated instances are equal', () {
        expect(const Unauthenticated(), equals(const Unauthenticated()));
      });

      test('Authenticated with same props are equal', () {
        const a = Authenticated(uid: 'u1', displayName: 'A');
        const b = Authenticated(uid: 'u1', displayName: 'A');
        expect(a, equals(b));
        expect(a.props, equals(['u1', 'A', null, null]));
      });

      test('Authenticated with different props are not equal', () {
        const a = Authenticated(uid: 'u1');
        const b = Authenticated(uid: 'u2');
        expect(a, isNot(equals(b)));
      });

      test('AuthError with same message are equal', () {
        const a = AuthError('fail');
        const b = AuthError('fail');
        expect(a, equals(b));
        expect(a.props, equals(['fail']));
      });

      test('AuthError with different messages are not equal', () {
        const a = AuthError('fail');
        const b = AuthError('other');
        expect(a, isNot(equals(b)));
      });
    });
  });
}
