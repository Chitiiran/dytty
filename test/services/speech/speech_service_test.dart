import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:dytty/services/speech/speech_service.dart';

class MockSpeechToText extends Mock implements SpeechToText {}

void main() {
  late MockSpeechToText mockStt;
  late SpeechService service;

  setUp(() {
    mockStt = MockSpeechToText();
    service = SpeechService(speech: mockStt);
  });

  group('SpeechService.startListening', () {
    setUp(() {
      // Simulate initialized state
      when(() => mockStt.initialize()).thenAnswer((_) async => true);
      when(
        () => mockStt.listen(
          onResult: any(named: 'onResult'),
          pauseFor: any(named: 'pauseFor'),
          listenFor: any(named: 'listenFor'),
        ),
      ).thenAnswer((_) async {});
    });

    test(
      'forwards pauseFor and listenFor defaults to SpeechToText.listen',
      () async {
        await service.initialize();
        await service.startListening(onResult: (_) {});

        verify(
          () => mockStt.listen(
            onResult: any(named: 'onResult'),
            pauseFor: const Duration(seconds: 5),
            listenFor: const Duration(seconds: 120),
          ),
        ).called(1);
      },
    );

    test(
      'forwards custom pauseFor and listenFor to SpeechToText.listen',
      () async {
        await service.initialize();
        await service.startListening(
          onResult: (_) {},
          pauseFor: const Duration(seconds: 10),
          listenFor: const Duration(seconds: 60),
        );

        verify(
          () => mockStt.listen(
            onResult: any(named: 'onResult'),
            pauseFor: const Duration(seconds: 10),
            listenFor: const Duration(seconds: 60),
          ),
        ).called(1);
      },
    );

    test('does not call listen when not initialized', () async {
      await service.startListening(onResult: (_) {});

      verifyNever(
        () => mockStt.listen(
          onResult: any(named: 'onResult'),
          pauseFor: any(named: 'pauseFor'),
          listenFor: any(named: 'listenFor'),
        ),
      );
    });
  });

  group('SpeechService.stopListening', () {
    setUp(() {
      when(() => mockStt.stop()).thenAnswer((_) async {});
    });

    test('delegates to SpeechToText.stop', () async {
      await service.stopListening();

      verify(() => mockStt.stop()).called(1);
    });
  });

  group('SpeechService.cancel', () {
    setUp(() {
      when(() => mockStt.cancel()).thenAnswer((_) async {});
    });

    test('delegates to SpeechToText.cancel', () async {
      await service.cancel();

      verify(() => mockStt.cancel()).called(1);
    });
  });

  group('SpeechService.dispose', () {
    setUp(() {
      when(() => mockStt.cancel()).thenAnswer((_) async {});
    });

    test('calls cancel on underlying SpeechToText', () {
      service.dispose();

      verify(() => mockStt.cancel()).called(1);
    });
  });

  group('SpeechService.isAvailable', () {
    test('returns false before initialization', () {
      expect(service.isAvailable, isFalse);
    });

    test('returns true after successful initialization', () async {
      when(() => mockStt.initialize()).thenAnswer((_) async => true);

      await service.initialize();

      expect(service.isAvailable, isTrue);
    });

    test('returns false after failed initialization', () async {
      when(() => mockStt.initialize()).thenAnswer((_) async => false);

      await service.initialize();

      expect(service.isAvailable, isFalse);
    });
  });

  group('SpeechService.isListening', () {
    test('delegates to SpeechToText.isListening', () {
      when(() => mockStt.isListening).thenReturn(false);
      expect(service.isListening, isFalse);

      when(() => mockStt.isListening).thenReturn(true);
      expect(service.isListening, isTrue);
    });
  });
}
