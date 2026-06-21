#!/usr/bin/env python3
"""Laptop-mic listening loop for closed-loop voice turn-taking.

The harness plays an utterance, then calls wait_for_ai_turn() to LISTEN to
the AI's reply (the phone speaker, captured by the laptop mic) and return
once the AI has finished — so the next utterance never talks over it.

The audio frame SOURCE is injected (a callable returning the next block of
float samples, or None when exhausted). In production it is fed by a live
sounddevice InputStream (see open_mic_source / calibrate_floor_from_mic);
in tests it is a fake generator, so the decision loop needs no microphone.

Returns one of:
    "ai_done"     — AI spoke then went silent for >= hangover (normal)
    "source_ended"— AI spoke, the stream ended before full silence
    "timeout"     — wall-clock timeout (AI likely never responded)
"""

import math

import numpy as np

from turn_detector import TurnDetector, TurnState


def rms(block) -> float:
    """Root-mean-square energy of a block of float samples."""
    arr = np.asarray(block, dtype=np.float64)
    if arr.size == 0:
        return 0.0
    return float(math.sqrt(np.mean(arr * arr)))


def wait_for_ai_turn(
    source,
    frame_seconds: float,
    silence_floor: float,
    start_threshold: float = 3.0,
    silence_hangover: float = 1.0,
    min_speech: float = 0.1,
    timeout: float = 15.0,
) -> str:
    """Drive a TurnDetector from a frame source until the AI turn ends.

    Args:
        source: callable returning the next audio block (array of floats)
            or None when the stream is exhausted.
        frame_seconds: wall-clock duration each block represents — also the
            detector's virtual clock tick.
    """
    detector = TurnDetector(
        silence_floor=silence_floor,
        start_threshold=start_threshold,
        silence_hangover=silence_hangover,
        min_speech=min_speech,
    )

    t = 0.0
    spoke = False
    while t < timeout:
        block = source()
        if block is None:
            # Stream ended. If the AI had started, treat the turn as over
            # rather than hanging; otherwise report exhaustion.
            return "source_ended" if spoke else "source_ended"

        level = rms(block)
        state = detector.process_frame(t, level)
        if state == TurnState.AI_SPEAKING:
            spoke = True
        if state == TurnState.AI_DONE:
            return "ai_done"

        t += frame_seconds

    return "timeout"


# ── Real-microphone helpers (not exercised by unit tests) ────────────────

def calibrate_floor_from_mic(seconds: float = 0.6,
                             samplerate: int = 16000,
                             blocksize: int = 800) -> float:
    """Record a short window of room tone and derive the silence floor.

    Call BEFORE the call connects (or during a known-quiet moment) so the
    floor reflects the room, not the AI's voice.
    """
    import sounddevice as sd

    samples_rms: list[float] = []
    frames_needed = int(seconds * samplerate / blocksize)
    with sd.InputStream(samplerate=samplerate, channels=1,
                        blocksize=blocksize, dtype="float32") as stream:
        for _ in range(max(frames_needed, 1)):
            block, _overflow = stream.read(blocksize)
            samples_rms.append(rms(block[:, 0]))
    return TurnDetector.calibrate_floor(samples_rms)


def open_mic_source(stream, blocksize: int):
    """Return a source callable that reads blocks from a live InputStream."""
    def _next():
        block, _overflow = stream.read(blocksize)
        return block[:, 0]
    return _next
