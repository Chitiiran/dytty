import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dytty/services/auth/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(FakeAuthCredential());
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    service = AuthService(auth: mockAuth, googleSignIn: mockGoogleSignIn);
  });

  group('AuthService.authStateChanges', () {
    test('delegates to FirebaseAuth.authStateChanges', () {
      final controller = StreamController<User?>.broadcast();
      when(
        () => mockAuth.authStateChanges(),
      ).thenAnswer((_) => controller.stream);

      expect(service.authStateChanges, equals(controller.stream));
      verify(() => mockAuth.authStateChanges()).called(1);

      controller.close();
    });
  });

  group('AuthService.currentUser', () {
    test('delegates to FirebaseAuth.currentUser', () {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      expect(service.currentUser, equals(mockUser));
      verify(() => mockAuth.currentUser).called(1);
    });

    test('returns null when no user is signed in', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(service.currentUser, isNull);
    });
  });

  group('AuthService.signInWithGoogle', () {
    test('returns UserCredential on success', () async {
      final mockAccount = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      final mockCredential = MockUserCredential();

      when(
        () => mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockAccount);
      when(
        () => mockAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(() => mockGoogleAuth.accessToken).thenReturn('access-token');
      when(() => mockGoogleAuth.idToken).thenReturn('id-token');
      when(
        () => mockAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => mockCredential);

      final result = await service.signInWithGoogle();

      expect(result, equals(mockCredential));
      verify(() => mockGoogleSignIn.signIn()).called(1);
      verify(() => mockAuth.signInWithCredential(any())).called(1);
    });

    test('throws when Google Sign-In is cancelled', () async {
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      expect(
        () => service.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Google Sign-In was cancelled'),
          ),
        ),
      );
    });
  });

  group('AuthService.signInAnonymously', () {
    test('delegates to FirebaseAuth.signInAnonymously', () async {
      final mockCredential = MockUserCredential();
      when(
        () => mockAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockCredential);

      final result = await service.signInAnonymously();

      expect(result, equals(mockCredential));
      verify(() => mockAuth.signInAnonymously()).called(1);
    });
  });

  group('AuthService.signOut', () {
    test('signs out of both Firebase and Google', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      await service.signOut();

      verify(() => mockAuth.signOut()).called(1);
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });

    test('only signs out of Firebase when Google not initialized', () async {
      // Create service without GoogleSignIn injected
      final serviceNoGoogle = AuthService(auth: mockAuth);

      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await serviceNoGoogle.signOut();

      verify(() => mockAuth.signOut()).called(1);
      verifyNever(() => mockGoogleSignIn.signOut());
    });
  });
}
