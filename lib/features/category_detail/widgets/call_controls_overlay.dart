import 'package:flutter/material.dart';

/// Minimal bottom bar for the embedded review call.
/// Shows mute toggle, end call FAB, and optional elapsed time.
class CallControlsOverlay extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onEndCall;
  final Duration? elapsed;

  const CallControlsOverlay({
    super.key,
    required this.isMuted,
    required this.onToggleMute,
    required this.onEndCall,
    this.elapsed,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute toggle
          Semantics(
            label: isMuted ? 'Unmute microphone' : 'Mute microphone',
            child: IconButton.filled(
              onPressed: onToggleMute,
              tooltip: isMuted ? 'Unmute' : 'Mute',
              icon: Icon(isMuted ? Icons.mic_off : Icons.mic),
              style: IconButton.styleFrom(
                backgroundColor: isMuted
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: isMuted
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onSurface,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),

          // Elapsed time
          if (elapsed != null)
            Text(
              _formatDuration(elapsed!),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

          // End call
          Semantics(
            label: 'End call',
            child: FloatingActionButton.small(
              onPressed: onEndCall,
              tooltip: 'End call',
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
