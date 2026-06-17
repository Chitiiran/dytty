#!/usr/bin/env python3
"""Question-quality LLM-judge for daily-call transcripts (#231, opt-in).

Scores each AI turn on a fixed rubric (warm / relevant / sparing /
open-not-why / reflects-before-asking) and computes aggregates
(reflection:question ratio, % turns ending on a question, why-question count).

Non-deterministic (LLM-dependent) — isolated from verify.py's deterministic
recall gate. Runs post-run, behind a flag.

Usage:
    python judge.py --transcript call.txt --json
"""

import argparse
import json
import os
import sys

RUBRIC_KEYS = [
    "warm",
    "relevant_to_prior",
    "sparing",
    "open_not_why",
    "reflects_before_asking",
]

JUDGE_INSTRUCTION = """You are scoring ONE turn from an AI journaling companion
whose goal is to listen warmly and draw the user out WITHOUT interrogating.

Score the AI turn 0.0-1.0 on each axis and return JSON only:
- warm: gentle, friend-like tone (not clinical)
- relevant_to_prior: responds to what the user just said
- sparing: not interrogating; a reflection/backchannel scores high, a stacked
  or pushy question scores low
- open_not_why: if it asks, the question is open ("what/how") not "why" and not
  closed yes/no. If it asks nothing, score 1.0.
- reflects_before_asking: acknowledges/reflects before any question
Also return booleans: is_question, ends_on_question, is_why.
Few-shot:
  AI: "oh that sounds heavy. what made it rough?" ->
     warm 1, relevant 1, sparing 1, open_not_why 1, reflects_before_asking 1,
     is_question true, ends_on_question true, is_why false
  AI: "why did you do that?" ->
     warm 0.4, sparing 0.3, open_not_why 0, is_question true, is_why true
  AI: "mm, that's a lot." ->
     is_question false, ends_on_question false, sparing 1, open_not_why 1
"""


def parse_ai_turns(transcript: str) -> list[str]:
    """Extract AI turn texts from a 'You:'/'AI:' line-formatted transcript."""
    turns = []
    for line in transcript.splitlines():
        line = line.strip()
        if line.startswith("AI:"):
            turns.append(line[len("AI:"):].strip())
    return turns


def _judge_turn(turn: str, prior_user: str, api_key: str) -> dict:
    """Call Gemini to score one turn. Returns the rubric dict.

    Uses google-generativeai if available; structured output, temperature 0.
    Isolated so tests patch it (no import cost at module load).
    """
    import google.generativeai as genai

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel("gemini-2.5-flash")
    prompt = (
        f"{JUDGE_INSTRUCTION}\n\nPrevious user line: {prior_user!r}\n"
        f"AI turn to score: {turn!r}\n\nReturn JSON only."
    )
    resp = model.generate_content(
        prompt,
        generation_config={
            "temperature": 0.0,
            "response_mime_type": "application/json",
        },
    )
    return json.loads(_strip_fences(resp.text))


def _strip_fences(text: str) -> str:
    """Strip a markdown ```json ... ``` fence if present.

    Gemini occasionally wraps JSON in a code fence even with
    response_mime_type=application/json; json.loads would then raise. (#232)
    """
    text = text.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    return text


def aggregate(per_turn: list[dict]) -> dict:
    """Aggregate per-turn rubric scores into call-level metrics."""
    n = len(per_turn) or 1
    questions = [t for t in per_turn if t.get("is_question")]
    reflections = [t for t in per_turn if not t.get("is_question")]
    nq = len(questions)
    ratio = (len(reflections) / nq) if nq else float(len(reflections))
    ending = sum(1 for t in per_turn if t.get("ends_on_question"))
    whys = sum(1 for t in per_turn if t.get("is_why"))
    avg = {
        k: round(sum(t.get(k, 0.0) for t in per_turn) / n, 3) for k in RUBRIC_KEYS
    }
    return {
        **avg,
        "reflection_question_ratio": round(ratio, 3),
        "pct_turns_ending_on_question": round(ending / n, 3),
        "why_question_count": whys,
        "turns": len(per_turn),
    }


def score_transcript(transcript: str, api_key: str) -> dict:
    """Score every AI turn in a transcript and aggregate.

    Walks lines in order so each AI turn is scored with the user line that
    immediately preceded it (relevant_to_prior context).
    """
    per_turn = []
    prior_user = ""
    for line in transcript.splitlines():
        s = line.strip()
        if s.startswith("You:"):
            prior_user = s[len("You:"):].strip()
        elif s.startswith("AI:"):
            turn = s[len("AI:"):].strip()
            per_turn.append(_judge_turn(turn, prior_user, api_key))
    return {"per_turn": per_turn, "aggregate": aggregate(per_turn)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript", required=True)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    key = os.environ.get("GEMINI_API_KEY") or os.environ.get("FIREBASE_WEB_API_KEY")
    if not key:
        print("ERROR: GEMINI_API_KEY env var required", file=sys.stderr)
        sys.exit(2)
    with open(args.transcript, encoding="utf-8", errors="replace") as f:
        result = score_transcript(f.read(), key)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(json.dumps(result["aggregate"], indent=2))


if __name__ == "__main__":
    main()
