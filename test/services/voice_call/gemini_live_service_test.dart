import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dytty/services/voice_call/gemini_live_service.dart';

void main() {
  group('Transcript', () {
    test('has correct speaker and text', () {
      final transcript = Transcript(speaker: Speaker.user, text: 'hello');

      expect(transcript.speaker, Speaker.user);
      expect(transcript.text, 'hello');
    });

    test('isFinal defaults to true', () {
      final transcript = Transcript(speaker: Speaker.ai, text: 'response');

      expect(transcript.isFinal, isTrue);
    });

    test('can create with isFinal: false', () {
      final transcript = Transcript(
        speaker: Speaker.user,
        text: 'partial',
        isFinal: false,
      );

      expect(transcript.isFinal, isFalse);
    });
  });

  group('GeminiLiveState', () {
    test('has all expected values', () {
      expect(
        GeminiLiveState.values,
        containsAll([
          GeminiLiveState.idle,
          GeminiLiveState.connecting,
          GeminiLiveState.active,
          GeminiLiveState.disconnecting,
          GeminiLiveState.error,
        ]),
      );
      expect(GeminiLiveState.values, hasLength(5));
    });
  });

  group('GeminiLiveService', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isConnected returns false initially', () {
      expect(service.isConnected, isFalse);
    });

    test('sendAudio is a no-op when not connected', () {
      // Should not throw
      service.sendAudio(Uint8List.fromList([0, 1, 2, 3]));
    });

    test('sendText is a no-op when not connected', () async {
      // Should not throw
      await service.sendText('hello');
    });

    test('sendToolResponse is a no-op when not connected', () async {
      // Should not throw
      await service.sendToolResponse('save_entry', null, {'key': 'value'});
    });

    test('disconnect emits disconnecting then idle states', () async {
      final states = <GeminiLiveState>[];
      service.stateStream.listen(states.add);

      await service.disconnect();

      // Allow stream events to propagate
      await Future<void>.delayed(Duration.zero);

      expect(states, [GeminiLiveState.disconnecting, GeminiLiveState.idle]);
    });

    test('dispose closes all stream controllers', () async {
      // Listen to all streams before disposing
      final audioCompleter = Completer<void>();
      final transcriptCompleter = Completer<void>();
      final toolCallCompleter = Completer<void>();
      final stateCompleter = Completer<void>();

      service.audioStream.listen(null, onDone: audioCompleter.complete);
      service.transcriptStream.listen(
        null,
        onDone: transcriptCompleter.complete,
      );
      service.toolCallStream.listen(null, onDone: toolCallCompleter.complete);
      service.stateStream.listen(null, onDone: stateCompleter.complete);

      service.dispose();

      // All streams should complete (onDone fires)
      await expectLater(audioCompleter.future, completes);
      await expectLater(transcriptCompleter.future, completes);
      await expectLater(toolCallCompleter.future, completes);
      await expectLater(stateCompleter.future, completes);
    });

    test('lastLatencyMs is null initially', () {
      expect(service.lastLatencyMs, isNull);
    });
  });

  group('Speaker', () {
    test('has user and ai values', () {
      expect(Speaker.values, containsAll([Speaker.user, Speaker.ai]));
      expect(Speaker.values, hasLength(2));
    });
  });
}
