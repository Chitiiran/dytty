import 'dart:typed_data';

import 'package:dytty/services/audio/audio_playback_service.dart';

/// Records all calls for test verification.
class FakeAudioPlaybackService implements AudioPlaybackService {
  final List<String> calls = [];
  final List<Uint8List> fedData = [];

  int? initSampleRate;
  int? initChannels;
  bool _disposed = false;

  /// When set, [feed] will throw this exception.
  Exception? feedError;

  bool get isDisposed => _disposed;

  @override
  Future<void> init({required int sampleRate, required int channels}) async {
    calls.add('init');
    initSampleRate = sampleRate;
    initChannels = channels;
  }

  @override
  Future<void> feed(Uint8List pcmData) async {
    if (feedError != null) throw feedError!;
    calls.add('feed');
    fedData.add(pcmData);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  void dispose() {
    calls.add('dispose');
    _disposed = true;
  }
}
