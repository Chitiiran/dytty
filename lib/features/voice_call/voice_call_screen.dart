import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dytty/features/auth/bloc/auth_bloc.dart';
import 'package:dytty/features/daily_journal/bloc/journal_bloc.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/services/llm/llm_service.dart';
import 'package:dytty/services/storage/audio_storage_service.dart';
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

  late GeminiLiveService _service;
  late VoiceCallBloc _bloc;

  @override
  void initState() {
    super.initState();
    _service = GeminiLiveService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wire dependencies for entry persistence, audio upload, and post-call summary
    final authState = context.read<AuthBloc>().state;
    final uid = authState is Authenticated ? authState.uid : null;

    _bloc = VoiceCallBloc(
      service: _service,
      journalBloc: context.read<JournalBloc>(),
      llmService: context.read<LlmService>(),
      audioStorage: context.read<AudioStorageService>(),
      uid: uid,
    );
  }

  @override
  void dispose() {
    _audioOutputSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _startCall() async {
    if (!await _recorder.hasPermission()) return;

    _bloc.add(const StartCall());

    _audioOutputSub = _bloc.audioOutputStream.listen((audioData) {
      _audioBuffer.addAll(audioData);
      if (_audioBuffer.length > 24000) {
        _playAudioBuffer();
      }
    });

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    stream.listen((data) {
      _bloc.sendAudio(Uint8List.fromList(data));
    });
  }

  Future<void> _endCall() async {
    await _recorder.stop();
    _audioOutputSub?.cancel();
    _audioOutputSub = null;
    _audioBuffer.clear();
    _bloc.add(const EndCall());
  }

  void _playAudioBuffer() {
    final bytes = Uint8List.fromList(_audioBuffer);
    _audioBuffer.clear();
    final wav = _createWavFromPcm(bytes, sampleRate: 24000);
    _player.setAudioSource(_InMemoryAudioSource(wav, 'audio/wav'));
    _player.play();
  }

  Uint8List _createWavFromPcm(Uint8List pcmData, {required int sampleRate}) {
    final byteRate = sampleRate * 2;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big);
    header.setUint32(12, 0x666D7420, Endian.big);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint32(36, 0x64617461, Endian.big);
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
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<VoiceCallBloc, VoiceCallState>(
        builder: (context, state) {
          // Post-call summary screen
          if (state.status == VoiceCallStatus.ended) {
            return _PostCallSummary(
              savedEntries: state.savedEntries,
              elapsed: state.elapsed,
              latencyMs: state.latencyMs,
              sessionSummary: state.sessionSummary,
              generatingSummary: state.generatingSummary,
              audioUrl: state.audioUrl,
              uploadingAudio: state.uploadingAudio,
              formatDuration: _formatDuration,
              onDone: () => Navigator.pop(context),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('Daily Call'),
              actions: [
                if (state.latencyMs != null)
                  Padding(
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
                  ),
              ],
            ),
            body: Column(
              children: [
                // Status bar
                _StatusBar(
                  status: state.status,
                  elapsed: state.elapsed,
                  timeRemaining: state.timeRemaining,
                  isNearTimeout: state.isNearTimeout,
                  formatDuration: _formatDuration,
                ),

                // Time warning banner
                if (state.showTimeWarning &&
                    state.status == VoiceCallStatus.active)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: state.isNearTimeout
                        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: state.isNearTimeout
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDuration(state.timeRemaining)} remaining',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: state.isNearTimeout
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
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
                      return _TranscriptBubble(transcript: transcript);
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
            ),
          );
        },
      ),
    );
  }

  Color _latencyColor(int ms) {
    if (ms <= 200) return const Color(0xFF10B981);
    if (ms <= 400) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// --- Post-call summary ---

class _PostCallSummary extends StatelessWidget {
  final List<SavedEntry> savedEntries;
  final Duration elapsed;
  final int? latencyMs;
  final String? sessionSummary;
  final bool generatingSummary;
  final String? audioUrl;
  final bool uploadingAudio;
  final String Function(Duration) formatDuration;
  final VoidCallback onDone;

  const _PostCallSummary({
    required this.savedEntries,
    required this.elapsed,
    required this.latencyMs,
    this.sessionSummary,
    this.generatingSummary = false,
    this.audioUrl,
    this.uploadingAudio = false,
    required this.formatDuration,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Call Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                icon: Icons.timer_outlined,
                label: formatDuration(elapsed),
                caption: 'Duration',
              ),
              _StatChip(
                icon: Icons.bookmark_rounded,
                label: '${savedEntries.length}',
                caption: 'Entries',
              ),
              if (latencyMs != null)
                _StatChip(
                  icon: Icons.speed_rounded,
                  label: '${latencyMs}ms',
                  caption: 'Latency',
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Session summary (loading or generated)
          if (generatingSummary)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generating summary...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (sessionSummary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Summary',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sessionSummary!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Audio upload status
          if (uploadingAudio)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Uploading audio...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else if (audioUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Audio saved to cloud',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (savedEntries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No entries were captured during this session.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            Text(
              'Captured entries',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...savedEntries.map((entry) => _SavedEntryTile(entry: entry)),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SavedEntryTile extends StatelessWidget {
  final SavedEntry entry;

  const _SavedEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: entry.category.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                entry.category.icon,
                size: 18,
                color: entry.category.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.category.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.category.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.text,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared widgets ---

class _StatusBar extends StatelessWidget {
  final VoiceCallStatus status;
  final Duration elapsed;
  final Duration timeRemaining;
  final bool isNearTimeout;
  final String Function(Duration) formatDuration;

  const _StatusBar({
    required this.status,
    required this.elapsed,
    required this.timeRemaining,
    required this.isNearTimeout,
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
        color = isNearTimeout
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);
      case VoiceCallStatus.ending:
        label = 'Saving and ending...';
        color = theme.colorScheme.onSurfaceVariant;
      case VoiceCallStatus.ended:
        label = 'Call ended';
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
    final isActive = status == VoiceCallStatus.active ||
        status == VoiceCallStatus.connecting;

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
