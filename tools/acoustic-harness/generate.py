#!/usr/bin/env python3
"""Generate WAV files from a test-scripts JSON file using Kokoro TTS.

Usage:
    python generate.py --scripts <path> --output <dir> [--force] [--list]
    python generate.py --scripts <path> --list

Options:
    --scripts PATH  Path to test-scripts.json (required)
    --output DIR    Output directory for generated WAVs (required unless --list)
    --force         Regenerate all WAVs even if they already exist
    --list          List scenarios and exit without generating
    --voice VOICE   Kokoro voice preset (default: af_heart)
    --speed SPEED   Speech speed multiplier (default: 1.0)

Output:
    <output-dir>/<scenario-name>_<index>.wav

Voices (American English): af_heart (A), af_bella (A-), af_nicole (B-),
    af_nova (C), am_fenrir (C+), am_michael (C+), am_puck (C+)
"""

import argparse
import hashlib
import json
import os
import sys


def _load_hashes(hash_file: str) -> dict[str, str]:
    """Load previously generated file hashes for change detection."""
    if os.path.exists(hash_file):
        with open(hash_file, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def _save_hashes(hashes: dict[str, str], hash_file: str) -> None:
    """Persist file hashes for future change detection."""
    with open(hash_file, "w", encoding="utf-8") as f:
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
    scripts_path: str,
    output_dir: str,
    force: bool = False,
    voice: str = "af_heart",
    speed: float = 1.0,
) -> None:
    """Read test-scripts JSON and generate WAV files via Kokoro TTS."""
    # Lazy imports so --help and --list work without torch installed
    import numpy as np
    import soundfile as sf
    from kokoro import KPipeline

    with open(scripts_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    os.makedirs(output_dir, exist_ok=True)

    hash_file = os.path.join(output_dir, ".hashes.json")
    hashes = _load_hashes(hash_file)
    pipeline = KPipeline(lang_code="a")  # American English
    generated = 0
    skipped = 0
    up_to_date = 0

    for scenario in data["scenarios"]:
        name = scenario["name"]
        for i, utterance in enumerate(scenario["utterances"]):
            filename = f"{name}_{i}.wav"
            filepath = os.path.join(output_dir, filename)
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

            # Append 1.5s silence so STT can finalize the last word.
            # Without this, the audio ends abruptly and STT clips
            # the final word before it can be recognized.
            silence = np.zeros(int(24000 * 1.5), dtype=full_audio.dtype)
            full_audio = np.concatenate([full_audio, silence])

            # Kokoro outputs at 24kHz
            sf.write(filepath, full_audio, 24000)
            hashes[filename] = content_hash
            generated += 1

    _save_hashes(hashes, hash_file)

    print()
    print(f"Done: {generated} generated, {up_to_date} up-to-date, {skipped} skipped")
    print(f"Output: {output_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate test WAV files from test-scripts JSON using Kokoro TTS"
    )
    parser.add_argument(
        "--scripts", required=True, help="Path to test-scripts.json"
    )
    parser.add_argument(
        "--output", help="Output directory for generated WAVs"
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

    if not os.path.exists(args.scripts):
        print(f"ERROR: Scripts file not found: {args.scripts}")
        sys.exit(2)

    with open(args.scripts, "r", encoding="utf-8") as f:
        data = json.load(f)

    if args.list:
        print("=== Voice test scenarios ===\n")
        list_scenarios(data)
        return

    if not args.output:
        print("ERROR: --output is required when not using --list")
        sys.exit(2)

    print("=== Generating voice test audio ===")
    print(f"Source: {args.scripts}")
    print(f"Voice:  {args.voice}  Speed: {args.speed}")
    print()
    generate_wavs(
        scripts_path=args.scripts,
        output_dir=args.output,
        force=args.force,
        voice=args.voice,
        speed=args.speed,
    )


if __name__ == "__main__":
    main()
