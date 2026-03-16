# ADR-001: Bloc over Provider for State Management

## Status
Accepted

## Context
The app requires state management for complex voice session flows (idle, connecting, listening, processing, saving). Provider with ChangeNotifier does not model explicit state machines well -- there is no compile-time enforcement of valid state transitions, and complex flows become tangled with boolean flags and nullable fields.

## Decision
Use Bloc (flutter_bloc) for all state management across the app. Each feature gets its own Bloc or Cubit:

- **AuthBloc** -- authentication flow
- **JournalBloc** -- daily entries CRUD
- **ThemeCubit** -- light/dark mode
- **VoiceNoteBloc** -- anytime voice note recording and transcription
- **VoiceCallBloc** -- scheduled daily call session
- **SettingsCubit** -- user preferences

## Consequences
- More boilerplate per feature (events, states, bloc class).
- Explicit state machines catch impossible transitions at compile time.
- Fully testable with `bloc_test` (given event, expect states).
- Consistent pattern across the entire app -- every feature follows the same structure.
- Team members can understand any feature by reading its states and events.
