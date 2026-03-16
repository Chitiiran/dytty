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

  /// Stop playback and release the audio output.
  Future<void> stop();

  /// Dispose of all resources.
  void dispose();
}
