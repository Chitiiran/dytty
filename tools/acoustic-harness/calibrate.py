#!/usr/bin/env python3
"""Audio-environment calibration for the acoustic test harness.

Answers "is the speaker→mic chain healthy?" BEFORE a test run produces
mystery failures (owner finding 2026-06-11: a mid-session speaker swap
silently degraded STT pickup and burned a full sweep).

Two checks:

  Loopback (laptop side)
      Plays the 1 kHz reference tone through the default output while
      recording the laptop microphone. Reports RMS level, play→heard
      onset latency, and run-to-run spread over --runs repetitions.

  Phone chain (phone side)
      The phone's microphone has no direct capture path over adb; the
      metric that matters to the tests is what the SpeechRecognizer
      hears. Score the [TAG] transcript from a normal orchestrated run
      against the scenario script with word_error_rate() — see
      orchestrate.py integration in the consuming app.

Usage:
  python calibrate.py --tone path/to/test-tone-1khz.wav --runs 3
  python calibrate.py --tone tone.wav --min-dbfs -45 --max-latency-ms 800
"""

import argparse
import math
import statistics
import sys


def rms_dbfs(samples) -> float:
    """RMS level in dBFS for float samples in [-1, 1]. Floor: -120."""
    if len(samples) == 0:
        return -120.0
    mean_sq = sum(s * s for s in samples) / len(samples)
    if mean_sq <= 1e-12:
        return -120.0
    return 20.0 * math.log10(math.sqrt(mean_sq))


def detect_onset_seconds(samples, samplerate, threshold_dbfs=-30.0,
                         window_seconds=0.02):
    """First time (s) a sliding window exceeds threshold; None if never."""
    win = max(1, int(window_seconds * samplerate))
    threshold_mean_sq = 10.0 ** (threshold_dbfs / 10.0)
    acc = 0.0
    for i, s in enumerate(samples):
        acc += s * s
        if i >= win:
            j = i - win
            acc -= samples[j] * samples[j]
        if i >= win - 1 and acc / win >= threshold_mean_sq:
            return (i - win + 1) / samplerate
    return None


def _normalize_words(text: str):
    cleaned = "".join(c.lower() if c.isalnum() or c.isspace() else " "
                      for c in text)
    return cleaned.split()


def word_error_rate(reference: str, hypothesis: str) -> float:
    """Levenshtein distance over words / reference length. 0.0 = perfect."""
    ref = _normalize_words(reference)
    hyp = _normalize_words(hypothesis)
    if not ref:
        return 0.0 if not hyp else 1.0
    prev = list(range(len(hyp) + 1))
    for i, rw in enumerate(ref, 1):
        cur = [i] + [0] * len(hyp)
        for j, hw in enumerate(hyp, 1):
            cur[j] = min(
                prev[j] + 1,                      # deletion
                cur[j - 1] + 1,                   # insertion
                prev[j - 1] + (0 if rw == hw else 1),  # substitution
            )
        prev = cur
    return prev[len(hyp)] / len(ref)


def summarize_runs(values) -> dict:
    """Mean/min/max/stdev for repeatability reporting."""
    return {
        "mean": statistics.fmean(values),
        "min": min(values),
        "max": max(values),
        "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
    }


def _loopback_once(tone_path: str, record_seconds: float):
    """Play the tone while recording the default input. Returns
    (level_dbfs, onset_seconds | None).

    Uses sd.playrec — sounddevice's high-level play()/rec() share one
    global stream, so a play() after rec() silently CANCELS the
    recording (observed: -120 dBFS "silence" on a working mic).
    """
    import sounddevice as sd
    import soundfile as sf

    data, rate = sf.read(tone_path)
    if data.ndim > 1:
        data = data[:, 0]
    frames = int(record_seconds * rate)
    if len(data) < frames:  # pad so we record past the tone's end
        import numpy as np

        data = np.concatenate([data, np.zeros(frames - len(data))])
    recording = sd.playrec(data[:frames], samplerate=rate, channels=1)
    sd.wait()
    flat = [row[0] if hasattr(row, "__len__") else row for row in recording]
    level = rms_dbfs(flat)
    # Adaptive onset threshold: tone windows must stand 3 dB above the
    # recording's own average — absolute thresholds break across rooms,
    # speakers and mic gains. The --min-dbfs gate separately rejects
    # too-quiet environments.
    onset = detect_onset_seconds(flat, rate, threshold_dbfs=level + 3.0)
    return level, onset


def main() -> None:
    parser = argparse.ArgumentParser(description="Calibrate speaker/mic chain")
    parser.add_argument("--tone", required=True, help="Reference tone WAV")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--min-dbfs", type=float, default=-45.0,
                        help="Fail if recorded level is below this")
    parser.add_argument("--max-latency-ms", type=float, default=1000.0,
                        help="Fail if play->heard onset exceeds this")
    parser.add_argument("--record-seconds", type=float, default=3.0)
    args = parser.parse_args()

    levels, latencies = [], []
    for n in range(args.runs):
        level, onset = _loopback_once(args.tone, args.record_seconds)
        if level < args.min_dbfs:
            print(f"  run {n + 1}: level {level:.1f} dBFS")
            print(f"CALIBRATION FAIL: level below {args.min_dbfs} dBFS — "
                  "speaker too quiet, too far, or mic muted")
            sys.exit(1)
        if onset is None:
            print(f"  run {n + 1}: level {level:.1f} dBFS, NO ONSET DETECTED")
            print("CALIBRATION FAIL: no distinct tone onset — "
                  "constant noise or speaker not playing")
            sys.exit(1)
        latency_ms = onset * 1000.0
        levels.append(level)
        latencies.append(latency_ms)
        print(f"  run {n + 1}: level {level:.1f} dBFS, "
              f"onset {latency_ms:.0f} ms")

    lv, lt = summarize_runs(levels), summarize_runs(latencies)
    print(f"  level: mean {lv['mean']:.1f} dBFS "
          f"(min {lv['min']:.1f}, max {lv['max']:.1f}, ±{lv['stdev']:.1f})")
    print(f"  latency: mean {lt['mean']:.0f} ms "
          f"(min {lt['min']:.0f}, max {lt['max']:.0f}, ±{lt['stdev']:.1f})")

    if lv["mean"] < args.min_dbfs:
        print(f"CALIBRATION FAIL: level {lv['mean']:.1f} dBFS "
              f"< {args.min_dbfs} — speaker too quiet or mic muted")
        sys.exit(1)
    if lt["mean"] > args.max_latency_ms:
        print(f"CALIBRATION FAIL: latency {lt['mean']:.0f} ms "
              f"> {args.max_latency_ms:.0f}")
        sys.exit(1)
    print("CALIBRATION PASS")


if __name__ == "__main__":
    main()
