#!/usr/bin/env python3
"""Play a WAV file through laptop speakers and monitor ADB logcat for a signal.

Usage:
    python scripts/voice-test/play.py --wav <path> --wait-for "Turn complete" --timeout 10
    python scripts/voice-test/play.py --wav <path> --wait-for "User said" --timeout 10 --log session.log

Exit codes:
    0 — Signal found in logcat within timeout
    1 — Timeout reached without signal
    2 — Error (file not found, ADB not available, etc.)
"""

import argparse
import os
import subprocess
import sys
import threading
import time


def play_wav(wav_path: str) -> None:
    """Play a WAV file through the default audio output device."""
    import sounddevice as sd
    import soundfile as sf

    data, samplerate = sf.read(wav_path)
    sd.play(data, samplerate)
    sd.wait()  # Block until playback finishes


def monitor_logcat(
    signal: str,
    timeout: float,
    result: dict,
    log_path: str | None = None,
) -> None:
    """Watch ADB logcat for a specific signal string.

    Runs `adb logcat` filtering for Flutter output and scans each line
    for the [DYTTY] tag + signal. Optionally appends all matched lines
    to a log file.
    """
    try:
        proc = subprocess.Popen(
            ["adb", "logcat", "-v", "time", "flutter:V", "*:S"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,  # Line-buffered for responsive signal detection
        )
    except FileNotFoundError:
        result["error"] = "ADB not found in PATH"
        return

    log_file = None
    if log_path:
        log_file = open(log_path, "a", encoding="utf-8")

    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            if proc.stdout is None:
                break
            # Non-blocking read with deadline check
            line = proc.stdout.readline()
            if not line:
                if proc.poll() is not None:
                    result["error"] = "ADB process exited unexpectedly"
                    return
                continue

            # Log all [DYTTY] lines
            if "[DYTTY]" in line:
                stripped = line.strip()
                if log_file:
                    log_file.write(stripped + "\n")
                    log_file.flush()

                if signal in stripped:
                    result["found"] = True
                    result["line"] = stripped
                    return
    finally:
        if log_file:
            log_file.close()
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()

    result["found"] = False


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Play WAV through speakers and wait for logcat signal"
    )
    parser.add_argument("--wav", required=True, help="Path to WAV file")
    parser.add_argument(
        "--wait-for",
        required=True,
        help="Signal string to watch for in [DYTTY] logcat lines",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=10,
        help="Timeout in seconds (default: 10)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Delay in seconds before playing audio (default: 1.0)",
    )
    parser.add_argument(
        "--log",
        default=None,
        help="Append [DYTTY] logcat lines to this file",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Skip audio playback (for testing the logcat monitor)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.wav):
        print(f"ERROR: WAV file not found: {args.wav}")
        sys.exit(2)

    # Start logcat monitor in background thread
    result: dict = {"found": False, "error": None, "line": None}
    monitor_thread = threading.Thread(
        target=monitor_logcat,
        args=(args.wait_for, args.timeout, result),
        kwargs={"log_path": args.log},
        daemon=True,
    )
    monitor_thread.start()

    # Brief delay to let the app's mic start listening
    if args.delay > 0:
        print(f"Waiting {args.delay}s for mic to be ready...")
        time.sleep(args.delay)

    # Play audio
    if args.dry_run:
        print(f"DRY RUN: Would play {args.wav}")
    else:
        print(f"Playing: {args.wav}")
        play_wav(args.wav)

    # Wait for monitor to finish (remaining timeout)
    monitor_thread.join(timeout=max(args.timeout, 1))

    if result.get("error"):
        print(f"ERROR: {result['error']}")
        sys.exit(2)
    elif result.get("found"):
        print(f"SIGNAL FOUND: {result['line']}")
        sys.exit(0)
    else:
        print(f"TIMEOUT: '{args.wait_for}' not found within {args.timeout}s")
        sys.exit(1)


if __name__ == "__main__":
    main()
