import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/services/audio/pcm_sound_playback_service.dart';

/// #246.2: flush() re-arms the player by calling setup again — it must reuse
/// the sample rate/channels from init(), not silently reset to hardcoded
/// 24000/1 (wrong for any future non-24kHz stream).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_pcm_sound/methods');
  final setupCalls = <Map<Object?, Object?>>[];

  setUp(() {
    setupCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setup') {
            setupCalls.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('flush re-arms with the params init was given', () async {
    final service = PcmSoundPlaybackService();
    await service.init(sampleRate: 44100, channels: 2);
    await service.flush();

    expect(setupCalls, hasLength(2));
    expect(setupCalls.last['sample_rate'], 44100);
    expect(setupCalls.last['num_channels'], 2);
  });

  test('flush before init falls back to the 24kHz mono default', () async {
    final service = PcmSoundPlaybackService();
    await service.flush();

    expect(setupCalls, hasLength(1));
    expect(setupCalls.last['sample_rate'], 24000);
    expect(setupCalls.last['num_channels'], 1);
  });
}
