import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Debug-only bridge that lets a platform broadcast feed an exact text turn
/// into the active daily call.
///
/// The acoustic demo harness plays the speaker's HUMAN voice aloud (so the
/// room hears it) while sending the AI the speaker's EXACT words via this
/// channel — bypassing lossy over-air STT for flawless capture. The active
/// [VoiceCallScreen] registers a sink (the bloc's InjectUserText dispatch)
/// while a call is live; an `adb` broadcast routed through [channel] then
/// reaches it. A no-op when no call is active.
///
/// This is wired only in debug builds (see main / MainActivity); release
/// builds never register the channel handler.
class DebugTextInjector {
  DebugTextInjector._();
  static final DebugTextInjector instance = DebugTextInjector._();

  static const channel = MethodChannel('dytty/debug_inject');

  void Function(String text)? _sink;

  /// Register the active call's text sink. Latest registration wins, so a
  /// new call replaces a stale one.
  void register(void Function(String text) sink) => _sink = sink;

  /// Stop delivering injected text (call on screen dispose).
  void unregister() => _sink = null;

  /// Deliver [text] to the active sink, if any. No-op otherwise.
  void inject(String text) => _sink?.call(text);

  @visibleForTesting
  void reset() => _sink = null;

  /// Install the platform MethodChannel handler (debug builds only).
  /// Idempotent; safe to call once at startup.
  void installChannelHandler() {
    if (!kDebugMode) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'injectText') {
        final text = call.arguments as String?;
        if (text != null) inject(text);
      }
      return null;
    });
  }
}
