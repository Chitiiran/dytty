# Acoustic Test Harness

App-agnostic voice testing toolchain for mobile apps. Generates TTS audio, plays it through laptop speakers to a physical phone's microphone, and verifies results via ADB logcat.

## How It Works

```
Laptop                              Phone
┌──────────┐   audio over air/aux   ┌──────────┐
│ play.py  │ ──── speaker ))))  ──→ │   mic    │
│          │                        │   ↓      │
│          │         ADB USB        │ STT/LLM  │
│ logcat   │ ◄───────────────────── │ [TAG]    │
│ monitor  │   logcat stream        │ log lines│
└──────────┘                        └──────────┘
```

## Setup

```bash
# Clone
git clone <repo-url> /path/to/acoustic-test-harness

# Set environment variables
export ACOUSTIC_HARNESS_HOME="/path/to/acoustic-test-harness"
export ACOUSTIC_TAG="MYAPP"  # Your app's logcat tag

# Install dependencies
pip install -r $ACOUSTIC_HARNESS_HOME/requirements.txt
```

## Scripts

### generate.py — TTS Audio Generation

Reads a test-scripts JSON file and generates WAV files via Kokoro TTS.

```bash
# Generate WAVs
python $ACOUSTIC_HARNESS_HOME/generate.py \
  --scripts test/fixtures/audio/test-scripts.json \
  --output test/fixtures/audio/generated/

# List scenarios without generating
python $ACOUSTIC_HARNESS_HOME/generate.py \
  --scripts test/fixtures/audio/test-scripts.json \
  --list

# Force regeneration with different voice
python $ACOUSTIC_HARNESS_HOME/generate.py \
  --scripts test/fixtures/audio/test-scripts.json \
  --output test/fixtures/audio/generated/ \
  --force --voice af_bella --speed 0.9
```

### play.py — Audio Playback + Logcat Monitor

Plays a WAV through laptop speakers and monitors ADB logcat for a signal.

```bash
python $ACOUSTIC_HARNESS_HOME/play.py \
  --wav test/fixtures/audio/generated/basic-call-liveness_0.wav \
  --wait-for "Turn complete" \
  --tag MYAPP \
  --timeout 10

# With logging and pre-play delay
python $ACOUSTIC_HARNESS_HOME/play.py \
  --wav audio.wav \
  --wait-for "User said" \
  --timeout 15 \
  --delay 2.0 \
  --log session.log

# Dry run (skip audio, test logcat monitor only)
python $ACOUSTIC_HARNESS_HOME/play.py \
  --wav audio.wav \
  --wait-for "Turn complete" \
  --dry-run
```

Exit codes: 0 = signal found, 1 = timeout, 2 = error.

### verify.py — Logcat Verification

Parses a logcat session log and checks results against scenario expectations.

```bash
python $ACOUSTIC_HARNESS_HOME/verify.py \
  --log session.log \
  --scenario basic-call-liveness \
  --scripts test/fixtures/audio/test-scripts.json \
  --tag MYAPP

# JSON output for CI
python $ACOUSTIC_HARNESS_HOME/verify.py \
  --log session.log \
  --scenario basic-call-liveness \
  --scripts test/fixtures/audio/test-scripts.json \
  --tag MYAPP \
  --json
```

Checks: call connected, user transcript (fuzzy match >80%), AI responded, tool calls, clean shutdown, no errors.

## Integration Guide

### 1. Add debug logs to your app

Add tagged `debugPrint` lines to your voice service:

```dart
static const _logTag = '[MYAPP]';
static void _log(String msg) => debugPrint('$_logTag $msg');

// Log state changes
_log('Call state: ${state.name}');

// Log transcripts
_log('User said: $text (final: $isFinal)');
_log('AI said: $text (final: $isFinal)');

// Log turn completion
_log('Turn complete');
```

### 2. Create test-scripts.json

```json
{
  "scenarios": [
    {
      "name": "basic-call",
      "description": "Verify call connects and AI responds",
      "path": "call",
      "utterances": [
        {
          "text": "Hey, how are you?",
          "expect": {
            "ai_responds": true,
            "timeout_sec": 10
          }
        }
      ]
    }
  ]
}
```

### 3. Write Maestro shell wrappers

Create thin shell scripts that bridge Maestro `runScript` to the harness:

```bash
#!/usr/bin/env bash
# maestro-play.sh
set -euo pipefail

if [ -z "$ACOUSTIC_HARNESS_HOME" ]; then
  echo "ERROR: ACOUSTIC_HARNESS_HOME not set" >&2
  exit 2
fi

python "$ACOUSTIC_HARNESS_HOME/play.py" \
  --wav "$WAV_PATH" \
  --wait-for "${WAIT_FOR}" \
  --timeout "${TIMEOUT:-10}"
```

### 4. Write Maestro flows

```yaml
- runScript:
    file: "../../scripts/voice-test/maestro-play.sh"
    env:
      WAV: "basic-call_0.wav"
      WAIT_FOR: "Turn complete"
      TIMEOUT: "10"
```

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `ACOUSTIC_HARNESS_HOME` | Path to this repo | Yes (for consuming apps) |
| `ACOUSTIC_TAG` | Default logcat tag | No (can use `--tag` flag instead) |

## Running Tests

```bash
cd $ACOUSTIC_HARNESS_HOME
python -m unittest discover -s tests -p "test_*.py" -v
```

## Requirements

- Python 3.11+
- ADB in PATH (for play.py and logcat monitoring)
- Physical Android device connected via USB
- Audio output device (laptop speakers or aux cable to phone)
