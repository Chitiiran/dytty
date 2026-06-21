#!/usr/bin/env python3
"""Tests for the closed-loop AI-turn detector.

The detector consumes a stream of per-frame audio-energy readings (RMS)
from the laptop mic and decides when the AI has STARTED speaking and when
it has FINISHED (sustained silence). This lets the harness wait for the
AI's turn to end before playing the next utterance — true human-like
turn-taking, robust to the barge-in collisions that break logcat-marker
gating.

All logic here is pure (energy values + timestamps in, state out) so it
is tested without a microphone or device.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from turn_detector import TurnDetector, TurnState  # noqa: E402


# A frame is (timestamp_seconds, rms_energy). The detector is fed frames
# one at a time and reports its current state.


def _feed(detector, frames):
    """Feed (t, rms) frames; return the state after the last frame."""
    state = None
    for t, rms in frames:
        state = detector.process_frame(t, rms)
    return state


def test_starts_in_waiting_state():
    """Before any speech, the detector waits for the AI to start."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0)
    assert d.state == TurnState.WAITING_FOR_SPEECH


def test_detects_ai_started_speaking_when_energy_rises():
    """Energy sustained above start_threshold * floor => AI is speaking."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0, min_speech=0.1)
    # floor=0.01, threshold 3x => 0.03. Feed loud frames over 0.15s.
    state = _feed(d, [
        (0.00, 0.05),
        (0.05, 0.06),
        (0.10, 0.05),
        (0.15, 0.06),
    ])
    assert state == TurnState.AI_SPEAKING


def test_brief_blip_does_not_count_as_speech():
    """A single loud frame shorter than min_speech is ignored (noise)."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0, min_speech=0.2)
    state = _feed(d, [
        (0.00, 0.005),
        (0.05, 0.05),   # one loud blip (< min_speech 0.2s)
        (0.10, 0.004),
        (0.15, 0.005),
    ])
    assert state == TurnState.WAITING_FOR_SPEECH


def test_detects_ai_done_after_sustained_silence():
    """After speaking, silence for >= hangover => AI turn done."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0, min_speech=0.1)
    # Speak for 0.2s, then go quiet for 1.1s (> 1.0 hangover).
    frames = [
        (0.00, 0.05), (0.05, 0.06), (0.10, 0.05), (0.20, 0.05),
        # silence begins at 0.25
        (0.25, 0.005), (0.50, 0.004), (0.75, 0.005),
        (1.00, 0.004), (1.30, 0.005),  # 1.05s of silence since 0.25
    ]
    state = _feed(d, frames)
    assert state == TurnState.AI_DONE


def test_silence_shorter_than_hangover_stays_speaking():
    """A short pause mid-utterance must NOT end the turn prematurely."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0, min_speech=0.1)
    frames = [
        (0.00, 0.05), (0.05, 0.06), (0.10, 0.05),
        # short 0.4s pause (< 1.0 hangover)
        (0.20, 0.004), (0.40, 0.005),
        # speaking resumes
        (0.60, 0.05), (0.70, 0.06),
    ]
    state = _feed(d, frames)
    assert state == TurnState.AI_SPEAKING


def test_resumed_speech_resets_silence_timer():
    """Speech after a short pause resets the hangover; turn not done."""
    d = TurnDetector(silence_floor=0.01, start_threshold=3.0,
                     silence_hangover=1.0, min_speech=0.1)
    frames = [
        (0.00, 0.05), (0.10, 0.06),         # speaking
        (0.20, 0.004), (0.60, 0.005),       # 0.4s pause
        (0.70, 0.05),                        # resume -> resets timer
        (0.80, 0.004), (1.10, 0.005),       # only 0.4s silence again
    ]
    state = _feed(d, frames)
    assert state == TurnState.AI_SPEAKING


def test_calibrate_floor_from_room_tone():
    """Floor calibration takes a robust statistic of quiet frames."""
    # Given room-tone RMS samples, the calibrated floor should sit at/above
    # the bulk of them so normal noise doesn't trip start_threshold.
    samples = [0.008, 0.010, 0.009, 0.011, 0.050]  # last is a stray blip
    floor = TurnDetector.calibrate_floor(samples)
    # Robust to the outlier: floor near the median band, not the max.
    assert 0.008 <= floor <= 0.02
