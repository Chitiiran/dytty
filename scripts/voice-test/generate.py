#!/usr/bin/env python3
"""Generate WAV files from test-scripts.json using Kokoro TTS.

Usage:
    python scripts/voice-test/generate.py [--force] [--list] [--voice VOICE] [--speed SPEED]

Options:
    --force        Regenerate all WAVs even if they already exist
    --list         List scenarios and exit without generating
    --voice VOICE  Kokoro voice preset (default: af_heart)
    --speed SPEED  Speech speed multiplier (default: 1.0)

Output:
    test/fixtures/audio/generated/<scenario>_<index>.wav

Voices (American English): af_heart (A), af_bella (A-), af_nicole (B-),
    af_nova (C), am_fenrir (C+), am_michael (C+), am_puck (C+)
"""

import argparse
import hashlib
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
SCRIPTS_JSON = os.path.join(
    PROJECT_DIR, "test", "fixtures", "audio", "test-scripts.json"
)
OUTPUT_DIR = os.path.join(PROJECT_DIR, "test", "fixtures", "audio", "generated")
HASH_FILE = os.path.join(OUTPUT_DIR, ".hashes.json")


def _load_hashes() -> dict[str, str]:
    """Load previously generated file hashes for change detection."""
    if os.path.exists(HASH_FILE):
        with open(HASH_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def _save_hashes(hashes: dict[str, str]) -> None:
    """Persist file hashes for future change detection."""
    with open(HASH_FILE, "w", encoding="utf-8") as f:
        json.dump(hashes, f, indent=2)


def _content_hash(text: str, voice: str, speed: float) -> str:
    """Hash the inputs that determine the WAV output."""
    key = f"{text}|{voice}|{speed}"
    return hashlib.sha256(key.encode()).hexdigest()[:16]


def list_scenarios(data: dict) -> None:
    """Print all scenarios and their utterances."""
    for scenario in data["scenarios"]:
        name = scenario["name"]
        path = scenario["path"]
        desc = scenario["description"]
        count = len(scenario["utterances"])
        print(f"  {name} ({path}, {count} utterance{'s' if count != 1 else ''})")
        print(f"    {desc}")
        for i, u in enumerate(scenario["utterances"]):
            filename = f"{name}_{i}.wav"
            print(f"    [{i}] \"{u['text']}\" -> {filename}")
        print()


def generate_wavs(
    force: bool = False, voice: str = "af_heart", speed: float = 1.0
) -> None:
    """Read test-scripts.json and generate WAV files via Kokoro TTS."""
    # Lazy imports so --help and --list work without torch installed
    import numpy as np
    import soundfile as sf
    from kokoro import KPipeline

    with open(SCRIPTS_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    hashes = _load_hashes()
    pipeline = KPipeline(lang_code="a")  # American English
    generated = 0
    skipped = 0
    up_to_date = 0

    for scenario in data["scenarios"]:
        name = scenario["name"]
        for i, utterance in enumerate(scenario["utterances"]):
            filename = f"{name}_{i}.wav"
            filepath = os.path.join(OUTPUT_DIR, filename)
            text = utterance["text"]
            content_hash = _content_hash(text, voice, speed)

            # Skip if file exists and content hasn't changed
            if os.path.exists(filepath) and not force:
                if hashes.get(filename) == content_hash:
                    up_to_date += 1
                    continue
                else:
                    print(f"  REGEN: {filename} (content changed)")
            elif os.path.exists(filepath) and force:
                print(f"  FORCE: {filename}")
            else:
                print(f"  GEN:   {filename} <- \"{text}\"")

            # Kokoro returns generator of (graphemes, phonemes, audio) tuples
            audio_segments = []
            for _gs, _ps, audio in pipeline(text, voice=voice, speed=speed):
                audio_segments.append(audio)

            if not audio_segments:
                print(f"  ERROR: No audio generated for {filename}")
                sys.exit(1)

            full_audio = np.concatenate(audio_segments)

            # Kokoro outputs at 24kHz
            sf.write(filepath, full_audio, 24000)
            hashes[filename] = content_hash
            generated += 1

    _save_hashes(hashes)

    print()
    print(f"Done: {generated} generated, {up_to_date} up-to-date, {skipped} skipped")
    print(f"Output: {OUTPUT_DIR}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate test WAV files from test-scripts.json using Kokoro TTS"
    )
    parser.add_argument(
        "--force", action="store_true", help="Regenerate all WAVs even if they exist"
    )
    parser.add_argument(
        "--list", action="store_true", help="List scenarios and exit"
    )
    parser.add_argument(
        "--voice",
        default="af_heart",
        help="Kokoro voice preset (default: af_heart)",
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=1.0,
        help="Speech speed multiplier (default: 1.0)",
    )
    args = parser.parse_args()

    with open(SCRIPTS_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    if args.list:
        print("=== Voice test scenarios ===\n")
        list_scenarios(data)
        return

    print("=== Generating voice test audio ===")
    print(f"Source: {SCRIPTS_JSON}")
    print(f"Voice:  {args.voice}  Speed: {args.speed}")
    print()
    generate_wavs(force=args.force, voice=args.voice, speed=args.speed)


if __name__ == "__main__":
    main()
