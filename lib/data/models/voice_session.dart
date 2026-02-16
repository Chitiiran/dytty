class VoiceSession {
  final String id;
  final String dailyEntryId;
  final String transcript;
  final int durationSeconds;
  final DateTime startedAt;

  VoiceSession({
    required this.id,
    required this.dailyEntryId,
    required this.transcript,
    required this.durationSeconds,
    required this.startedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'daily_entry_id': dailyEntryId,
      'transcript': transcript,
      'duration_seconds': durationSeconds,
      'started_at': startedAt.toIso8601String(),
    };
  }

  factory VoiceSession.fromMap(Map<String, dynamic> map) {
    return VoiceSession(
      id: map['id'] as String,
      dailyEntryId: map['daily_entry_id'] as String,
      transcript: map['transcript'] as String,
      durationSeconds: map['duration_seconds'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
    );
  }
}
