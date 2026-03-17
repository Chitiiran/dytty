# Test Infrastructure & Coverage Improvement (#51, #52)

## Context
Test infrastructure is partially scaffolded but not wired:
- **Patrol** (#51): `integration_test/` has 3 flows + 3 robots, all commented out. `patrol` and `patrol_finders` not in `pubspec.yaml`. Runner script exists at `scripts/patrol-test.sh`.
- **Audio injection** (#52): Research complete (ADR-007, `docs/research/grpc-audio-injection.md`). The emulator gRPC `injectAudio` API is the viable approach — other methods (adb emu, CLI flags, tinymix, Maestro) are all dead ends.
- **Coverage**: 66.6% overall (CI gate: 50%). Several files at 0% that are easy wins.

No big coverage target — goal is to wire the test infra, prove it works, and opportunistically fill low-hanging coverage gaps.

## Approach
1. Add Patrol dependencies, uncomment and verify one flow on a real emulator
2. Build `scripts/inject-audio.py` using emulator gRPC `injectAudio` API, spike end-to-end with `speech_to_text`
3. Add unit tests for 0%-coverage files that are easy to test (services, models)
4. Leave hard-to-test files (app.dart, main.dart, firebase_options.dart) for later

## Current Coverage Snapshot (66.6%)

**0% coverage (actionable):**
| File | Lines | Notes |
|------|-------|-------|
| `services/audio/pcm_sound_playback_service.dart` | 9 | Platform-dependent, test via Patrol |
| `services/auth/auth_service.dart` | 20 | Wraps FirebaseAuth, mockable |
| `services/storage/audio_storage_service.dart` | 13 | Wraps Firebase Storage, mockable |
| `services/llm/gemini_llm_service.dart` | 40 | Wraps Gemini API, mockable |
| `services/voice_call/gemini_live_service.dart` | 93 | Complex, partial coverage feasible |
| `voice_note/voice_note_result.dart` | 1 | Trivial data class |
| `voice_note/widgets/voice_recording_sheet.dart` | 261 | Widget test candidate |

**0% but not worth testing now:**
| File | Lines | Reason |
|------|-------|--------|
| `main.dart` | 15 | Bootstrap, no logic |
| `firebase_options.dart` | 9 | Generated config |
| `app.dart` | 86 | Widget tree wiring, covered by E2E |

## Implementation Steps

### Phase 1: Patrol Setup (#51)

**1.1 — Add dependencies**
```yaml
# pubspec.yaml dev_dependencies
patrol: ^3.13.0
patrol_finders: ^2.4.0
```

**1.2 — Configure patrol in `pubspec.yaml`**
```yaml
patrol:
  app_name: Dytty
  android:
    package_name: com.dytty.dytty
```

**1.3 — Update `app_test_setup.dart`**
- Uncomment setup code
- Import `patrol` package
- Add `patrolTest` wrapper with Firebase emulator config

**1.4 — Uncomment and fix `auth_flow_test.dart`**
- First flow to verify: login -> home screen -> sign out
- Run on local emulator: `bash scripts/patrol-test.sh --flow auth`

**1.5 — Verify remaining flows compile**
- `dashboard_state_test.dart` — uncomment, fix imports
- `journal_crud_test.dart` — uncomment, fix imports
- Don't need all passing yet — just compiling and one flow green

**1.6 — CI consideration**
- Patrol tests require a real emulator — same as Maestro
- Add to existing `maestro` CI job or create separate `patrol` job (decision at implementation time)
- For now, local-only verification is sufficient

### Phase 2: gRPC Audio Injection (#52)

> Research: ADR-007, full notes at `docs/research/grpc-audio-injection.md`

**2.1 — Generate gRPC stubs from local proto**
```bash
pip install grpcio grpcio-tools
python -m grpc_tools.protoc \
  --proto_path=$ANDROID_SDK/emulator/lib \
  --python_out=scripts/grpc_gen \
  --grpc_python_out=scripts/grpc_gen \
  emulator_controller.proto
```
Proto confirmed at: `C:/Users/chiti/AppData/Local/Android/Sdk/emulator/lib/emulator_controller.proto`

**2.2 — Create `scripts/inject-audio.py`**
Helper script that:
1. Discovers running emulator via `pid_*.ini` files in `%LOCALAPPDATA%\Temp\avd\running\` (Windows) or `~/.android/avd/running/` (Linux/Mac)
2. Reads `grpc.address` and `grpc.token` from the INI file
3. Opens WAV file, reads in 300ms chunks
4. Streams `AudioPacket` messages to `EmulatorController.injectAudio()`
5. Uses `MODE_UNSPECIFIED` (blocking, paced by emulator) for reliability

```
Usage: python scripts/inject-audio.py <wav-file> [--realtime]
```

**2.3 — Create test WAV files**
- `test/fixtures/audio/grateful-health.wav` — "I'm grateful for my health today" (5s, 16kHz, mono, 16-bit)
- `test/fixtures/audio/had-good-day.wav` — "I had a really good day" (3s)
- Generated with TTS or manually recorded, committed to repo

**2.4 — Proof of concept on local emulator**
1. Start Pixel 9 emulator
2. Launch Dytty, navigate to voice note recording
3. Run `python scripts/inject-audio.py test/fixtures/audio/grateful-health.wav`
4. Verify `speech_to_text` receives the transcript
5. Document: does it work? Latency? Any STT engine bypass issues?

**2.5 — Integration with Maestro (if spike passes)**
```yaml
# .maestro/voice/voice-input-flow.yaml
- runScript:
    script: python scripts/inject-audio.py test/fixtures/audio/grateful-health.wav
    wait: true
- assertVisible: "grateful.*health"
```

**2.6 — Fallback (if spike fails)**
- If `speech_to_text` uses a private audio pipeline that bypasses `AudioRecord`, injected audio won't reach STT
- Document findings on #52 and close
- The `record` package (daily call raw PCM) should still work — lower risk, separate test

### Phase 3: Unit Test Coverage Gaps

**3.1 — `voice_note_result.dart`** (1 line, trivial)
- Add to existing voice_note_bloc tests or standalone

**3.2 — `auth_service.dart`** (20 lines)
- `test/services/auth/auth_service_test.dart` (new)
- Mock `FirebaseAuth` and `GoogleSignIn` via mocktail
- Test: `signInWithGoogle` success, `signInWithGoogle` failure, `signOut`, `authStateChanges` stream

**3.3 — `audio_storage_service.dart`** (13 lines)
- `test/services/storage/audio_storage_service_test.dart` (new)
- Mock `FirebaseStorage` via mocktail
- Test: `uploadCallAudio` success, upload failure

**3.4 — `gemini_llm_service.dart`** (40 lines)
- `test/services/llm/gemini_llm_service_test.dart` (new)
- Mock `GenerativeModel` via mocktail
- Test: `generateResponse`, `categorizeEntry` JSON parsing, error handling

**3.5 — `voice_recording_sheet.dart`** (261 lines)
- `test/widgets/voice_recording_sheet_test.dart` (new)
- Robot pattern, mock `VoiceNoteBloc`
- Test idle state renders, listening state shows mic animation, review state shows category chips

**3.6 — `gemini_live_service.dart`** (93 lines, partial)
- Extend existing test or create `test/services/voice_call/gemini_live_service_test.dart`
- Test `Transcript` model with `isFinal` field
- Test `_handleContent` logic via mock `LiveSession` if feasible
- Skip `connect()` and `_receiveLoop()` — these need real Firebase, covered by Maestro

### Phase 4: Verify

1. `flutter analyze` — clean
2. `flutter test --coverage --exclude-tags=golden` — all pass
3. Coverage delta: aim for ~70-72% (up from 66.6%), no hard target
4. `bash scripts/patrol-test.sh --flow auth` — one green flow on local emulator
5. #52 spike result documented (pass or fail)

## Critical Files
| File | Action |
|------|--------|
| `pubspec.yaml` | Add patrol, patrol_finders |
| `integration_test/app_test_setup.dart` | Uncomment and wire Patrol |
| `integration_test/flows/auth_flow_test.dart` | Uncomment and verify |
| `scripts/inject-audio.py` | New — gRPC audio injector |
| `scripts/grpc_gen/` | New — generated proto stubs |
| `test/fixtures/audio/*.wav` | New — test audio files |
| `test/services/auth/auth_service_test.dart` | New — unit tests |
| `test/services/storage/audio_storage_service_test.dart` | New — unit tests |
| `test/services/llm/gemini_llm_service_test.dart` | New — unit tests |
| `test/widgets/voice_recording_sheet_test.dart` | New — widget tests |

## Estimated Coverage Impact
| Phase | New tests | Lines covered | Coverage delta |
|-------|-----------|---------------|----------------|
| Phase 1 (Patrol) | 1-3 flows | 0 (integration, not lcov) | — |
| Phase 2 (gRPC spike) | 0-1 Maestro flow | 0 | — |
| Phase 3 (unit/widget) | ~20-30 | ~150-200 | +5-6% |
| **Total** | ~25-35 | ~150-200 | **~70-72%** |

## Issue Closure Criteria

**#51 — Patrol setup**: Closed when one flow runs green on local emulator and all flows compile.

**#52 — Audio injection**: Closed when either:
- (a) `scripts/inject-audio.py` works end-to-end with `speech_to_text` on emulator, OR
- (b) Spike fails and findings are documented on the issue with recommendation to close as won't-fix
