#!/usr/bin/env python3
"""Tests for verify.py — logcat parsing, fuzzy matching, scenario verification."""

import json
import os
import tempfile
import unittest

# Import from verify.py (same directory)
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verify import parse_logcat, fuzzy_match, verify_scenario, _check_tool_calls


class TestFuzzyMatch(unittest.TestCase):
    """Test fuzzy_match() — SequenceMatcher-based text comparison."""

    def test_exact_match_returns_1(self):
        passed, ratio = fuzzy_match("hello world", "hello world")
        self.assertTrue(passed)
        self.assertAlmostEqual(ratio, 1.0)

    def test_case_insensitive(self):
        passed, ratio = fuzzy_match("Hello World", "hello world")
        self.assertTrue(passed)
        self.assertAlmostEqual(ratio, 1.0)

    def test_above_threshold_passes(self):
        # "hello world" vs "hello worl" — very close
        passed, ratio = fuzzy_match("hello world", "hello worl", 0.8)
        self.assertTrue(passed)
        self.assertGreater(ratio, 0.8)

    def test_below_threshold_fails(self):
        passed, ratio = fuzzy_match("hello world", "completely different", 0.8)
        self.assertFalse(passed)
        self.assertLess(ratio, 0.8)

    def test_empty_strings(self):
        passed, ratio = fuzzy_match("", "")
        self.assertTrue(passed)
        self.assertAlmostEqual(ratio, 1.0)

    def test_one_empty_string(self):
        passed, ratio = fuzzy_match("hello", "", 0.8)
        self.assertFalse(passed)
        self.assertAlmostEqual(ratio, 0.0)

    def test_custom_threshold(self):
        # With low threshold, even poor matches pass
        passed, ratio = fuzzy_match("hello", "hola", 0.3)
        self.assertTrue(passed)

    def test_stt_realistic_match(self):
        """Simulate STT output — minor word differences."""
        expected = "I had a productive day at work today"
        actual = "I had a productive day at work to day"
        passed, ratio = fuzzy_match(expected, actual, 0.8)
        self.assertTrue(passed)

    def test_stt_poor_recognition(self):
        """Simulate STT failure — garbled output."""
        expected = "I had a productive day at work today"
        actual = "eye hat uh ductive day"
        passed, ratio = fuzzy_match(expected, actual, 0.8)
        self.assertFalse(passed)


