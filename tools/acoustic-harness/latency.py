#!/usr/bin/env python3
"""Measure true conversational latency from a daily-call session log (#223).

The in-app stopwatch (gemini_live_service.dart) starts on the user's FIRST mic
chunk and stops on the AI's first audio chunk — so it includes the entire user
utterance plus Gemini's server-side VAD silence wait. That is NOT latency by any
industry definition; it's "total wall-clock the user waits, including their own
talking."

The correct, comparable metric is end-of-user-speech -> first-AI-audio. Both
events are timestamped on the device's single logcat clock, so no cross-device
synchronization is needed (unlike measuring the laptop's playback clock).

This analyzer parses a `[DYTTY]`-tagged session log and reports, per turn:
  user_last_ms       — timestamp of the user's last "User said" before the response
  ai_first_audio_ms  — timestamp of the AI's first "Audio chunk received"
  latency_ms         — ai_first_audio_ms - user_last_ms  (the real number)

Usage:
    python latency.py --log session.log
    python latency.py --log session.log --json
"""

import argparse
import json
import re
import sys

# 06-15 17:50:44.816 I/flutter ( 7245): [DYTTY] User said: ...
_LINE = re.compile(
    r"^(?P<ts>\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\b.*\[DYTTY\] (?P<msg>.*)$"
)
_TS = re.compile(r"\d{2}-\d{2} (\d{2}):(\d{2}):(\d{2})\.(\d{3})")


def parse_timestamp(ts: str) -> int:
    """Logcat 'MM-DD HH:MM:SS.mmm' -> milliseconds within the day.

    Day rollover is not handled (a single call never spans midnight).
    """
    m = _TS.search(ts)
    if not m:
        raise ValueError(f"unparseable timestamp: {ts!r}")
    h, mi, s, ms = (int(g) for g in m.groups())
    return ((h * 60 + mi) * 60 + s) * 1000 + ms


def _events(log_path: str):
    """Yield (timestamp_ms, message) for every [DYTTY] line, in order."""
    with open(log_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = _LINE.match(line.strip())
            if m:
                yield parse_timestamp(m.group("ts")), m.group("msg")


def analyze_turns(log_path: str) -> list[dict]:
    """Compute per-turn end-of-speech -> first-AI-audio latency.

    A turn = a run of "User said" lines followed by the first "Audio chunk
    received". The user's last "User said" before that chunk is end-of-speech.
    """
    turns = []
    last_user_ms = None
    measuring = False  # have we seen user speech since the last AI audio?

    for ts, msg in _events(log_path):
        if msg.startswith("User said"):
            last_user_ms = ts
            measuring = True
        elif msg.startswith("Audio chunk received") and measuring and last_user_ms is not None:
            turns.append(
                {
                    "user_last_ms": last_user_ms,
                    "ai_first_audio_ms": ts,
                    "latency_ms": ts - last_user_ms,
                }
            )
            measuring = False  # wait for the next user turn before measuring again

    return turns


def summarize(turns: list[dict]) -> dict:
    """Aggregate stats over all turns."""
    if not turns:
        return {"turns": 0}
    lat = sorted(t["latency_ms"] for t in turns)
    n = len(lat)
    return {
        "turns": n,
        "min_ms": lat[0],
        "max_ms": lat[-1],
        "median_ms": lat[n // 2],
        "mean_ms": round(sum(lat) / n),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", required=True, help="Path to the session log")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    args = parser.parse_args()

    turns = analyze_turns(args.log)
    stats = summarize(turns)

    if args.json:
        print(json.dumps({"turns": turns, "summary": stats}, indent=2))
        return

    print("=== Daily-call latency (end-of-speech -> first-AI-audio) ===\n")
    for i, t in enumerate(turns, 1):
        print(f"  turn {i}: {t['latency_ms']} ms")
    print()
    if stats["turns"]:
        print(
            f"  {stats['turns']} turns | "
            f"median {stats['median_ms']} ms | "
            f"mean {stats['mean_ms']} ms | "
            f"min {stats['min_ms']} | max {stats['max_ms']}"
        )
    else:
        print("  no complete turns found in log")
    sys.exit(0)


if __name__ == "__main__":
    main()
