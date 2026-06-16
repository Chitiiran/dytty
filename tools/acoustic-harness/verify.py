#!/usr/bin/env python3
"""Verify voice test results by parsing a logcat session log.

Usage:
    python verify.py --log session.log --scenario basic-call-liveness --scripts test-scripts.json --tag DYTTY
    python verify.py --log session.log --scenario basic-call-liveness --scripts test-scripts.json --tag DYTTY --json

Tag resolution: --tag flag > ACOUSTIC_TAG env var > error (no default).

Parses tagged lines from logcat and checks:
  - Call connected (state: active)
  - User transcript recognized (fuzzy match against expected text)
  - AI responded
  - Tool calls fired (if expected)
  - Call ended cleanly (state: idle)
  - No errors

Exit codes:
    0 — All assertions passed
    1 — One or more assertions failed
    2 — Error (file not found, scenario not found, tag not set, etc.)
"""

import argparse
import json
import os
import re
import sys
from difflib import SequenceMatcher


def resolve_tag(flag_value: str | None, required: bool = True) -> str | None:
    """Resolve the logcat tag from --tag flag or ACOUSTIC_TAG env var.

    If required=True (default), exits with code 2 if neither is set.
    If required=False, returns None when not set.
    """
    if flag_value:
        return flag_value
    env_tag = os.environ.get("ACOUSTIC_TAG")
    if env_tag:
        return env_tag
    if required:
        print("ERROR: --tag flag or ACOUSTIC_TAG env var is required")
        sys.exit(2)
    return None