class TestParseLogcat(unittest.TestCase):
    """Test parse_logcat() — structured event extraction from log files."""

    def _write_log(self, lines: list[str]) -> str:
        """Write lines to a temp file and return the path."""
        fd, path = tempfile.mkstemp(suffix=".log")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for line in lines:
                f.write(line + "\n")
        return path

    def tearDown(self):
        # Clean up temp files
        pass

    def test_empty_file(self):
        path = self._write_log([])
        events, raw = parse_logcat(path)
        self.assertEqual(events, [])
        self.assertEqual(raw, [])
        os.unlink(path)

    def test_parses_state_events(self):
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: [DYTTY] Call state: connecting",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: active",
            "04-04 12:00:30.000 V/flutter: [DYTTY] Call state: disconnecting",
            "04-04 12:00:31.000 V/flutter: [DYTTY] Call state: idle",
        ])
        events, _ = parse_logcat(path)
        states = [e["value"] for e in events if e["type"] == "state"]
        self.assertEqual(states, ["connecting", "active", "disconnecting", "idle"])
        os.unlink(path)

    def test_parses_user_transcript(self):
        path = self._write_log([
            "04-04 12:00:05.000 V/flutter: [DYTTY] User said: hello world (final: true)",
        ])
        events, _ = parse_logcat(path)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "user_transcript")
        self.assertEqual(events[0]["text"], "hello world")
        self.assertTrue(events[0]["final"])
        os.unlink(path)

    def test_parses_partial_user_transcript(self):
        path = self._write_log([
            "04-04 12:00:05.000 V/flutter: [DYTTY] User said: hel (final: false)",
        ])
        events, _ = parse_logcat(path)
        self.assertEqual(events[0]["type"], "user_transcript")
        self.assertFalse(events[0]["final"])
        os.unlink(path)

    def test_parses_ai_transcript(self):
        path = self._write_log([
            "04-04 12:00:06.000 V/flutter: [DYTTY] AI said: That sounds great! (final: true)",
        ])
        events, _ = parse_logcat(path)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "ai_transcript")
        self.assertEqual(events[0]["text"], "That sounds great!")
        self.assertTrue(events[0]["final"])
        os.unlink(path)

    def test_parses_turn_complete(self):
        path = self._write_log([
            "04-04 12:00:10.000 V/flutter: [DYTTY] Turn complete",
        ])
        events, _ = parse_logcat(path)
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "turn_complete")
        os.unlink(path)

    def test_ignores_non_dytty_lines(self):
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: Some other log",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: active",
            "04-04 12:00:02.000 I/System.out: random noise",
        ])
        events, raw = parse_logcat(path)
        self.assertEqual(len(events), 1)
        self.assertEqual(len(raw), 3)  # raw has all lines
        os.unlink(path)

    def test_parses_full_session(self):
        """Simulate a complete call session."""
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: [DYTTY] Call state: connecting",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: active",
            "04-04 12:00:05.000 V/flutter: [DYTTY] User said: Hey I had a good day (final: true)",
            "04-04 12:00:07.000 V/flutter: [DYTTY] AI said: That's wonderful to hear (final: true)",
            "04-04 12:00:08.000 V/flutter: [DYTTY] Turn complete",
            "04-04 12:00:09.000 V/flutter: Response latency: 150ms",
            "04-04 12:00:30.000 V/flutter: [DYTTY] Call state: disconnecting",
            "04-04 12:00:31.000 V/flutter: [DYTTY] Call state: idle",
        ])
        events, raw = parse_logcat(path)
        self.assertEqual(len(events), 7)  # 4 states + 1 user + 1 ai + 1 turn
        self.assertEqual(len(raw), 8)
        os.unlink(path)

    def test_handles_unicode_errors(self):
        """Log files may contain garbled bytes."""
        fd, path = tempfile.mkstemp(suffix=".log")
        with os.fdopen(fd, "wb") as f:
            f.write(b"[DYTTY] Call state: active\n")
            f.write(b"\xff\xfe garbled \n")
            f.write(b"[DYTTY] Turn complete\n")
        events, _ = parse_logcat(path)
        self.assertEqual(len(events), 2)
        os.unlink(path)


class TestCheckToolCalls(unittest.TestCase):
    """Test _check_tool_calls() — raw logcat search for tool invocations."""

    def test_finds_save_entry(self):
        lines = [
            "04-04 12:00:00.000 V/flutter: Tool call: save_entry → wellness: I went running\n",
        ]
        self.assertTrue(_check_tool_calls(lines, "save_entry"))

    def test_finds_edit_entry(self):
        lines = [
            "04-04 12:00:00.000 V/flutter: Tool call: edit_entry → abc123: updated text\n",
        ]
        self.assertTrue(_check_tool_calls(lines, "edit_entry"))

    def test_not_found_returns_false(self):
        lines = [
            "04-04 12:00:00.000 V/flutter: [DYTTY] Turn complete\n",
            "04-04 12:00:00.000 V/flutter: Some other log\n",
        ]
        self.assertFalse(_check_tool_calls(lines, "save_entry"))

    def test_empty_lines(self):
        self.assertFalse(_check_tool_calls([], "save_entry"))


