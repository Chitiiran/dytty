import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/voice_call/debug_text_injector.dart';

void main() {
  setUp(DebugTextInjector.instance.reset);

  test('injects into the registered sink', () {
    final received = <String>[];
    DebugTextInjector.instance.register(received.add);

    DebugTextInjector.instance.inject('I am grateful for him.');

    expect(received, ['I am grateful for him.']);
  });

  test('does nothing when no sink is registered', () {
    // Must not throw — a stray broadcast outside a call is a no-op.
    expect(() => DebugTextInjector.instance.inject('hello'), returnsNormally);
  });

  test('unregister stops delivery', () {
    final received = <String>[];
    DebugTextInjector.instance.register(received.add);
    DebugTextInjector.instance.unregister();

    DebugTextInjector.instance.inject('after unregister');

    expect(received, isEmpty);
  });

  test('latest registration wins (one active call at a time)', () {
    final first = <String>[];
    final second = <String>[];
    DebugTextInjector.instance.register(first.add);
    DebugTextInjector.instance.register(second.add);

    DebugTextInjector.instance.inject('hi');

    expect(first, isEmpty);
    expect(second, ['hi']);
  });
}
