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

  group('GeminiLiveService connection constants', () {
    test('connectionTimeout is 15 seconds', () {
      expect(GeminiLiveService.connectionTimeout, const Duration(seconds: 15));
    });
  });

  group('GeminiLiveService stream types', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('audioStream is a broadcast stream', () {
      // Broadcast streams allow multiple listeners
      service.audioStream.listen((_) {});
      service.audioStream.listen((_) {});
      // No error means it's broadcast
    });

    test('transcriptStream is a broadcast stream', () {
      service.transcriptStream.listen((_) {});
      service.transcriptStream.listen((_) {});
    });

    test('toolCallStream is a broadcast stream', () {
      service.toolCallStream.listen((_) {});
      service.toolCallStream.listen((_) {});
    });

    test('stateStream is a broadcast stream', () {
      service.stateStream.listen((_) {});
      service.stateStream.listen((_) {});
    });
  });

  group('GeminiLiveService disconnect behavior', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isConnected is false after disconnect', () async {
      await service.disconnect();
      expect(service.isConnected, isFalse);
    });

    test('disconnect can be called multiple times safely', () async {
      await service.disconnect();
      await service.disconnect();
      // No error thrown
    });

    test('sendAudio after disconnect is a no-op', () async {
      await service.disconnect();
      service.sendAudio(Uint8List.fromList([1, 2, 3]));
      // No error thrown, lastLatencyMs should remain null
      expect(service.lastLatencyMs, isNull);
    });

    test('sendText after disconnect is a no-op', () async {
      await service.disconnect();
      await service.sendText('hello after disconnect');
      // No error thrown
    });

    test('sendToolResponse after disconnect is a no-op', () async {
      await service.disconnect();
      await service.sendToolResponse('fn', 'id', {'key': 'val'});
      // No error thrown
    });
  });

  group('Transcript equality', () {
    test('transcripts with same fields have same values', () {
      const t1 = Transcript(speaker: Speaker.user, text: 'hi', isFinal: true);
      const t2 = Transcript(speaker: Speaker.user, text: 'hi', isFinal: true);
      expect(t1.speaker, t2.speaker);
      expect(t1.text, t2.text);
      expect(t1.isFinal, t2.isFinal);
    });

    test('transcripts with different speakers differ', () {
      const t1 = Transcript(speaker: Speaker.user, text: 'hi');
      const t2 = Transcript(speaker: Speaker.ai, text: 'hi');
      expect(t1.speaker, isNot(t2.speaker));
    });

    test('transcripts with different isFinal differ', () {
      const t1 = Transcript(speaker: Speaker.user, text: 'hi', isFinal: true);
      const t2 = Transcript(speaker: Speaker.user, text: 'hi', isFinal: false);
      expect(t1.isFinal, isNot(t2.isFinal));
    });
  });

  group('GeminiLiveService stream broadcast behavior', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('multiple stateStream listeners receive same events', () async {
      final states1 = <GeminiLiveState>[];
      final states2 = <GeminiLiveState>[];
      service.stateStream.listen(states1.add);
      service.stateStream.listen(states2.add);

      await service.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states1, [GeminiLiveState.disconnecting, GeminiLiveState.idle]);
      expect(states2, [GeminiLiveState.disconnecting, GeminiLiveState.idle]);
    });

    test('late listener on broadcast stream misses earlier events', () async {
      final earlyStates = <GeminiLiveState>[];
      service.stateStream.listen(earlyStates.add);

      await service.disconnect();
      await Future<void>.delayed(Duration.zero);

      // Late listener added after events were emitted
      final lateStates = <GeminiLiveState>[];
      service.stateStream.listen(lateStates.add);
      await Future<void>.delayed(Duration.zero);

      expect(earlyStates, hasLength(2));
      expect(lateStates, isEmpty);
    });
  });

  group('GeminiLiveService repeated operations', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('sendAudio multiple times when disconnected keeps latency null', () {
      service.sendAudio(Uint8List.fromList([1, 2, 3]));
      service.sendAudio(Uint8List.fromList([4, 5, 6]));
      service.sendAudio(Uint8List.fromList([7, 8, 9]));
      expect(service.lastLatencyMs, isNull);
    });

    test(
      'sendText multiple times when disconnected completes normally',
      () async {
        await service.sendText('first');
        await service.sendText('second');
        await service.sendText('third');
        // No errors thrown
      },
    );

    test('sendToolResponse with various argument types is a no-op', () async {
      await service.sendToolResponse('fn', null, {});
      await service.sendToolResponse('fn', 'id-123', {
        'nested': {'a': 1},
      });
      await service.sendToolResponse('fn', '', {
        'list': [1, 2, 3],
      });
      // No errors thrown
    });

    test('disconnect then sendAudio then disconnect is safe', () async {
      await service.disconnect();
      service.sendAudio(Uint8List.fromList([1]));
      await service.disconnect();
      expect(service.isConnected, isFalse);
    });

    test('interleaving send operations when disconnected is safe', () async {
      service.sendAudio(Uint8List.fromList([1, 2]));
      await service.sendText('text');
      service.sendAudio(Uint8List.fromList([3, 4]));
      await service.sendToolResponse('fn', null, {});
      expect(service.isConnected, isFalse);
      expect(service.lastLatencyMs, isNull);
    });
  });

  group('GeminiLiveService dispose behavior', () {
    test('dispose closes streams so no new events arrive', () async {
      final service = GeminiLiveService();
      final audioEvents = <Uint8List>[];
      final transcriptEvents = <Transcript>[];

      service.audioStream.listen(audioEvents.add, onError: (_) {});
      service.transcriptStream.listen(transcriptEvents.add, onError: (_) {});

      service.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(audioEvents, isEmpty);
      expect(transcriptEvents, isEmpty);
    });

    test('listening after dispose returns done subscription', () async {
      final service = GeminiLiveService();
      service.dispose();

      // Broadcast controllers allow listening after close but
      // immediately fire onDone
      final completer = Completer<void>();
      service.stateStream.listen((_) {}, onDone: completer.complete);

      // onDone fires immediately since the controller is closed
      await expectLater(completer.future, completes);
    });
  });

  group('GeminiLiveService disconnect state sequence', () {
    late GeminiLiveService service;

    setUp(() {
      service = GeminiLiveService();
    });

    tearDown(() {
      service.dispose();
    });

    test('disconnect always emits disconnecting before idle', () async {
      final states = <GeminiLiveState>[];
      service.stateStream.listen(states.add);

      await service.disconnect();
      await Future<void>.delayed(Duration.zero);

      // Verify ordering
      final disconnectingIndex = states.indexOf(GeminiLiveState.disconnecting);
      final idleIndex = states.indexOf(GeminiLiveState.idle);
      expect(disconnectingIndex, lessThan(idleIndex));
    });

    test('multiple disconnects emit state pairs each time', () async {
      final states = <GeminiLiveState>[];
      service.stateStream.listen(states.add);

      await service.disconnect();
      await service.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states, [
        GeminiLiveState.disconnecting,
        GeminiLiveState.idle,
        GeminiLiveState.disconnecting,
        GeminiLiveState.idle,
      ]);
    });
  });
}