class TestVerifyScenario(unittest.TestCase):
    """Test verify_scenario() — end-to-end scenario verification."""

    def _make_scenario(self, **overrides):
        """Create a basic scenario dict."""
        base = {
            "name": "test-scenario",
            "description": "Test",
            "path": "daily-call",
            "utterances": [
                {
                    "text": "Hey I had a good day today.",
                    "expect": {
                        "ai_responds": True,
                        "timeout_sec": 10,
                    },
                }
            ],
        }
        base.update(overrides)
        return base

    def _make_events(self, states=None, user_texts=None, ai_texts=None, turns=0):
        """Create structured events list."""
        events = []
        for s in (states or []):
            events.append({"type": "state", "value": s})
        for text in (user_texts or []):
            events.append({"type": "user_transcript", "text": text, "final": True})
        for text in (ai_texts or []):
            events.append({"type": "ai_transcript", "text": text, "final": True})
        for _ in range(turns):
            events.append({"type": "turn_complete"})
        return events

    def test_successful_call(self):
        """All checks pass for a normal call."""
        events = self._make_events(
            states=["connecting", "active", "disconnecting", "idle"],
            user_texts=["Hey I had a good day today"],
            ai_texts=["That's great to hear!"],
            turns=1,
        )
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        for r in results:
            if r["passed"] is not None:
                self.assertTrue(r["passed"], f"Failed: {r['check']} — {r['detail']}")

    def test_call_not_connected(self):
        """Fails when call never reaches active state."""
        events = self._make_events(states=["connecting", "error"])
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        connected = next(r for r in results if r["check"] == "Call connected")
        self.assertFalse(connected["passed"])

        errors = next(r for r in results if r["check"] == "No errors")
        self.assertFalse(errors["passed"])

    def test_no_user_transcript(self):
        """Fails when user speech not recognized."""
        events = self._make_events(
            states=["active", "idle"],
            ai_texts=["Hello"],
            turns=1,
        )
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        user_check = next(r for r in results if "User speech" in r["check"])
        self.assertFalse(user_check["passed"])

    def test_no_ai_response(self):
        """Fails when AI doesn't respond."""
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Hey I had a good day today"],
        )
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        ai_check = next(r for r in results if "AI responded" in r["check"])
        self.assertFalse(ai_check["passed"])

    def test_tool_call_found(self):
        """Passes when expected tool call is in raw logcat."""
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Save a note about running"],
            ai_texts=["Saved!"],
            turns=1,
        )
        raw_lines = ["Tool call: save_entry → wellness: running\n"]
        scenario = self._make_scenario(
            utterances=[{
                "text": "Save a note about running",
                "expect": {
                    "ai_responds": True,
                    "tool_call": "save_entry",
                    "timeout_sec": 10,
                },
            }]
        )
        results = verify_scenario(events, raw_lines, scenario)

        tool_check = next(r for r in results if "Tool call" in r["check"])
        self.assertTrue(tool_check["passed"])

    def test_tool_call_not_found(self):
        """Fails when expected tool call is missing."""
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Save a note"],
            ai_texts=["Sure"],
            turns=1,
        )
        scenario = self._make_scenario(
            utterances=[{
                "text": "Save a note",
                "expect": {
                    "ai_responds": True,
                    "tool_call": "save_entry",
                    "timeout_sec": 10,
                },
            }]
        )
        results = verify_scenario(events, [], scenario)

        tool_check = next(r for r in results if "Tool call" in r["check"])
        self.assertFalse(tool_check["passed"])

    def test_call_not_ended_cleanly(self):
        """Fails when call doesn't reach idle/disconnecting."""
        events = self._make_events(
            states=["active"],
            user_texts=["Hey"],
            ai_texts=["Hi"],
            turns=1,
        )
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        ended = next(r for r in results if r["check"] == "Call ended cleanly")
        self.assertFalse(ended["passed"])

    def test_fuzzy_match_with_stt_variations(self):
        """User transcript close but not exact still passes."""
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Hey I had a good day today"],  # missing period
            ai_texts=["Great!"],
            turns=1,
        )
        scenario = self._make_scenario()
        results = verify_scenario(events, [], scenario)

        user_check = next(r for r in results if "User speech" in r["check"])
        self.assertTrue(user_check["passed"])


if __name__ == "__main__":
    unittest.main()
