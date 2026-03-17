# Emulator gRPC Audio Injection — Research Notes

> Decision: ADR-007. Issue: #52.

## Problem
Automated STT testing requires injecting audio into the Android emulator's virtual microphone. Without this, voice note and daily call flows can only be tested manually.

## Approaches Evaluated

### 1. `adb emu audio` commands — NOT FEASIBLE
The emulator console (`adb emu` / telnet) has two audio commands:
- `adb emu avd hostmicon` — enables host mic pass-through
- `adb emu avd hostmicoff` — disables host mic (silence)

These toggle the host's physical microphone, not file injection. No `adb emu audio inject` or similar exists.

### 2. Emulator `-audio-in` flag — NOT FEASIBLE
The `-audio-in` and `-audio-out` CLI flags are deprecated and removed from current emulator builds. Only `-noaudio` survives. No replacement for file-based mic input.

### 3. `adb shell` tinymix/tinyplay — NOT FEASIBLE
The emulator's audio HAL is a virtual stub. `tinymix` and `tinyplay` require real ALSA hardware. No audio routing mechanism exists inside the emulator guest OS.

### 4. Maestro built-in — NOT FEASIBLE
Maestro has zero audio/microphone capabilities. Confirmed via GitHub Issues search on `mobile-dev-inc/maestro`.

### 5. PulseAudio virtual mic (Linux) — WORKS BUT FRAGILE
On Linux CI with PulseAudio:
```bash
pactl load-module module-pipe-source file=/tmp/virtual_mic source_name=virtual_mic
adb emu avd hostmicon
ffmpeg -i speech.wav -f s16le -ar 16000 -ac 1 /tmp/virtual_mic
```
Drawbacks: requires PulseAudio daemon in CI (finicky headless setup), OS-dependent, timing unreliable. Strictly inferior to gRPC.

### 6. Emulator gRPC `injectAudio` — FEASIBLE (chosen)
See details below.

## gRPC `injectAudio` API

### Proto Definition
Source: `$ANDROID_SDK/emulator/lib/emulator_controller.proto` (ships with SDK)

```protobuf
service EmulatorController {
    // Injects audio packets to the android microphone.
    // Audio stored in a 300ms buffer. Only one mic client at a time.
    // Errors:
    //   INVALID_ARGUMENT (3): sampling rate too high/low, or packet too large
    //   FAILED_PRECONDITION (9): microphone already registered
    rpc injectAudio(stream AudioPacket) returns (google.protobuf.Empty) {}
}

message AudioFormat {
    enum SampleFormat {
        AUD_FMT_U8 = 0;   // Unsigned 8 bit
        AUD_FMT_S16 = 1;  // Signed 16 bit (little endian)
    }
    enum Channels { Mono = 0; Stereo = 1; }
    enum DeliveryMode {
        MODE_UNSPECIFIED = 0;  // Blocks until emulator requests frames
        MODE_REAL_TIME = 1;    // Overwrites buffer (experimental)
    }
    uint64 samplingRate = 1;   // Default 44100, max 48000
    Channels channels = 2;
    SampleFormat format = 3;
    DeliveryMode mode = 4;
}

message AudioPacket {
    AudioFormat format = 1;
    uint64 timestamp = 2;      // Unix epoch in microseconds
    bytes audio = 3;           // Raw PCM samples
}
```

### Key Constraints
- **Buffer size**: 300ms — chunks should be ~300ms or smaller
- **Format first**: Only the first `AudioPacket.format` is honored; subsequent packets can omit it
- **Single client**: Only one `injectAudio` stream at a time (FAILED_PRECONDITION if already registered)
- **Max sample rate**: 48kHz (Android NDK limit)
- **Delivery modes**: `MODE_UNSPECIFIED` (blocking, paced by emulator) is simpler and more reliable than `MODE_REAL_TIME` (experimental, needs client-side timing)

### Emulator gRPC Discovery
Running emulators register in discovery files at:

| OS | Path |
|----|------|
| Windows | `%LOCALAPPDATA%\Temp\avd\running\pid_<PID>.ini` |
| Linux | `$XDG_RUNTIME_DIR/avd/running/pid_<PID>.ini` or `~/.android/avd/running/pid_<PID>.ini` |
| macOS | `~/Library/Caches/TemporaryItems/avd/running/pid_<PID>.ini` |

INI file format:
```ini
grpc.address=localhost:8554
grpc.token=abc123xyz
```

Connection: `grpc.address` is the endpoint, `grpc.token` is passed as `("emulator.security", "<token>")` metadata on every RPC call.

