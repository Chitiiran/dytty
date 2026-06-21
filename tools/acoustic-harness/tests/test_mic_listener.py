#!/usr/bin/env python3
"""Tests for the mic-listening loop that drives the TurnDetector.

wait_for_ai_turn() reads audio frames from an injectable source (real mic
in production, a fake generator in tests), computes RMS per frame, feeds
the TurnDetector, and returns when the AI turn ends or a timeout hits.

The frame SOURCE is injected so these tests need no microphone.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np  # noqa: E402

from mic_listener import rms, wait_for_ai_turn  # noqa: E402


def test_rms_of_silence_is_near_zero():
    block = np.zeros(480, dtype=np.float32)
    assert rms(block) < 1e-6


def test_rms_of_loud_block_is_larger():
    quiet = np.full(480, 0.01, dtype=np.float32)
    loud = np.full(480, 0.2, dtype=np.float32)
    assert rms(loud) > rms(quiet)


def _block(level, n=480):
    return np.full(n, level, dtype=np.float32)


def test_wait_returns_done_when_ai_speaks_then_stops():
    """A source that goes loud then silent => returns reason 'ai_done'."""
    # 0.5s loud, then 1.5s silent, at 0.05s/frame => frames:
    frames = ([_block(0.2)] * 10) + ([_block(0.001)] * 30)
    source = iter(frames)

    reason = wait_for_ai_turn(
        source=lambda: next(source, None),
        frame_seconds=0.05,
        silence_floor=0.01,
        start_threshold=3.0,
        silence_hangover=1.0,
        min_speech=0.1,
        timeout=10.0,
    )
    assert reason == "ai_done"


def test_wait_times_out_if_ai_never_speaks():
    """Source stays silent => returns 'timeout' (AI never responded)."""
    source = iter([_block(0.001)] * 200)
    reason = wait_for_ai_turn(
        source=lambda: next(source, None),
        frame_seconds=0.05,
        silence_floor=0.01,
        start_threshold=3.0,
        silence_hangover=1.0,
        min_speech=0.1,
        timeout=1.0,  # 1s timeout, 0.05s frames => ~20 frames
    )
    assert reason == "timeout"


def test_wait_returns_done_even_with_a_midspeech_pause():
    """Loud, brief pause, loud again, then real silence => 'ai_done'."""
    frames = (
        [_block(0.2)] * 6     # 0.3s speaking
        + [_block(0.001)] * 8  # 0.4s pause (< 1.0 hangover)
        + [_block(0.2)] * 6    # resume 0.3s
        + [_block(0.001)] * 30  # 1.5s real silence
    )
    source = iter(frames)
    reason = wait_for_ai_turn(
        source=lambda: next(source, None),
        frame_seconds=0.05,
        silence_floor=0.01,
        start_threshold=3.0,
        silence_hangover=1.0,
        min_speech=0.1,
        timeout=10.0,
    )
    assert reason == "ai_done"


def test_source_exhaustion_returns_done_if_speaking_happened():
    """If the source ends after speech without full silence, don't hang;
    treat exhaustion as the turn being over."""
    frames = ([_block(0.2)] * 6) + ([_block(0.001)] * 3)  # ends mid-silence
    source = iter(frames)
    reason = wait_for_ai_turn(
        source=lambda: next(source, None),
        frame_seconds=0.05,
        silence_floor=0.01,
        start_threshold=3.0,
        silence_hangover=1.0,
        min_speech=0.1,
        timeout=10.0,
    )
    assert reason in ("ai_done", "source_ended")
