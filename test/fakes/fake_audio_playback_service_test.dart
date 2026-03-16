import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'fake_audio_playback_service.dart';

void main() {
  late FakeAudioPlaybackService service;

  setUp(() {
    service = FakeAudioPlaybackService();
  });

  test('records init call with parameters', () async {
    await service.init(sampleRate: 24000, channels: 1);

    expect(service.calls, ['init']);
    expect(service.initSampleRate, 24000);
    expect(service.initChannels, 1);
  });

  test('records feed calls and stores data', () async {
    final chunk1 = Uint8List.fromList([1, 2, 3]);
    final chunk2 = Uint8List.fromList([4, 5, 6]);
    await service.feed(chunk1);
    await service.feed(chunk2);

    expect(service.calls, ['feed', 'feed']);
    expect(service.fedData, [chunk1, chunk2]);
  });

  test('records stop and dispose calls', () async {
    await service.stop();
    service.dispose();

    expect(service.calls, ['stop', 'dispose']);
    expect(service.isDisposed, true);
  });

  test('feed throws when feedError is set', () async {
    service.feedError = Exception('audio error');

    expect(
      () => service.feed(Uint8List.fromList([1, 2])),
      throwsA(isA<Exception>()),
    );
  });

  test('full lifecycle records all calls in order', () async {
    await service.init(sampleRate: 16000, channels: 2);
    await service.feed(Uint8List.fromList([1]));
    await service.feed(Uint8List.fromList([2]));
    await service.stop();
    service.dispose();

    expect(service.calls, ['init', 'feed', 'feed', 'stop', 'dispose']);
  });
}
