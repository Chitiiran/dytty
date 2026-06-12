#!/usr/bin/env python3
"""Tests for calibrate.py — audio-environment calibration analysis.

Owner direction (2026-06-11): speaker quality must be checked from both
the laptop side and the phone side, giving level/latency/repeatability
numbers instead of mystery test failures when the environment drifts.
"""

import math
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from calibrate import (
    detect_onset_seconds,
    rms_dbfs,
    summarize_runs,
    word_error_rate,
)


def _sine(freq=1000.0, seconds=0.5, rate=16000, amplitude=0.5):
    n = int(seconds * rate)
    return [amplitude * math.sin(2 * math.pi * freq * i / rate) for i in range(n)]


class TestRmsDbfs(unittest.TestCase):
    def test_full_scale_sine_is_about_minus_3_dbfs(self):
        self.assertAlmostEqual(rms_dbfs(_sine(amplitude=1.0)), -3.01, delta=0.1)

    def test_half_scale_sine_is_6_db_below_full_scale(self):
        full = rms_dbfs(_sine(amplitude=1.0))
        half = rms_dbfs(_sine(amplitude=0.5))
        self.assertAlmostEqual(full - half, 6.02, delta=0.1)

    def test_silence_is_floor(self):
        self.assertLessEqual(rms_dbfs([0.0] * 1600), -90.0)


class TestOnsetDetection(unittest.TestCase):
    def test_onset_after_leading_silence(self):
        rate = 16000
        signal = [0.0] * rate + _sine(seconds=0.5, rate=rate)  # 1s silence
        onset = detect_onset_seconds(signal, rate, threshold_dbfs=-30.0)
        self.assertAlmostEqual(onset, 1.0, delta=0.05)

    def test_no_onset_in_silence_returns_none(self):
        self.assertIsNone(
            detect_onset_seconds([0.0] * 16000, 16000, threshold_dbfs=-30.0)
        )


class TestWordErrorRate(unittest.TestCase):
    def test_identical_is_zero(self):
        self.assertEqual(word_error_rate("today i went", "today i went"), 0.0)

    def test_case_and_punctuation_insensitive(self):
        self.assertEqual(
            word_error_rate("Today, I went grocery shopping.",
                            "today i went grocery shopping"),
            0.0,
        )

    def test_dropped_tail_counts_as_deletions(self):
        # 7-word reference, last 2 missing -> WER 2/7
        wer = word_error_rate(
            "today i went grocery shopping and cooked",
            "today i went grocery shopping",
        )
        self.assertAlmostEqual(wer, 2 / 7, delta=0.001)

    def test_substitution_counts(self):
        wer = word_error_rate("i cooked a nice meal", "i booked a nice meal")
        self.assertAlmostEqual(wer, 1 / 5, delta=0.001)


class TestSummarizeRuns(unittest.TestCase):
    def test_reports_mean_and_spread(self):
        s = summarize_runs([100.0, 110.0, 105.0])
        self.assertAlmostEqual(s["mean"], 105.0, delta=0.01)
        self.assertAlmostEqual(s["min"], 100.0)
        self.assertAlmostEqual(s["max"], 110.0)
        self.assertGreater(s["stdev"], 0)

    def test_single_run_has_zero_stdev(self):
        self.assertEqual(summarize_runs([42.0])["stdev"], 0.0)


if __name__ == "__main__":
    unittest.main()
