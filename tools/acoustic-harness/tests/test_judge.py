#!/usr/bin/env python3
"""Tests for judge.py — question-quality LLM-judge (#231).

The LLM call (_judge_turn) is patched, so these tests are deterministic and
require no network or google-generativeai install.
"""

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import judge


class TestParseAiTurns(unittest.TestCase):
    def test_extracts_ai_turns_only(self):
        transcript = (
            "You: work was rough today\n"
            "AI: oh that sounds heavy. what made it rough?\n"
            "You: just a lot of meetings\n"
            "AI: mm, that's a lot.\n"
        )
        self.assertEqual(
            judge.parse_ai_turns(transcript),
            ["oh that sounds heavy. what made it rough?", "mm, that's a lot."],
        )

    def test_empty_transcript(self):
        self.assertEqual(judge.parse_ai_turns(""), [])


class TestAggregate(unittest.TestCase):
    def test_ratio_why_and_ending(self):
        per_turn = [
            {"warm": 1.0, "relevant_to_prior": 1.0, "sparing": 1.0,
             "open_not_why": 1.0, "reflects_before_asking": 1.0, "is_question": True,
             "ends_on_question": True, "is_why": False},
            {"warm": 1.0, "relevant_to_prior": 1.0, "sparing": 1.0,
             "open_not_why": 1.0, "reflects_before_asking": 1.0, "is_question": False,
             "ends_on_question": False, "is_why": False},
            {"warm": 1.0, "relevant_to_prior": 1.0, "sparing": 1.0,
             "open_not_why": 0.0, "reflects_before_asking": 1.0, "is_question": True,
             "ends_on_question": False, "is_why": True},
        ]
        agg = judge.aggregate(per_turn)
        # 2 questions, 1 reflection -> reflections/questions = 0.5
        self.assertEqual(agg["reflection_question_ratio"], 0.5)
        self.assertEqual(agg["why_question_count"], 1)
        self.assertEqual(agg["pct_turns_ending_on_question"], round(1 / 3, 3))
        self.assertEqual(agg["turns"], 3)

    def test_all_reflections_no_questions(self):
        per_turn = [
            {"warm": 1.0, "relevant_to_prior": 1.0, "sparing": 1.0,
             "open_not_why": 1.0, "reflects_before_asking": 1.0, "is_question": False,
             "ends_on_question": False, "is_why": False},
        ]
        agg = judge.aggregate(per_turn)
        # 1 reflection, 0 questions -> ratio = float(reflections)
        self.assertEqual(agg["reflection_question_ratio"], 1.0)
        self.assertEqual(agg["why_question_count"], 0)


class TestScoreTranscript(unittest.TestCase):
    def test_calls_judge_per_ai_turn(self):
        transcript = "You: hi\nAI: hey, how was your day?\n"
        fake = {"warm": 1.0, "relevant_to_prior": 1.0, "sparing": 1.0,
                "open_not_why": 1.0, "reflects_before_asking": 0.0, "is_question": True,
                "ends_on_question": True, "is_why": False, "justification": "ok"}
        with patch.object(judge, "_judge_turn", return_value=fake) as m:
            result = judge.score_transcript(transcript, api_key="x")
        self.assertEqual(m.call_count, 1)
        self.assertEqual(result["aggregate"]["why_question_count"], 0)
        self.assertEqual(len(result["per_turn"]), 1)

    def test_passes_prior_user_line_to_judge(self):
        transcript = "You: my dog died\nAI: oh no, I'm so sorry.\n"
        with patch.object(judge, "_judge_turn", return_value={"is_question": False}) as m:
            judge.score_transcript(transcript, api_key="x")
        # _judge_turn(turn, prior_user, api_key)
        args = m.call_args
        self.assertEqual(args.args[0], "oh no, I'm so sorry.")
        self.assertEqual(args.args[1], "my dog died")


if __name__ == "__main__":
    unittest.main()
