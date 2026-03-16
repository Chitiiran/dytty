import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:dytty/services/audio/audio_playback_service.dart';

/// Streams raw PCM audio via [FlutterPcmSound] for low-latency playback.
class PcmSoundPlaybackService implements AudioPlaybackService {
  @override
  Future<void> init({required int sampleRate, required int channels}) async {
    await FlutterPcmSound.setup(
      sampleRate: sampleRate,
      channelCount: channels,
    );
  }

  @override
  Future<void> feed(Uint8List pcmData) async {
    final byteData = ByteData.sublistView(pcmData);
    await FlutterPcmSound.feed(PcmArrayInt16(bytes: byteData));
  }

  @override
  Future<void> stop() async {
    await FlutterPcmSound.release();
  }

  @override
  void dispose() {
    FlutterPcmSound.release();
  }
}
