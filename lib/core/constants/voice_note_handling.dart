/// How a finished voice-note recording proceeds (#32): pause for
/// transcript review, summarize immediately, or keep the raw transcript
/// immediately. Shared by VoiceNoteBloc (routing), SettingsCubit
/// (persistence) and the recording sheet (wiring).
enum VoiceNoteHandling {
  ask,
  summarize,
  raw;

  /// Value stored in the user settings profile document.
  String get storageValue => name;

  static VoiceNoteHandling fromStorage(String? value) =>
      VoiceNoteHandling.values.asNameMap()[value] ?? VoiceNoteHandling.ask;
}
