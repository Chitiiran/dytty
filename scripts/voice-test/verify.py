#!/usr/bin/env python3
"""Verify voice test results by parsing a logcat session log.

Usage:
    python scripts/voice-test/verify.py --log session.log --scenario basic-call-liveness
    python scripts/voice-test/verify.py --log session.log --scenario basic-call-liveness --json

Parses [DYTTY] tagged lines from logcat and checks:
  - Call connected (state: active)
  - User transcript recognized (fuzzy match against expected text)
  - AI responded
  - Tool calls fired (if expected)
  - Call ended cleanly (state: idle)
  - No errors

Exit codes:
    0 — All assertions passed
    1 — One or more assertions failed
    2 — Error (file not found, scenario not found, etc.)
"""

import argparse
import json
import os
import re
import sys
from difflib import SequenceMatcher

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
SCRIPTS_JSON = os.path.join(
    PROJECT_DIR, "test", "fixtures", "audio", "test-scripts.json"
)


def parse_logcat(log_path: str) -> tuple[list[dict], list[str]]:
    """Parse log file into structured events and raw lines.

    Returns (events, raw_lines) where events are [DYTTY]-tagged structured
    events and raw_lines are all lines (for tool call detection).
    """
    events: list[dict] = []
    raw_lines: list[str] = []

    with open(log_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            raw_lines.append(line)

            if "[DYTTY]" not in line:
                continue

            match = re.search(r"\[DYTTY\] (.+)", line)
            if not match:
                continue

            msg = match.group(1).strip()

            if msg.startswith("Call state: "):
                state = msg.split("Call state: ", 1)[1]
                events.append({"type": "state", "value": state})
            elif msg.startswith("User said: "):
                m = re.match(r"User said: (.+) \(final: (true|false)\)", msg)
                if m:
                    events.append({
                        "type": "user_transcript",
                        "text": m.group(1),
                        "final": m.group(2) == "true",
                    })
            elif msg.startswith("AI said: "):
                m = re.match(r"AI said: (.+) \(final: (true|false)\)", msg)
                if m:
                    events.append({
                        "type": "ai_transcript",
                        "text": m.group(1),
                        "final": m.group(2) == "true",
                    })
            elif msg == "Turn complete":
                events.append({"type": "turn_complete"})

    return events, raw_lines


def fuzzy_match(
    expected: str, actual: str, threshold: float = 0.8
) -> tuple[bool, float]:
    """Compare expected and actual text with fuzzy matching.

    Returns (passed, similarity_ratio).
    """
    ratio = SequenceMatcher(None, expected.lower(), actual.lower()).ratio()
    return ratio >= threshold, ratio


def _check_tool_calls(raw_lines: list[str], tool_name: str) -> bool:
    """Check raw logcat lines for tool call invocations.

    VoiceCallBloc logs tool calls as 'Tool call: <name>' without the
    [DYTTY] tag, so we search raw lines.
    """
    pattern = f"Tool call: {tool_name}"
    return any(pattern in line for line in raw_lines)


def verify_scenario(
    events: list[dict], raw_lines: list[str], scenario: dict
) -> list[dict]:
    """Verify events against scenario expectations. Returns list of results."""
    results: list[dict] = []

    # Check call connected
    state_events = [e for e in events if e["type"] == "state"]
    states = [e["value"] for e in state_events]
    connected = "active" in states
    results.append({
        "check": "Call connected",
        "passed": connected,
        "detail": f"States seen: {states}" if not connected else "OK",
    })

    # Check no errors
    has_error = "error" in states
    results.append({
        "check": "No errors",
        "passed": not has_error,
        "detail": "Error state detected" if has_error else "OK",
    })

    # Collect final transcripts for matching
    user_final_transcripts = [
        e for e in events if e["type"] == "user_transcript" and e["final"]
    ]
    # If no final transcripts, fall back to all user transcripts
    if not user_final_transcripts:
        user_final_transcripts = [
            e for e in events if e["type"] == "user_transcript"
        ]

    ai_transcripts = [
        e for e in events if e["type"] == "ai_transcript"
    ]
    turn_completes = [e for e in events if e["type"] == "turn_complete"]

    # Concatenate all user transcript segments for matching
    # (partial transcripts may arrive as multiple events)
    all_user_text = " ".join(t["text"] for t in user_final_transcripts)

    for i, utterance in enumerate(scenario["utterances"]):
        expect = utterance["expect"]
        prefix = f"Utterance {i + 1}"

        # Check user transcript recognized
        min_acc = expect.get("min_accuracy", 0.8)
        if user_final_transcripts:
            # For multi-utterance, try matching against concatenated text
            # or individual segments
            passed, ratio = fuzzy_match(
                utterance["text"], all_user_text, min_acc
            )
            # Also try individual segments if concatenated didn't match
            if not passed and i < len(user_final_transcripts):
                passed, ratio = fuzzy_match(
                    utterance["text"],
                    user_final_transcripts[i]["text"],
                    min_acc,
                )
            results.append({
                "check": f"{prefix}: User speech recognized",
                "passed": passed,
                "detail": f"Similarity: {ratio:.2f} (threshold: {min_acc})",
            })
        else:
            results.append({
                "check": f"{prefix}: User speech recognized",
                "passed": False,
                "detail": "No user transcript found in logcat",
            })

        # Check AI responded
        if expect.get("ai_responds"):
            ai_responded = len(ai_transcripts) > 0 or len(turn_completes) > 0
            results.append({
                "check": f"{prefix}: AI responded",
                "passed": ai_responded,
                "detail": (
                    "OK"
                    if ai_responded
                    else "No AI transcript or turn complete found"
                ),
            })

        # Check tool call
        if expect.get("tool_call"):
            tool_name = expect["tool_call"]
            found = _check_tool_calls(raw_lines, tool_name)
            results.append({
                "check": f"{prefix}: Tool call '{tool_name}'",
                "passed": found,
                "detail": "OK" if found else f"'{tool_name}' not found in logcat",
            })

    # Check call ended cleanly
    ended = "idle" in states or "disconnecting" in states
    results.append({
        "check": "Call ended cleanly",
        "passed": ended,
        "detail": (
            "OK"
            if ended
            else f"Final states: {states[-2:] if states else 'none'}"
        ),
    })

    return results


def print_report(results: list[dict], scenario_name: str) -> bool:
    """Print verification report. Returns True if all passed."""
    print(f"\n=== Verification: {scenario_name} ===\n")

    all_passed = True
    for r in results:
        if r["passed"] is None:
            icon = "SKIP"
        elif r["passed"]:
            icon = "PASS"
        else:
            icon = "FAIL"
            all_passed = False
        print(f"  {icon}: {r['check']}")
        if r["detail"] != "OK":
            print(f"        {r['detail']}")

    print()
    print(f"Result: {'ALL PASSED' if all_passed else 'FAILED'}")
    return all_passed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify voice test results from logcat"
    )
    parser.add_argument("--log", required=True, help="Path to logcat session log")
    parser.add_argument(
        "--scenario", required=True, help="Scenario name from test-scripts.json"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON (for CI integration)",
    )
    args = parser.parse_args()

    if not os.path.exists(args.log):
        print(f"ERROR: Log file not found: {args.log}")
        sys.exit(2)

    with open(SCRIPTS_JSON, "r", encoding="utf-8") as f:
        data = json.load(f)

    scenario = next(
        (s for s in data["scenarios"] if s["name"] == args.scenario), None
    )
    if not scenario:
        available = [s["name"] for s in data["scenarios"]]
        print(f"ERROR: Scenario '{args.scenario}' not found")
        print(f"Available: {', '.join(available)}")
        sys.exit(2)

    events, raw_lines = parse_logcat(args.log)
    print(f"Parsed {len(events)} [DYTTY] events from {args.log}")

    results = verify_scenario(events, raw_lines, scenario)

    if args.json:
        output = {
            "scenario": args.scenario,
            "passed": all(r["passed"] for r in results if r["passed"] is not None),
            "results": results,
        }
        print(json.dumps(output, indent=2))
        sys.exit(0 if output["passed"] else 1)
    else:
        passed = print_report(results, args.scenario)
        sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