def parse_logcat(log_path: str, tag: str) -> tuple[list[dict], list[str]]:
    """Parse log file into structured events and raw lines.

    Filters for lines containing [tag] marker. Returns (events, raw_lines)
    where events are structured and raw_lines are all lines.
    """
    tag_marker = f"[{tag}]"
    events: list[dict] = []
    raw_lines: list[str] = []

    with open(log_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            raw_lines.append(line)

            if tag_marker not in line:
                continue

            match = re.search(re.escape(tag_marker) + r" (.+)", line)
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
            elif msg.startswith("Entry saved: "):
                # #224: "Entry saved: <category> (origin: <origin>)"
                m = re.match(r"Entry saved: (\w+) \(origin: ([\w-]+)\)", msg)
                if m:
                    events.append({
                        "type": "entry_saved",
                        "category": m.group(1),
                        "origin": m.group(2),
                    })
            elif msg.startswith("Entry reworded: "):
                # #224: "Entry reworded: <category>"
                m = re.match(r"Entry reworded: (\w+)", msg)
                if m:
                    events.append({
                        "type": "entry_reworded",
                        "category": m.group(1),
                    })
            elif msg.startswith("Reconciliation complete: "):
                # #224: "Reconciliation complete: <n> added, <m> reworded"
                m = re.match(
                    r"Reconciliation complete: (\d+) added, (\d+) reworded", msg
                )
                if m:
                    events.append({
                        "type": "reconciliation_complete",
                        "added": int(m.group(1)),
                        "reworded": int(m.group(2)),
                    })

    return events, raw_lines


def fuzzy_match(
    expected: str, actual: str, threshold: float = 0.8
) -> tuple[bool, float]:
    """Compare expected and actual text with fuzzy matching.

    Returns (passed, similarity_ratio).
    """
    ratio = SequenceMatcher(None, expected.lower(), actual.lower()).ratio()
    return ratio >= threshold, ratio


def score_recall(expected_items: list[dict], saved_events: list[dict]) -> dict:
    """Deterministic multi-item recall metric (#231).

    expected_items: [{"category": str, "anchor": str}]. The anchor is unused
        here (kept for future span-level matching); recall is category-multiset
        based.
    saved_events: parsed "entry_saved" events [{"type", "category", "origin"}].

    Returns recall (captured / expected by category multiset), category_accuracy
    (fraction of saved entries whose category was expected), and over_split /
    hallucination guard flags.
    """
    from collections import Counter

    expected_cats = Counter(e["category"] for e in expected_items)
    saved_cats = Counter(
        e["category"] for e in saved_events if e.get("type") == "entry_saved"
    )

    total_expected = sum(expected_cats.values())
    captured = sum(min(expected_cats[c], saved_cats.get(c, 0)) for c in expected_cats)
    recall = 1.0 if total_expected == 0 else captured / total_expected

    total_saved = sum(saved_cats.values())
    correct_saved = sum(
        min(saved_cats[c], expected_cats.get(c, 0)) for c in saved_cats
    )
    category_accuracy = 1.0 if total_saved == 0 else correct_saved / total_saved

    over_split = any(saved_cats.get(c, 0) > expected_cats[c] for c in expected_cats)
    hallucination = total_expected == 0 and total_saved > 0

    return {
        "recall": round(recall, 3),
        "category_accuracy": round(category_accuracy, 3),
        "captured": captured,
        "expected": total_expected,
        "over_split": over_split,
        "hallucination": hallucination,
    }


def _check_tool_calls(raw_lines: list[str], tool_name: str) -> bool:
    """Check raw logcat lines for tool call invocations.

    Tool calls are logged without the app tag, so we search raw lines.
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
    if not user_final_transcripts:
        user_final_transcripts = [
            e for e in events if e["type"] == "user_transcript"
        ]

    ai_transcripts = [e for e in events if e["type"] == "ai_transcript"]
    turn_completes = [e for e in events if e["type"] == "turn_complete"]

    all_user_text = " ".join(t["text"] for t in user_final_transcripts)

    for i, utterance in enumerate(scenario["utterances"]):
        expect = utterance["expect"]
        prefix = f"Utterance {i + 1}"

        # Check user transcript recognized
        min_acc = expect.get("min_accuracy", 0.8)
        if user_final_transcripts:
            passed, ratio = fuzzy_match(utterance["text"], all_user_text, min_acc)
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

        # #224: entry count + category checks. entry_saved covers both in-call
        # and reconciled-add origins, so this validates the full hybrid pipeline.
        saved_events = [e for e in events if e["type"] == "entry_saved"]
        saved_categories = [e["category"] for e in saved_events]

        if "min_entries" in expect:
            want = expect["min_entries"]
            got = len(saved_events)
            results.append({
                "check": f"{prefix}: entries captured (>= {want})",
                "passed": got >= want,
                "detail": (
                    "OK"
                    if got >= want
                    else f"Expected >= {want}, saw {got}: {saved_categories}"
                ),
            })

        if "expected_categories" in expect:
            want_cats = expect["expected_categories"]
            missing = [c for c in want_cats if c not in saved_categories]
            results.append({
                "check": f"{prefix}: expected categories present",
                "passed": not missing,
                "detail": (
                    "OK"
                    if not missing
                    else f"Missing {missing}; saw {saved_categories}"
                ),
            })

        # #231: deterministic multi-item recall metric. Passes when no
        # over-split / hallucination guard trips; recall/cat_acc surface in JSON.
        if "expected_items" in expect:
            recall = score_recall(expect["expected_items"], saved_events)
            results.append({
                "check": f"{prefix}: multi-item recall",
                "passed": not recall["over_split"] and not recall["hallucination"],
                "detail": (
                    f"recall={recall['recall']} "
                    f"cat_acc={recall['category_accuracy']} "
                    f"captured={recall['captured']}/{recall['expected']} "
                    f"over_split={recall['over_split']} "
                    f"hallucination={recall['hallucination']}"
                ),
                "metrics": recall,
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
        "--scenario", required=True, help="Scenario name from test-scripts JSON"
    )
    parser.add_argument(
        "--scripts", required=True, help="Path to test-scripts.json"
    )
    parser.add_argument(
        "--tag",
        default=None,
        help="Logcat tag to filter for (fallback: ACOUSTIC_TAG env var)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON (for CI integration)",
    )
    args = parser.parse_args()

    tag = resolve_tag(args.tag)

    if not os.path.exists(args.log):
        print(f"ERROR: Log file not found: {args.log}")
        sys.exit(2)

    if not os.path.exists(args.scripts):
        print(f"ERROR: Scripts file not found: {args.scripts}")
        sys.exit(2)

    with open(args.scripts, "r", encoding="utf-8") as f:
        data = json.load(f)

    scenario = next(
        (s for s in data["scenarios"] if s["name"] == args.scenario), None
    )
    if not scenario:
        available = [s["name"] for s in data["scenarios"]]
        print(f"ERROR: Scenario '{args.scenario}' not found")
        print(f"Available: {', '.join(available)}")
        sys.exit(2)

    events, raw_lines = parse_logcat(args.log, tag=tag)
    print(f"Parsed {len(events)} [{tag}] events from {args.log}")

    results = verify_scenario(events, raw_lines, scenario)

    if args.json:
        output = {
            "scenario": args.scenario,
            "passed": all(
                r["passed"] for r in results if r["passed"] is not None
            ),
            "results": results,
        }
        print(json.dumps(output, indent=2))
        sys.exit(0 if output["passed"] else 1)
    else:
        passed = print_report(results, args.scenario)
        sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
