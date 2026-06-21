#!/usr/bin/env python3
"""Closed-loop AI-turn detector for human-like voice turn-taking.

The harness plays an utterance, then must wait for the AI to respond and
FINISH before playing the next one — otherwise it talks over the AI and
triggers server-side barge-in (the failure that broke the first Rose demo
run: clips played back-to-back on a fixed timer, the AI never got a clean
turn, no `Turn complete` ever logged).

This detector keys on ACTUAL ACOUSTIC ENERGY from the laptop mic (the AI's
voice coming out of the phone speaker), not on fragile logcat markers. It
is a pure state machine — energy readings in, turn state out — so the
decision logic is unit-tested without a mic or device. The mic capture
that feeds it lives in mic_listener.py.

State machine:

    WAITING_FOR_SPEECH --(energy high for >= min_speech)--> AI_SPEAKING
    AI_SPEAKING        --(energy low for  >= hangover)----> AI_DONE

A short pause mid-utterance (< hangover) does not end the turn; resumed
speech resets the silence timer.
"""

from enum import Enum


class TurnState(Enum):
    WAITING_FOR_SPEECH = "waiting_for_speech"
    AI_SPEAKING = "ai_speaking"
    AI_DONE = "ai_done"


class TurnDetector:
    """Energy-threshold state machine for AI turn boundaries.

    Args:
        silence_floor: calibrated room-tone RMS (the quiet baseline).
        start_threshold: multiple of the floor that counts as speech.
        silence_hangover: seconds of continuous silence that end a turn.
        min_speech: seconds of continuous loud audio required to confirm
            the AI actually started (rejects single-frame blips/noise).
    """

    def __init__(
        self,
        silence_floor: float,
        start_threshold: float = 3.0,
        silence_hangover: float = 1.0,
        min_speech: float = 0.1,
    ):
        self.silence_floor = silence_floor
        self.start_threshold = start_threshold
        self.silence_hangover = silence_hangover
        self.min_speech = min_speech

        self.state = TurnState.WAITING_FOR_SPEECH
        # Timestamp the current loud run started (None when not in a run).
        self._loud_since: float | None = None
        # Timestamp the current quiet run started (None when not quiet).
        self._quiet_since: float | None = None

    @property
    def _speech_level(self) -> float:
        return self.silence_floor * self.start_threshold

    def process_frame(self, t: float, rms: float) -> TurnState:
        """Feed one (timestamp, rms) frame; return the new state."""
        loud = rms >= self._speech_level

        if self.state == TurnState.WAITING_FOR_SPEECH:
            if loud:
                if self._loud_since is None:
                    self._loud_since = t
                elif t - self._loud_since >= self.min_speech:
                    self.state = TurnState.AI_SPEAKING
                    self._quiet_since = None
            else:
                # Blip ended before reaching min_speech — reset.
                self._loud_since = None

        elif self.state == TurnState.AI_SPEAKING:
            if loud:
                # Speaking continues; cancel any pending silence run.
                self._quiet_since = None
            else:
                if self._quiet_since is None:
                    self._quiet_since = t
                elif t - self._quiet_since >= self.silence_hangover:
                    self.state = TurnState.AI_DONE

        return self.state

    @staticmethod
    def calibrate_floor(samples: list[float]) -> float:
        """Derive a robust silence floor from room-tone RMS samples.

        Uses the median (robust to stray loud blips) so the floor reflects
        the typical quiet baseline, not an outlier.
        """
        if not samples:
            return 0.0
        ordered = sorted(samples)
        n = len(ordered)
        mid = n // 2
        if n % 2:
            return ordered[mid]
        return (ordered[mid - 1] + ordered[mid]) / 2
