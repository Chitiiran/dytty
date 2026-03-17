# ADR-007: Emulator gRPC Audio Injection for Automated STT Testing

## Status
Accepted

## Context
We need automated voice input testing for STT flows (voice notes, daily call). Manual testing is the only option today — no way to inject audio into the emulator's virtual microphone in CI or local automation.

Five approaches were evaluated:

| Approach | Verdict | Why |
|----------|---------|-----|
| `adb emu audio` commands | Not feasible | Only toggles host mic pass-through, no file injection |
| Emulator `-audio-in` flag | Not feasible | Deprecated and removed from current emulator |
| `adb shell` tinymix/tinyplay | Not feasible | Emulator audio HAL is a stub, no ALSA routing |
| Maestro built-in | Not feasible | Zero audio/mic capabilities |
| **Emulator gRPC `injectAudio`** | **Feasible** | Official API, proto ships with SDK, headless-friendly |
| PulseAudio virtual mic (Linux) | Works but fragile | Requires PulseAudio daemon, OS-dependent, unnecessary given gRPC |

## Decision
Use the Android Emulator's gRPC `injectAudio` RPC to inject pre-recorded WAV files into the virtual microphone during automated tests.

**How it works:**
1. The emulator exposes `EmulatorController.injectAudio(stream AudioPacket)` via gRPC
2. A helper script reads a WAV file, chunks it into `AudioPacket` messages (16-bit PCM, mono, 16kHz)
3. The script streams packets to the emulator's gRPC endpoint at real-time pace
4. The app's `speech_to_text` / `record` package receives the audio as if from a real microphone

**Proto location:** `$ANDROID_SDK/emulator/lib/emulator_controller.proto` (confirmed present locally)

**Discovery:** Running emulator instances register their gRPC port at `$TMPDIR/avd/running/pid_<pid>.ini`

**Implementation:**
- Python script using `grpcio` + generated stubs from the proto file
- Callable from Maestro/Patrol flows via `runScript` or shell exec
- Test WAV files stored in `test/fixtures/audio/`

## Consequences

**Easier:**
- Automated STT testing in CI — no manual speech needed
- Deterministic test input — same audio file produces reproducible results
- Works headless on any OS (Windows, Linux, macOS) — no PulseAudio or audio hardware needed

**Harder:**
- Requires Python + `grpcio` in the test environment (CI and local)
- gRPC security token discovery adds setup complexity
- STT engine behavior may vary (on-device vs cloud recognition) — needs validation with `speech_to_text` package
- WAV files must match expected format (16-bit signed LE, mono)

**Risk:**
- If Google's on-device speech recognition bypasses the standard mic path, injected audio may not reach STT. This needs a proof-of-concept before committing to test flows. The spike in Phase 2 of PLAN-051-052 covers this.
