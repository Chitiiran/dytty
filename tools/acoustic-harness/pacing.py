#!/usr/bin/env python3
"""Human-pacing for TTS audio.

Flat Kokoro output reads like a narrator and, played back-to-back, talks
over the AI (the failure in the first Rose demo run). plan_pacing() breaks
one turn's text into spoken segments each followed by a deliberate pause —
the breaths, hesitations, and end-of-turn gap a real grieving person uses.
The generator renders each segment with Kokoro and concatenates them with
build_silence() gaps.

Pure text/array logic — no TTS or audio device needed to test it.
"""

import re
from dataclasses import dataclass

import numpy as np


@dataclass
class Segment:
    """A spoken chunk and the silence (seconds) that follows it."""
    text: str
    pause_after: float


# Split into sentences, keeping the terminal punctuation. Treat '...' as a
# single hesitation token so it is not shredded into three periods.
_SENTENCE_RE = re.compile(r".+?(?:\.\.\.|[.!?])(?:\s+|$)", re.DOTALL)


def _split_sentences(text: str) -> list[str]:
    text = text.strip()
    if not text:
        return []
    matches = [m.group(0).strip() for m in _SENTENCE_RE.finditer(text)]
    if not matches:
        return [text]
    # Capture any trailing remainder without terminal punctuation.
    consumed = sum(len(m) for m in matches)
    if consumed < len(text.replace("  ", " ")):
        tail = text[text.rfind(matches[-1]) + len(matches[-1]):].strip()
        if tail:
            matches.append(tail)
    return [m for m in matches if m]


def _split_long_on_commas(sentence: str) -> list[str]:
    """Break a long sentence at commas so it has internal breath beats."""
    parts = [p.strip() for p in sentence.split(",")]
    parts = [p for p in parts if p]
    # Reattach the comma to all but the last part for natural rendering.
    out = []
    for i, p in enumerate(parts):
        if i < len(parts) - 1:
            out.append(p + ",")
        else:
            out.append(p)
    return out


def plan_pacing(
    text: str,
    sentence_pause: float = 0.35,
    ellipsis_pause: float = 0.5,
    comma_pause: float = 0.2,
    end_gap: float = 2.5,
    split_long_commas: bool = False,
    long_sentence_chars: int = 60,
) -> list[Segment]:
    """Turn a turn's text into paced (segment, pause_after) units.

    - each sentence is its own segment, followed by ``sentence_pause``
    - a sentence ending in '...' pauses ``ellipsis_pause`` (hesitation)
    - long sentences are optionally broken at commas (``comma_pause``)
    - the FINAL segment is followed by ``end_gap`` — room for the AI to
      reply before the next turn plays
    """
    sentences = _split_sentences(text)
    segments: list[Segment] = []

    for sentence in sentences:
        chunks = [sentence]
        # Break at commas when requested and the sentence is either long
        # or has multiple comma-separated clauses (a breathless list).
        if split_long_commas and sentence.count(",") >= 1 and (
            len(sentence) >= long_sentence_chars or sentence.count(",") >= 2
        ):
            chunks = _split_long_on_commas(sentence)

        for i, chunk in enumerate(chunks):
            if not chunk.strip():
                continue
            is_last_chunk = i == len(chunks) - 1
            if not is_last_chunk:
                pause = comma_pause
            elif chunk.endswith("..."):
                pause = ellipsis_pause
            else:
                pause = sentence_pause
            segments.append(Segment(text=chunk.strip(), pause_after=pause))

    if segments:
        segments[-1].pause_after = max(end_gap, segments[-1].pause_after)
    return segments


def build_silence(seconds: float, samplerate: int = 24000,
                  dtype=np.float32) -> np.ndarray:
    """Return ``seconds`` of digital silence at ``samplerate``."""
    return np.zeros(int(round(seconds * samplerate)), dtype=dtype)


def normalize_peak(audio: np.ndarray, target: float = 0.95) -> np.ndarray:
    """Scale audio so its absolute peak equals ``target``.

    Kokoro output peaks around 0.5 — quiet over the air, which costs STT
    accuracy (observed garbling: "grateful" -> "grim"). Scaling the peak to
    ~0.95 roughly doubles the effective loudness/clarity for over-air STT
    without clipping. Silence is returned unchanged (no divide-by-zero).
    """
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    if peak == 0.0:
        return audio
    return (audio * (target / peak)).astype(audio.dtype)
