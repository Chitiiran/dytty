# ADR-004: Gemini Live Receive Loop for Multi-Turn Sessions

## Status
Accepted

## Context
The `firebase_ai` package (3.9.0) implements `LiveSession.receive()` as an `async*` generator that yields `LiveServerResponse` objects until the server sends `turnComplete: true`, at which point the stream ends (`break` at line 170 of `live_session.dart`). The underlying WebSocket connection and `_messageController` remain open — only the `receive()` stream terminates.

Our original implementation used `receive().listen()` with an `onDone` callback that emitted `GeminiLiveState.idle`. After the AI's first response turn completed, the stream ended, `onDone` fired, the bloc received `idle` during an active call, and dispatched `EndCall` — killing the session after one exchange.

## Decision
Replace the single `receive().listen()` subscription with a **receive loop** pattern:

```dart
while (_session != null) {
  await for (final response in _session!.receive()) {
    // handle response
  }
  // receive() ended (turnComplete) — loop for next turn
}
```

Key design choices:
- **Graceful disconnect**: `disconnect()` sets `_session = null` before closing the session, which breaks the `while` loop cleanly without emitting spurious error states.
- **Error handling**: Exceptions from `receive()` (e.g., WebSocket errors) are caught in a try/catch around the entire loop, emitting `GeminiLiveState.error`.
- **Connection timeout**: Added a 15-second timeout on the initial `liveModel.connect()` call to prevent indefinite hangs.

## Consequences
- Multi-turn voice conversations now work as expected — the session stays alive across multiple AI response turns.
- The `_responseSubscription` field is no longer needed (removed), simplifying cleanup in `disconnect()`.
- If the `firebase_ai` package changes `receive()` to not break at `turnComplete` in a future version, the loop will still work correctly (it will simply not re-enter the inner loop as often).
- Real-device testing is still required to confirm end-to-end behavior, as the fix cannot be fully verified with mocks alone.
