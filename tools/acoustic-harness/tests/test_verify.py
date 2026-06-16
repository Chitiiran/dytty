#!/usr/bin/env python3
"""Tests for verify.py — logcat parsing, fuzzy matching, scenario verification.

App-agnostic: tag is configurable, scripts path passed as argument.
"""

import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from verify import parse_logcat, fuzzy_match, verify_scenario, _check_tool_calls, resolve_tag, score_recall


class TestResolveTag(unittest.TestCase):
    """Test resolve_tag() — --tag flag and ACOUSTIC_TAG env var."""

    def test_flag_takes_precedence(self):
        os.environ["ACOUSTIC_TAG"] = "ENVTAG"
        try:
            self.assertEqual(resolve_tag("FLAGTAG"), "FLAGTAG")
        finally:
            del os.environ["ACOUSTIC_TAG"]

    def test_env_var_fallback(self):
        os.environ["ACOUSTIC_TAG"] = "ENVTAG"
        try:
            self.assertEqual(resolve_tag(None), "ENVTAG")
        finally:
            del os.environ["ACOUSTIC_TAG"]

    def test_error_when_neither_set(self):
        env_backup = os.environ.pop("ACOUSTIC_TAG", None)
        try:
            with self.assertRaises(SystemExit) as cm:
                resolve_tag(None)
            self.assertEqual(cm.exception.code, 2)
        finally:
            if env_backup is not None:
                os.environ["ACOUSTIC_TAG"] = env_backup


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
    """Test parse_logcat() — structured event extraction, configurable tag."""

    def _write_log(self, lines: list[str]) -> str:
        fd, path = tempfile.mkstemp(suffix=".log")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for line in lines:
                f.write(line + "\n")
        return path

    def test_empty_file(self):
        path = self._write_log([])
        events, raw = parse_logcat(path, tag="DYTTY")
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
        events, _ = parse_logcat(path, tag="DYTTY")
        states = [e["value"] for e in events if e["type"] == "state"]
        self.assertEqual(states, ["connecting", "active", "disconnecting", "idle"])
        os.unlink(path)

    def test_parses_with_custom_tag(self):
        """Different tag is correctly filtered."""
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: [MYAPP] Call state: active",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: idle",
        ])
        events, _ = parse_logcat(path, tag="MYAPP")
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["value"], "active")
        os.unlink(path)

    def test_ignores_other_tags(self):
        """Only lines with the specified tag are parsed."""
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: [OTHER] Call state: active",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: idle",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["value"], "idle")
        os.unlink(path)

    def test_parses_user_transcript(self):
        path = self._write_log([
            "04-04 12:00:05.000 V/flutter: [DYTTY] User said: hello world (final: true)",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "user_transcript")
        self.assertEqual(events[0]["text"], "hello world")
        self.assertTrue(events[0]["final"])
        os.unlink(path)

    def test_parses_partial_user_transcript(self):
        path = self._write_log([
            "04-04 12:00:05.000 V/flutter: [DYTTY] User said: hel (final: false)",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(events[0]["type"], "user_transcript")
        self.assertFalse(events[0]["final"])
        os.unlink(path)

    def test_parses_ai_transcript(self):
        path = self._write_log([
            "04-04 12:00:06.000 V/flutter: [DYTTY] AI said: That sounds great! (final: true)",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "ai_transcript")
        self.assertEqual(events[0]["text"], "That sounds great!")
        self.assertTrue(events[0]["final"])
        os.unlink(path)

    def test_parses_turn_complete(self):
        path = self._write_log([
            "04-04 12:00:10.000 V/flutter: [DYTTY] Turn complete",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 1)
        self.assertEqual(events[0]["type"], "turn_complete")
        os.unlink(path)

    def test_ignores_non_tagged_lines(self):
        path = self._write_log([
            "04-04 12:00:00.000 V/flutter: Some other log",
            "04-04 12:00:01.000 V/flutter: [DYTTY] Call state: active",
            "04-04 12:00:02.000 I/System.out: random noise",
        ])
        events, raw = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 1)
        self.assertEqual(len(raw), 3)
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
        events, raw = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 7)
        self.assertEqual(len(raw), 8)
        os.unlink(path)

    def test_handles_unicode_errors(self):
        """Log files may contain garbled bytes."""
        fd, path = tempfile.mkstemp(suffix=".log")
        with os.fdopen(fd, "wb") as f:
            f.write(b"[DYTTY] Call state: active\n")
            f.write(b"\xff\xfe garbled \n")
            f.write(b"[DYTTY] Turn complete\n")
        events, _ = parse_logcat(path, tag="DYTTY")
        self.assertEqual(len(events), 2)
        os.unlink(path)


class TestParseEntryEvents(unittest.TestCase):
    """#224: parse structured entry-saved / reconciliation log lines."""

    def _write_log(self, lines: list[str]) -> str:
        fd, path = tempfile.mkstemp(suffix=".log")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            for line in lines:
                f.write(line + "\n")
        return path

    def test_parses_in_call_entry_saved(self):
        path = self._write_log([
            "V/flutter: [DYTTY] Entry saved: negative (origin: in-call)",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        saved = [e for e in events if e["type"] == "entry_saved"]
        self.assertEqual(len(saved), 1)
        self.assertEqual(saved[0]["category"], "negative")
        self.assertEqual(saved[0]["origin"], "in-call")
        os.unlink(path)

    def test_parses_reconciled_add(self):
        path = self._write_log([
            "V/flutter: [DYTTY] Entry saved: gratitude (origin: reconciled-add)",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        saved = [e for e in events if e["type"] == "entry_saved"]
        self.assertEqual(saved[0]["origin"], "reconciled-add")
        os.unlink(path)

    def test_parses_entry_reworded(self):
        path = self._write_log([
            "V/flutter: [DYTTY] Entry reworded: negative",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        rew = [e for e in events if e["type"] == "entry_reworded"]
        self.assertEqual(len(rew), 1)
        self.assertEqual(rew[0]["category"], "negative")
        os.unlink(path)

    def test_parses_reconciliation_complete(self):
        path = self._write_log([
            "V/flutter: [DYTTY] Reconciliation complete: 2 added, 1 reworded",
        ])
        events, _ = parse_logcat(path, tag="DYTTY")
        rc = [e for e in events if e["type"] == "reconciliation_complete"]
        self.assertEqual(len(rc), 1)
        self.assertEqual(rc[0]["added"], 2)
        self.assertEqual(rc[0]["reworded"], 1)
        os.unlink(path)


class TestVerifyEntryExpectations(unittest.TestCase):
    """#224: verify_scenario asserts entry count + categories."""

    def _events(self, *categories):
        return [
            {"type": "state", "value": "active"},
            *[
                {"type": "entry_saved", "category": c, "origin": "in-call"}
                for c in categories
            ],
        ]

    def _scenario(self, expect):
        return {
            "name": "s",
            "utterances": [{"text": "x", "expect": expect}],
        }

    def test_min_entries_pass(self):
        events = self._events("negative", "gratitude")
        results = verify_scenario(events, [], self._scenario({"min_entries": 2}))
        check = next(r for r in results if "entries captured" in r["check"].lower())
        self.assertTrue(check["passed"], check["detail"])

    def test_min_entries_fail(self):
        events = self._events("negative")
        results = verify_scenario(events, [], self._scenario({"min_entries": 2}))
        check = next(r for r in results if "entries captured" in r["check"].lower())
        self.assertFalse(check["passed"])

    def test_expected_categories_pass(self):
        events = self._events("negative", "gratitude")
        results = verify_scenario(
            events, [], self._scenario({"expected_categories": ["negative", "gratitude"]})
        )
        check = next(r for r in results if "categor" in r["check"].lower())
        self.assertTrue(check["passed"], check["detail"])

    def test_expected_categories_missing_one_fails(self):
        events = self._events("negative")
        results = verify_scenario(
            events, [], self._scenario({"expected_categories": ["negative", "gratitude"]})
        )
        check = next(r for r in results if "categor" in r["check"].lower())
        self.assertFalse(check["passed"])

    def test_no_entry_expectations_adds_no_checks(self):
        events = self._events("negative")
        results = verify_scenario(events, [], self._scenario({"ai_responds": True}))
        self.assertFalse(
            any("entries captured" in r["check"].lower() for r in results)
        )


class TestCheckToolCalls(unittest.TestCase):
    """Test _check_tool_calls() — raw logcat search for tool invocations."""

    def test_finds_save_entry(self):
        lines = ["Tool call: save_entry -> wellness: running\n"]
        self.assertTrue(_check_tool_calls(lines, "save_entry"))

    def test_finds_edit_entry(self):
        lines = ["Tool call: edit_entry -> abc123: updated\n"]
        self.assertTrue(_check_tool_calls(lines, "edit_entry"))

    def test_not_found_returns_false(self):
        lines = ["[DYTTY] Turn complete\n", "Some other log\n"]
        self.assertFalse(_check_tool_calls(lines, "save_entry"))

    def test_empty_lines(self):
        self.assertFalse(_check_tool_calls([], "save_entry"))


class TestVerifyScenario(unittest.TestCase):
    """Test verify_scenario() — end-to-end scenario verification."""

    def _make_scenario(self, **overrides):
        base = {
            "name": "test-scenario",
            "description": "Test",
            "path": "daily-call",
            "utterances": [{
                "text": "Hey I had a good day today.",
                "expect": {"ai_responds": True, "timeout_sec": 10},
            }],
        }
        base.update(overrides)
        return base

    def _make_events(self, states=None, user_texts=None, ai_texts=None, turns=0):
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
        events = self._make_events(
            states=["connecting", "active", "disconnecting", "idle"],
            user_texts=["Hey I had a good day today"],
            ai_texts=["That's great to hear!"],
            turns=1,
        )
        results = verify_scenario(events, [], self._make_scenario())
        for r in results:
            if r["passed"] is not None:
                self.assertTrue(r["passed"], f"Failed: {r['check']} — {r['detail']}")

    def test_call_not_connected(self):
        events = self._make_events(states=["connecting", "error"])
        results = verify_scenario(events, [], self._make_scenario())
        connected = next(r for r in results if r["check"] == "Call connected")
        self.assertFalse(connected["passed"])
        errors = next(r for r in results if r["check"] == "No errors")
        self.assertFalse(errors["passed"])

    def test_no_user_transcript(self):
        events = self._make_events(states=["active", "idle"], ai_texts=["Hello"], turns=1)
        results = verify_scenario(events, [], self._make_scenario())
        user_check = next(r for r in results if "User speech" in r["check"])
        self.assertFalse(user_check["passed"])

    def test_no_ai_response(self):
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Hey I had a good day today"],
        )
        results = verify_scenario(events, [], self._make_scenario())
        ai_check = next(r for r in results if "AI responded" in r["check"])
        self.assertFalse(ai_check["passed"])

    def test_tool_call_found(self):
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Save a note about running"],
            ai_texts=["Saved!"],
            turns=1,
        )
        raw_lines = ["Tool call: save_entry -> wellness: running\n"]
        scenario = self._make_scenario(utterances=[{
            "text": "Save a note about running",
            "expect": {"ai_responds": True, "tool_call": "save_entry", "timeout_sec": 10},
        }])
        results = verify_scenario(events, raw_lines, scenario)
        tool_check = next(r for r in results if "Tool call" in r["check"])
        self.assertTrue(tool_check["passed"])

    def test_tool_call_not_found(self):
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Save a note"],
            ai_texts=["Sure"],
            turns=1,
        )
        scenario = self._make_scenario(utterances=[{
            "text": "Save a note",
            "expect": {"ai_responds": True, "tool_call": "save_entry", "timeout_sec": 10},
        }])
        results = verify_scenario(events, [], scenario)
        tool_check = next(r for r in results if "Tool call" in r["check"])
        self.assertFalse(tool_check["passed"])

    def test_call_not_ended_cleanly(self):
        events = self._make_events(
            states=["active"],
            user_texts=["Hey"],
            ai_texts=["Hi"],
            turns=1,
        )
        results = verify_scenario(events, [], self._make_scenario())
        ended = next(r for r in results if r["check"] == "Call ended cleanly")
        self.assertFalse(ended["passed"])

    def test_fuzzy_match_with_stt_variations(self):
        events = self._make_events(
            states=["active", "idle"],
            user_texts=["Hey I had a good day today"],
            ai_texts=["Great!"],
            turns=1,
        )
        results = verify_scenario(events, [], self._make_scenario())
        user_check = next(r for r in results if "User speech" in r["check"])
        self.assertTrue(user_check["passed"])


class TestScoreRecall(unittest.TestCase):
    """#231: score_recall() — deterministic multi-item recall metric."""

    def test_full_capture(self):
        expected = [
            {"category": "negative", "anchor": "work was brutal"},
            {"category": "gratitude", "anchor": "sister called"},
        ]
        saved = [
            {"type": "entry_saved", "category": "negative", "origin": "in-call"},
            {"type": "entry_saved", "category": "gratitude", "origin": "reconciled-add"},
        ]
        result = score_recall(expected, saved)
        self.assertEqual(result["recall"], 1.0)
        self.assertEqual(result["category_accuracy"], 1.0)
        self.assertFalse(result["over_split"])
        self.assertFalse(result["hallucination"])

    def test_under_capture(self):
        expected = [
            {"category": "negative", "anchor": "a"},
            {"category": "gratitude", "anchor": "b"},
        ]
        saved = [{"type": "entry_saved", "category": "negative", "origin": "in-call"}]
        result = score_recall(expected, saved)
        self.assertEqual(result["recall"], 0.5)
        self.assertFalse(result["over_split"])

    def test_over_split(self):
        result = score_recall(
            [{"category": "positive", "anchor": "a"}],
            [
                {"type": "entry_saved", "category": "positive", "origin": "in-call"},
                {"type": "entry_saved", "category": "positive", "origin": "reconciled-add"},
            ],
        )
        self.assertTrue(result["over_split"])

    def test_hallucination(self):
        result = score_recall(
            [],
            [{"type": "entry_saved", "category": "positive", "origin": "in-call"}],
        )
        self.assertTrue(result["hallucination"])
        self.assertEqual(result["recall"], 1.0)  # nothing expected, nothing missed

    def test_verify_scenario_wires_expected_items(self):
        events = [
            {"type": "state", "value": "active"},
            {"type": "entry_saved", "category": "negative", "origin": "in-call"},
            {"type": "entry_saved", "category": "gratitude", "origin": "reconciled-add"},
            {"type": "state", "value": "idle"},
        ]
        scenario = {
            "name": "s",
            "utterances": [{
                "text": "x",
                "expect": {"expected_items": [
                    {"category": "negative", "anchor": "a"},
                    {"category": "gratitude", "anchor": "b"},
                ]},
            }],
        }
        results = verify_scenario(events, [], scenario)
        recall = next(r for r in results if "multi-item recall" in r["check"])
        self.assertTrue(recall["passed"], recall["detail"])
        self.assertEqual(recall["metrics"]["recall"], 1.0)


if __name__ == "__main__":
    unittest.main()
