import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';

/// Shared audio plumbing for voice calls.
///
/// Owns the recorder, playback service, and audio stream subscriptions.
/// Used by both [ReviewCallController] and [VoiceCallScreen] to avoid
/// duplicating permission checks, playback init, and stream wiring.
///
/// Provides granular methods so callers can compose steps as needed
/// (e.g. ReviewCallController inserts a Gemini connect between
/// [initPlayback] and [startRecording]).
class CallSession {
  final AudioRecorder recorder;
  final AudioPlaybackService playback;
  final VoiceCallBloc bloc;

  StreamSubscription<Uint8List>? _audioOutputSub;
  StreamSubscription<Uint8List>? _recordingStreamSub;
  StreamSubscription<void>? _interruptSub;

  CallSession({
    required this.recorder,
    required this.playback,
    required this.bloc,
  });

  /// Initialize playback and wire the audio output stream from the bloc.
  Future<void> initPlayback() async {
    await playback.init(sampleRate: 24000, channels: 1);

    _audioOutputSub = bloc.audioOutputStream.listen((audioData) {
      try {
        playback.feed(audioData);
      } catch (e) {
        debugPrint('Audio playback feed error: $e');
      }
    });

    // #12 barge-in: flush queued AI audio the moment Gemini reports the user
    // spoke over it, so the AI goes silent immediately.
    _interruptSub = bloc.interruptStream.listen((_) async {
      try {
        await playback.flush();
      } catch (e) {
        debugPrint('Audio playback flush error: $e');
      }
    });
  }

  /// Start recording mic input and streaming PCM data to the bloc.
  Future<void> startRecording() async {
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        // #222: hardware acoustic echo cancellation. The VOICE_COMMUNICATION
        // source engages the platform AEC (the mode phone calls use) so the
        // mic doesn't pick up the AI's speaker output and loop it back.
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      ),
    );
    _recordingStreamSub = stream.listen((data) {
      bloc.sendAudio(data);
    });
  }

  /// Stop recording and playback. Does not close the bloc.
  Future<void> stop() async {
    _recordingStreamSub?.cancel();
    _recordingStreamSub = null;
    await recorder.stop();
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    _interruptSub?.cancel();
    _interruptSub = null;
    await playback.stop();
  }

  /// Release all resources. Call this when the session is no longer needed.
  void dispose() {
    _recordingStreamSub?.cancel();
    _recordingStreamSub = null;
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    _interruptSub?.cancel();
    _interruptSub = null;
    recorder.dispose();
    playback.dispose();
  }
}
