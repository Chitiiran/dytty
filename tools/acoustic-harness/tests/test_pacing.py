#!/usr/bin/env python3
"""Tests for human-pacing of TTS audio.

Flat Kokoro output reads like a narrator and, played back-to-back, talks
over the AI. plan_pacing() turns one turn's text into a sequence of
(segment_text, pause_after_seconds) so we render each segment separately
and concatenate them with silence gaps — adding the breaths and beats a
grieving person actually uses — plus a trailing gap so the AI has room to
respond before the next turn.

build_silence() makes the gap samples. Both are pure and need no TTS.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np  # noqa: E402

from pacing import build_silence, normalize_peak, plan_pacing  # noqa: E402


def test_splits_on_sentence_boundaries():
    text = "I lost him. It was hard. I miss him."
    segments = plan_pacing(text)
    spoken = [s.text for s in segments]
    assert spoken == ["I lost him.", "It was hard.", "I miss him."]


def test_each_sentence_gets_a_pause_after():
    text = "I lost him. It was hard."
    segments = plan_pacing(text, sentence_pause=0.6)
    assert all(s.pause_after >= 0.6 for s in segments[:-1])


def test_last_segment_gets_trailing_gap_for_ai():
    """The final segment's pause is the (larger) end-of-turn gap so the
    AI has room to respond before the next utterance plays."""
    text = "I lost him. It was hard."
    segments = plan_pacing(text, sentence_pause=0.6, end_gap=2.5)
    assert segments[-1].pause_after >= 2.5
    assert segments[-1].pause_after > segments[0].pause_after


def test_ellipsis_adds_extra_hesitation_pause():
    """'...' is a hesitation beat — it gets a longer pause than a period."""
    text = "I was... I was not ready."
    segments = plan_pacing(text, sentence_pause=0.5, ellipsis_pause=1.0)
    # The segment ending in the ellipsis pauses longer than a plain period.
    ellipsis_seg = next(s for s in segments if s.text.endswith("..."))
    assert ellipsis_seg.pause_after >= 1.0


def test_handles_comma_phrasing_within_long_sentence():
    """Very long sentences are broken at commas so there are breath beats
    inside them, not one breathless run."""
    text = ("He taught me to ride, to spit, to laugh with my whole body.")
    segments = plan_pacing(text, comma_pause=0.25, split_long_commas=True)
    # More than one segment => internal breaths exist.
    assert len(segments) > 1


def test_build_silence_length_matches_seconds():
    sr = 24000
    block = build_silence(1.5, samplerate=sr)
    assert isinstance(block, np.ndarray)
    assert abs(len(block) - int(1.5 * sr)) <= 1


def test_build_silence_is_silent():
    block = build_silence(0.5, samplerate=24000)
    assert float(np.max(np.abs(block))) == 0.0


def test_no_empty_segments():
    text = "I lost him.   It was hard.  "
    segments = plan_pacing(text)
    assert all(s.text.strip() for s in segments)


def test_normalize_peak_raises_quiet_audio_to_target():
    """Quiet audio (peak ~0.5) is scaled up so its peak hits the target —
    louder, clearer over-air for STT, without clipping."""
    quiet = np.array([0.0, 0.5, -0.25, 0.5], dtype=np.float32)
    out = normalize_peak(quiet, target=0.95)
    assert abs(float(np.max(np.abs(out))) - 0.95) < 1e-4
    # shape/relative structure preserved
    assert out.shape == quiet.shape
    assert out[1] > 0 and out[2] < 0


def test_normalize_peak_handles_silence_without_dividing_by_zero():
    silent = np.zeros(10, dtype=np.float32)
    out = normalize_peak(silent, target=0.95)
    assert float(np.max(np.abs(out))) == 0.0


def test_normalize_peak_never_exceeds_target():
    """Already-loud audio is scaled DOWN to the target, never clipped above."""
    loud = np.array([0.0, 1.5, -1.2], dtype=np.float32)
    out = normalize_peak(loud, target=0.95)
    assert float(np.max(np.abs(out))) <= 0.95 + 1e-4


def test_default_intra_pauses_are_stt_safe():
    """DEFAULT intra-sentence pauses must stay short (<= 0.5s) so the AI's
    VAD does not finalize the turn mid-utterance and fragment the
    transcript (the regression seen on device: 3s gaps chopped each turn
    into many partials, collapsing similarity). Only the end-of-turn gap
    may be long."""
    text = "I lost him. It was hard. I miss him every day now."
    segments = plan_pacing(text)
    for s in segments[:-1]:
        assert s.pause_after <= 0.5, (
            f"intra pause {s.pause_after}s too long: would fragment VAD"
        )
    # The end gap is still generous for the AI to respond.
    assert segments[-1].pause_after >= 2.0
