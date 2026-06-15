#!/usr/bin/env python3
"""Tests for latency.py — measure true conversational latency from a session log.

The in-app stopwatch measures user-FIRST-chunk -> AI-first-audio, which includes
the whole user utterance + Gemini's VAD silence wait (#223). The industry
standard, and what this analyzer computes, is user-LAST-speech -> AI-first-audio,
using the device's single monotonic logcat clock (no cross-device sync).
"""

import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from latency import parse_timestamp, analyze_turns


class TestParseTimestamp(unittest.TestCase):
    def test_parses_logcat_time_to_ms(self):
        # 06-15 17:50:44.816 -> ms within the day
        ms = parse_timestamp("06-15 17:50:44.816")
        self.assertEqual(ms, (((17 * 60) + 50) * 60 + 44) * 1000 + 816)

    def test_two_timestamps_diff(self):
        a = parse_timestamp("06-15 17:50:44.816")
        b = parse_timestamp("06-15 17:50:46.300")
        self.assertEqual(b - a, 1484)


# A minimal but realistic session: user speaks (3 partials), stops at .891,
# AI's first audio chunk lands at 2.034s later.
SAMPLE_LOG = """\
06-15 15:21:23.421 I/flutter ( 7245): [DYTTY] Call state: active
06-15 15:21:27.203 I/flutter ( 7245): [DYTTY] User said:  Hey (final: false)
06-15 15:21:27.475 I/flutter ( 7245): [DYTTY] User said:  there (final: false)
06-15 15:21:27.891 I/flutter ( 7245): [DYTTY] User said:  how are you (final: false)
06-15 15:21:29.925 I/flutter ( 7245): [DYTTY] Audio chunk received: 46080 bytes
06-15 15:21:29.930 I/flutter ( 7245): [DYTTY] Audio chunk received: 1920 bytes
06-15 15:21:30.100 I/flutter ( 7245): [DYTTY] AI said: Hi! (final: false)
06-15 15:21:31.000 I/flutter ( 7245): [DYTTY] Turn complete
"""


class TestAnalyzeTurns(unittest.TestCase):
    def _write(self, text):
        f = tempfile.NamedTemporaryFile(
            "w", suffix=".log", delete=False, encoding="utf-8"
        )
        f.write(text)
        f.close()
        self.addCleanup(os.unlink, f.name)
        return f.name

    def test_latency_is_last_user_speech_to_first_ai_audio(self):
        turns = analyze_turns(self._write(SAMPLE_LOG))
        self.assertEqual(len(turns), 1)
        # 29.925 - 27.891 = 2034 ms (end-of-speech -> first AI audio)
        self.assertEqual(turns[0]["latency_ms"], 2034)

    def test_records_endpoints(self):
        turns = analyze_turns(self._write(SAMPLE_LOG))
        self.assertEqual(turns[0]["user_last_ms"], parse_timestamp("06-15 15:21:27.891"))
        self.assertEqual(
            turns[0]["ai_first_audio_ms"], parse_timestamp("06-15 15:21:29.925")
        )

    def test_naive_measurement_is_larger(self):
        # The buggy in-app metric would measure from the FIRST user chunk
        # (27.203), inflating it by the utterance duration.
        turns = analyze_turns(self._write(SAMPLE_LOG))
        naive = parse_timestamp("06-15 15:21:29.925") - parse_timestamp(
            "06-15 15:21:27.203"
        )
        self.assertGreater(naive, turns[0]["latency_ms"])
        self.assertEqual(naive - turns[0]["latency_ms"], 688)  # utterance span

    def test_no_turns_when_no_audio(self):
        log = (
            "06-15 15:21:27.203 I/flutter ( 7245): [DYTTY] User said:  Hey (final: false)\n"
        )
        self.assertEqual(analyze_turns(self._write(log)), [])


if __name__ == "__main__":
    unittest.main()
