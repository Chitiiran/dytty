import 'dart:typed_data';

/// Abstract interface for streaming PCM audio playback.
///
/// Implementations handle platform-specific audio output (e.g. flutter_pcm_sound).
/// This abstraction enables testing without real audio hardware.
abstract class AudioPlaybackService {
  /// Initialize the audio output with the given format.
  Future<void> init({required int sampleRate, required int channels});

  /// Feed a chunk of raw PCM 16-bit little-endian audio data for playback.
  Future<void> feed(Uint8List pcmData);

  /// Drop all queued audio and re-arm the output, so playback goes silent
  /// immediately. Used on barge-in (#12) — the model queues audio ahead of
  /// playback, so stopping the stream alone would keep playing what's buffered.
  Future<void> flush();

  /// Stop playback and release the audio output.
  Future<void> stop();

  /// Dispose of all resources.
  void dispose();
}