### Reference Implementation (AOSP)
Google's sample at `android-grpc/python/samples/src/audio/inject_audio.py`:
1. Uses `aemu.discovery.emulator_discovery.get_default_emulator()` to find the gRPC endpoint
2. Opens WAV with Python's `wave` module
3. Maps sample width to `SampleFormat` (1 byte → U8, 2 bytes → S16)
4. Reads in 300ms chunks: `chunk_size = int(frame_rate * 0.3) * frame_size`
5. Yields `AudioPacket(format=fmt, timestamp=epoch_us, audio=frames)`
6. Streams via `stub.injectAudio(audio_generator)`
7. Optional real-time pacing: `time.sleep(0.3)` between chunks

### Python Package
The `aemu-grpc` package on PyPI wraps the proto stubs and discovery. However, we can also generate stubs directly from the local proto file:
```bash
pip install grpcio grpcio-tools
python -m grpc_tools.protoc \
  --proto_path=$ANDROID_SDK/emulator/lib \
  --python_out=. --grpc_python_out=. \
  emulator_controller.proto
```

## Implementation Plan for Dytty

### Helper Script: `scripts/inject-audio.py`
```
Usage: python scripts/inject-audio.py <wav-file> [--realtime]
```
- Discovers running emulator via `pid_*.ini` files
- Reads WAV, chunks to 300ms, streams via `injectAudio`
- Default: `MODE_UNSPECIFIED` (blocking, reliable)
- `--realtime` flag: `MODE_REAL_TIME` + `time.sleep(0.3)` pacing

### Test WAV Files: `test/fixtures/audio/`
- `grateful-health.wav` — "I'm grateful for my health today" (5s, 16kHz, mono, 16-bit)
- `had-good-day.wav` — "I had a really good day" (3s)
- Generated with TTS or manually recorded, committed to repo

### Integration with Maestro
```yaml
# .maestro/voice/voice-input-flow.yaml
- runScript:
    script: python scripts/inject-audio.py test/fixtures/audio/grateful-health.wav
    wait: true
```

### CI Requirements
- Python 3.x + `grpcio` + `grpcio-tools` (pip install)
- Proto stubs generated as build step or committed
- Emulator must be running before script executes

## Spike Results (2026-03-17)

### Environment
- Emulator: Android SDK 35.5.10.0 (Pixel 9 AVD)
- Platform: Windows 10 (MSYS2/bash)
- Python: 3.12, grpcio 1.x
- Emulator launched with: `-avd Pixel_9 -no-window -grpc 8554 -grpc-use-token`

### Findings

**gRPC discovery**: Works. The `pid_*.ini` file at `%LOCALAPPDATA%\Temp\avd\running\` contains `grpc.port` (not `grpc.address`) and `grpc.token`. Fixed script to handle both key names.

**Authentication**: The emulator's `emulator_access.json` allowlist requires JWT for `injectAudio` when using default `-grpc-use-jwt` mode. Switching to `-grpc-use-token` exposes a simpler bearer token in the INI file. `getStatus` and other unary RPCs work fine with the token.

**injectAudio RPC**: **FAILS** — the streaming RPC consistently returns `StatusCode.UNAVAILABLE` with "Connection reset" (error 10054 on Windows). Tested with:
1. Single small packet (100ms, 16kHz mono S16)
2. Full 3-second WAV in 300ms chunks
3. With and without auth token
4. With and without `-no-audio` flag
5. Multiple emulator restarts

The emulator crashes or forcibly closes the connection when `injectAudio` is called. This appears to be a Windows-specific issue with the emulator's gRPC streaming implementation. The audio subsystem may not properly support the streaming RPC on Windows.

### Conclusion
**gRPC `injectAudio` is not viable on Windows** with the current emulator version (35.5.10.0). The script, proto stubs, and discovery mechanism are all correct and tested (12 Python unit tests pass), but the emulator's server-side implementation crashes on the streaming RPC.

**Recommendation**: Close #52. The infrastructure (`scripts/inject-audio.py`, proto stubs, test WAV files) is ready for re-testing on Linux CI or a future emulator version. If a Linux CI runner is available, the spike should be retried there — PulseAudio virtual mic is the backup approach for Linux-only.

## Open Risk
If the `speech_to_text` package or Google's on-device speech recognition service uses a private audio pipeline that bypasses the standard `AudioRecord` API, injected audio may not reach STT. This was not testable due to the emulator crash above.

The `record` package (used in daily call for raw PCM capture) should work since it uses standard `AudioRecord` — lower risk.
