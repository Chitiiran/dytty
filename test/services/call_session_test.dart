import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:record/record.dart';

import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';
import 'package:dytty/services/call_session.dart';

// --- Mocks ---

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class MockVoiceCallBloc extends MockBloc<VoiceCallEvent, VoiceCallState>
    implements VoiceCallBloc {}

void main() {
  late MockAudioRecorder mockRecorder;
  late MockAudioPlaybackService mockPlayback;
  late MockVoiceCallBloc mockBloc;
  late CallSession session;

  setUpAll(() {
    registerFallbackValue(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRecorder = MockAudioRecorder();
    mockPlayback = MockAudioPlaybackService();
    mockBloc = MockVoiceCallBloc();

    session = CallSession(
      recorder: mockRecorder,
      playback: mockPlayback,
      bloc: mockBloc,
    );
  });

  group('CallSession', () {
    group('requestPermission', () {
      test('returns true when recorder grants permission', () async {
        when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);

        final result = await session.requestPermission();

        expect(result, true);
        verify(() => mockRecorder.hasPermission()).called(1);
      });

      test('returns false when recorder denies permission', () async {
        when(() => mockRecorder.hasPermission()).thenAnswer((_) async => false);

        final result = await session.requestPermission();

        expect(result, false);
        verify(() => mockRecorder.hasPermission()).called(1);
      });
    });

    group('initPlayback', () {
      test('initializes playback and subscribes to audio output', () async {
        when(
          () => mockPlayback.init(sampleRate: 24000, channels: 1),
        ).thenAnswer((_) async {});
        when(
          () => mockBloc.audioOutputStream,
        ).thenAnswer((_) => const Stream<Uint8List>.empty());

        await session.initPlayback();

        verify(
          () => mockPlayback.init(sampleRate: 24000, channels: 1),
        ).called(1);
        verify(() => mockBloc.audioOutputStream).called(1);
      });

      test('feeds audio data from bloc output to playback', () async {
        final audioData = Uint8List.fromList([1, 2, 3, 4]);
        final controller = StreamController<Uint8List>();

        when(
          () => mockPlayback.init(sampleRate: 24000, channels: 1),
        ).thenAnswer((_) async {});
        when(
          () => mockBloc.audioOutputStream,
        ).thenAnswer((_) => controller.stream);
        when(() => mockPlayback.feed(any())).thenAnswer((_) async {});

        await session.initPlayback();
        controller.add(audioData);

        // Allow the stream listener to process
        await Future<void>.delayed(Duration.zero);

        verify(() => mockPlayback.feed(audioData)).called(1);

        await controller.close();
      });
    });

    group('startRecording', () {
      test('starts recorder stream and sends audio to bloc', () async {
        final audioData = Uint8List.fromList([5, 6, 7, 8]);
        final controller = StreamController<Uint8List>();

        when(
          () => mockRecorder.startStream(any()),
        ).thenAnswer((_) async => controller.stream);

        await session.startRecording();

        verify(
          () => mockRecorder.startStream(
            any(
              that: isA<RecordConfig>()
                  .having((c) => c.encoder, 'encoder', AudioEncoder.pcm16bits)
                  .having((c) => c.sampleRate, 'sampleRate', 16000)
                  .having((c) => c.numChannels, 'numChannels', 1),
            ),
          ),
        ).called(1);

        controller.add(audioData);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockBloc.sendAudio(any())).called(1);

        await controller.close();
      });
    });

    group('stop', () {
      test('stops recorder and playback', () async {
        // First set up recording so there are subscriptions to cancel
        final recorderController = StreamController<Uint8List>();
        final audioController = StreamController<Uint8List>();

        when(
          () => mockPlayback.init(sampleRate: 24000, channels: 1),
        ).thenAnswer((_) async {});
        when(
          () => mockBloc.audioOutputStream,
        ).thenAnswer((_) => audioController.stream);
        when(
          () => mockRecorder.startStream(any()),
        ).thenAnswer((_) async => recorderController.stream);
        when(() => mockRecorder.stop()).thenAnswer((_) async => null);
        when(() => mockPlayback.stop()).thenAnswer((_) async {});

        await session.initPlayback();
        await session.startRecording();

        await session.stop();

        verify(() => mockRecorder.stop()).called(1);
        verify(() => mockPlayback.stop()).called(1);

        await recorderController.close();
        await audioController.close();
      });

      test('is safe to call when no streams are active', () async {
        when(() => mockRecorder.stop()).thenAnswer((_) async => null);
        when(() => mockPlayback.stop()).thenAnswer((_) async {});

        // Should not throw
        await session.stop();

        verify(() => mockRecorder.stop()).called(1);
        verify(() => mockPlayback.stop()).called(1);
      });
    });

    group('dispose', () {
      test('disposes recorder and playback', () {
        when(() => mockRecorder.dispose()).thenAnswer((_) async {});
        when(() => mockPlayback.dispose()).thenReturn(null);

        session.dispose();

        verify(() => mockRecorder.dispose()).called(1);
        verify(() => mockPlayback.dispose()).called(1);
      });

      test('cancels active subscriptions', () async {
        final recorderController = StreamController<Uint8List>();
        final audioController = StreamController<Uint8List>();

        when(
          () => mockPlayback.init(sampleRate: 24000, channels: 1),
        ).thenAnswer((_) async {});
        when(
          () => mockBloc.audioOutputStream,
        ).thenAnswer((_) => audioController.stream);
        when(
          () => mockRecorder.startStream(any()),
        ).thenAnswer((_) async => recorderController.stream);
        when(() => mockRecorder.dispose()).thenAnswer((_) async {});
        when(() => mockPlayback.dispose()).thenReturn(null);

        await session.initPlayback();
        await session.startRecording();

        session.dispose();

        // Verify stream controllers have no listeners after dispose
        expect(recorderController.hasListener, false);
        expect(audioController.hasListener, false);

        await recorderController.close();
        await audioController.close();
      });
    });
  });
}
