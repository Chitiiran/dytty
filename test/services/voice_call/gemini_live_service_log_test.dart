import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dytty/services/voice_call/gemini_live_service.dart';

/// Diagnostic-logging contract for issue #222: "daily call AI audio not heard
/// — only transcript renders."
///
/// `_handleContent` already logs "AI said: ..." for output transcription, but
/// logs nothing when an audio chunk arrives. That gap makes it impossible to
/// tell — from a device logcat — whether the model is sending audio at all
/// (chunks never arrive) versus the native player swallowing it (chunks arrive
/// but produce no sound). These tests pin the missing log line so the on-device
/// repro becomes a binary fork in the road.
void main() {
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  group('[DYTTY] audio chunk logging (#222)', () {
    test('logs byte count when an audio chunk is emitted', () {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      service.emitAudioChunk(Uint8List(960));

      expect(
        logs.any((l) => l.contains('[DYTTY] Audio chunk received: 960 bytes')),
        isTrue,
        reason:
            'an arriving audio chunk must be logged so device logcat can '
            'distinguish "model sent no audio" from "player produced no sound"',
      );
    });

    test('still forwards the chunk to audioStream', () async {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      final received = <Uint8List>[];
      service.audioStream.listen(received.add);

      final chunk = Uint8List.fromList([1, 2, 3, 4]);
      service.emitAudioChunk(chunk);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, chunk);
    });

    test('logs the actual byte count for each chunk size', () {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      service.emitAudioChunk(Uint8List(4));
      service.emitAudioChunk(Uint8List(2048));

      expect(
        logs.any((l) => l.contains('[DYTTY] Audio chunk received: 4 bytes')),
        isTrue,
      );
      expect(
        logs.any((l) => l.contains('[DYTTY] Audio chunk received: 2048 bytes')),
        isTrue,
      );
    });
  });

  // #12 barge-in: open-mic architecture. Gemini runs server-side VAD and sets
  // LiveServerContent.interrupted == true when the user speaks over the AI.
  // The service surfaces that as interruptStream so the UI can stop + flush
  // buffered AI audio. (Validated on device 2026-06-15: the signal fires.)
  group('[DYTTY] interrupt signal (#12)', () {
    test('emits on interruptStream when an interrupt is handled', () async {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      var count = 0;
      service.interruptStream.listen((_) => count++);

      service.handleInterruptForTest();
      await Future<void>.delayed(Duration.zero);

      expect(count, 1);
    });

    test('logs the interruption for device observability', () {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      service.handleInterruptForTest();

      expect(
        logs.any((l) => l.contains('[DYTTY] Interrupted by user')),
        isTrue,
      );
    });

    // #12 Tier 1 (ghost-input fix): after a barge-in we've yielded the floor to
    // the user, so the AI's decaying speaker tail must NOT be streamed back as
    // input (Gemini transcribes it as phantom user speech). Suppress mic-send
    // for a short window after the interrupt — the "ASR gating during cancel
    // window" layer validated across LiveKit / Pipecat / Reflection.app.
    test('suppresses mic-send for a window after an interrupt', () {
      fakeAsync((async) {
        final service = GeminiLiveService();
        addTearDown(service.dispose);

        expect(
          service.isMicSuppressed,
          isFalse,
          reason: 'not suppressed before any interrupt',
        );

        service.handleInterruptForTest();
        expect(
          service.isMicSuppressed,
          isTrue,
          reason: 'the echo tail window opens on interrupt',
        );

        // Still within the window.
        async.elapse(GeminiLiveService.postInterruptSuppression * 0.5);
        expect(service.isMicSuppressed, isTrue);

        // Window elapsed — mic reopens.
        async.elapse(GeminiLiveService.postInterruptSuppression);
        expect(
          service.isMicSuppressed,
          isFalse,
          reason: 'the user keeps the floor once the tail has decayed',
        );
      });
    });
  });

  // #223: latency must be measured end-of-user-speech -> first-AI-audio, NOT
  // from the user's first chunk (which inflates it by the whole utterance +
  // Gemini's VAD wait). The clock anchors to the LATEST user chunk.
  group('latency measurement (#223)', () {
    test('measures from the user last chunk, not the first', () {
      var now = 0;
      final service = GeminiLiveService(nowMs: () => now);
      addTearDown(service.dispose);

      now = 1000; // user starts speaking
      service.noteUserAudioForTest();
      now = 1700; // ...still speaking (700ms of utterance)
      service.noteUserAudioForTest();
      now = 2000; // last user chunk (end of speech)
      service.noteUserAudioForTest();

      now = 3635; // AI's first audio arrives
      service.noteAiAudioForTest();

      // 3635 - 2000 = 1635 (end-of-speech -> AI audio), NOT 3635 - 1000 = 2635.
      expect(service.lastLatencyMs, 1635);
    });

    test('p50 reflects the corrected per-turn latency', () {
      var now = 0;
      final service = GeminiLiveService(nowMs: () => now);
      addTearDown(service.dispose);

      // One full turn: speak at 500, last chunk 1000, AI audio at 2600 -> 1600.
      now = 500;
      service.noteUserAudioForTest();
      now = 1000;
      service.noteUserAudioForTest();
      now = 2600;
      service.noteAiAudioForTest();

      expect(service.latencyP50, 1600);
    });
  });

  // #227: when the Gemini WebSocket closes (e.g. 1008 mid-session), the receive
  // loop must null the session so sendAudio stops firing into the dead socket
  // (which previously threw an unhandled exception every mic tick — the "lock").
  group('session close recovery (#227)', () {
    test('sendAudio is a no-op once the session is marked closed', () {
      final service = GeminiLiveService();
      addTearDown(service.dispose);

      service.markClosedForTest();

      // Must not throw, and the session is no longer connected.
      service.sendAudio(Uint8List(4));
      expect(service.isConnected, isFalse);
    });
  });
}
