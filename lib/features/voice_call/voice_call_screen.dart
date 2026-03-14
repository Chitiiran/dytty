import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/voice_call/gemini_live_service.dart';

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioOutputSub;
  final AudioPlayer _player = AudioPlayer();
  final List<int> _audioBuffer = [];

  @override
  void dispose() {
    _audioOutputSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startCall() async {
    final bloc = context.read<VoiceCallBloc>();

    // Request mic permission
    if (!await _recorder.hasPermission()) return;

    bloc.add(const StartCall());

    // Listen for audio output from model
    _audioOutputSub = bloc.audioOutputStream.listen((audioData) {
      _audioBuffer.addAll(audioData);
      // Buffer audio and play in chunks to avoid choppy playback
      if (_audioBuffer.length > 24000) {
        // ~0.5s at 24kHz 16-bit mono
        _playAudioBuffer();
      }
    });

    // Start recording mic audio and stream to bloc
    // PCM 16kHz 16-bit mono — the format Gemini expects
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    stream.listen((data) {
      bloc.sendAudio(Uint8List.fromList(data));
    });
  }

  Future<void> _endCall() async {
    final bloc = context.read<VoiceCallBloc>();
    await _recorder.stop();
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    _audioBuffer.clear();
    bloc.add(const EndCall());
  }

  void _playAudioBuffer() {
    // For the prototype, we accumulate PCM and play via just_audio.
    // Production would use a streaming audio player.
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();

    // Create a WAV header for PCM data (24kHz, 16-bit, mono)
    final wav = _createWavFromPcm(bytes, sampleRate: 24000);
    _player.setAudioSource(
      _InMemoryAudioSource(wav, 'audio/wav'),
    );
    _player.play();
  }

  Uint8List _createWavFromPcm(Uint8List pcmData, {required int sampleRate}) {
    final byteRate = sampleRate * 2; // 16-bit mono
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    // RIFF header
    header.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    // fmt chunk
    header.setUint32(12, 0x666D7420, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    header.setUint32(36, 0x64617461, Endian.big); // "data"
    header.setUint32(40, dataSize, Endian.little);

    return Uint8List.fromList([
      ...header.buffer.asUint8List(),
      ...pcmData,
    ]);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Call'),
        actions: [
          BlocBuilder<VoiceCallBloc, VoiceCallState>(
            builder: (context, state) {
              if (state.latencyMs != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _latencyColor(state.latencyMs!)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${state.latencyMs}ms',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _latencyColor(state.latencyMs!),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<VoiceCallBloc, VoiceCallState>(
        builder: (context, state) {
          return Column(
            children: [
              // Status + elapsed
              _StatusBar(
                status: state.status,
                elapsed: state.elapsed,
                formatDuration: _formatDuration,
              ),

              // Transcripts
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: state.transcripts.length,
                  itemBuilder: (context, index) {
                    final transcript = state.transcripts[
                        state.transcripts.length - 1 - index];
                    return _TranscriptBubble(
                      transcript: transcript,
                    );
                  },
                ),
              ),

              // Saved entries indicator
              if (state.savedEntries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bookmark_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${state.savedEntries.length} '
                        '${state.savedEntries.length == 1 ? 'entry' : 'entries'} saved',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Call control
              Padding(
                padding: const EdgeInsets.all(24),
                child: _CallButton(
                  status: state.status,
                  onStart: _startCall,
                  onEnd: _endCall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _latencyColor(int ms) {
    if (ms <= 200) return const Color(0xFF10B981); // green
    if (ms <= 400) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFEF4444); // red
  }
}

class _StatusBar extends StatelessWidget {
  final VoiceCallStatus status;
  final Duration elapsed;
  final String Function(Duration) formatDuration;

  const _StatusBar({
    required this.status,
    required this.elapsed,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    Color color;
    switch (status) {
      case VoiceCallStatus.idle:
        label = 'Ready to connect';
        color = theme.colorScheme.onSurfaceVariant;
      case VoiceCallStatus.connecting:
        label = 'Connecting...';
        color = theme.colorScheme.tertiary;
      case VoiceCallStatus.active:
        label = 'In call  ${formatDuration(elapsed)}';
        color = const Color(0xFF10B981);
      case VoiceCallStatus.ending:
        label = 'Ending call...';
        color = theme.colorScheme.onSurfaceVariant;
      case VoiceCallStatus.error:
        label = 'Connection error';
        color = theme.colorScheme.error;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (status == VoiceCallStatus.active)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptBubble extends StatelessWidget {
  final Transcript transcript;

  const _TranscriptBubble({required this.transcript});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = transcript.speaker == Speaker.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          transcript.text,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final VoiceCallStatus status;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _CallButton({
    required this.status,
    required this.onStart,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isActive =
        status == VoiceCallStatus.active || status == VoiceCallStatus.connecting;

    return SizedBox(
      width: 80,
      height: 80,
      child: FloatingActionButton.large(
        onPressed: isActive ? onEnd : onStart,
        backgroundColor: isActive
            ? const Color(0xFFEF4444)
            : Theme.of(context).colorScheme.primary,
        child: Icon(
          isActive ? Icons.call_end_rounded : Icons.call_rounded,
          size: 36,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// In-memory audio source for just_audio.
class _InMemoryAudioSource extends StreamAudioSource {
  final Uint8List _data;
  final String _contentType;

  _InMemoryAudioSource(this._data, this._contentType);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _data.length;
    return StreamAudioResponse(
      sourceLength: _data.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_data.sublist(start, end)),
      contentType: _contentType,
    );
  }
}
