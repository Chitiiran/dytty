# AI Conversation Quality Eval Harness

Systematically tests the Dytty daily call AI conversation quality using
LLM-as-user + LLM-as-judge methodology.

## How It Works

Three actors coordinate via a Dart CLI orchestrator:

1. **Gemini Flash** (text mode) — the system under test, using the same
   system prompt and tool declarations as the production app
2. **Claude (user persona)** — plays a specific user archetype via tmux session
3. **Claude (judge)** — scores the transcript against a 7-dimension rubric

## Prerequisites

- Firebase project configured (for Gemini API access)
- Claude Code CLI installed with `claude-session-driver` plugin
- WSL with tmux available (`wsl tmux`)

## Usage

```bash
# Single persona
dart run eval/bin/run_eval.dart --persona terse_tal

# All personas
dart run eval/bin/run_eval.dart --all

# Custom turn limit
dart run eval/bin/run_eval.dart --all --max-turns 15
```

## Personas

| Persona | Tests | Behavior |
|---------|-------|----------|
| **Terse Tal** | Follow-up depth, sycophancy | One-word answers, never elaborates |
| **Verbose Vicky** | Multi-category extraction | Long rambling answers spanning 2-3 categories |
| **Resistant Raj** | Transition quality, empathy | Engages on positive, deflects negative |

## Scoring Rubric

7 dimensions scored 1-5:

1. **Conversational Depth** — does the AI probe beyond surface answers?
2. **Question Variety** — diverse question styles or repetitive patterns?
3. **Transition Quality** — natural topic flow or mechanical category march?
4. **Multi-Category Awareness** — catches content spanning multiple categories?
5. **Relational Warmth** — feels like a friend or an interviewer?
6. **Tool Call Accuracy** — correct save_entry calls with right categories?
7. **Conversation Pacing** — natural rhythm or rushed/dragging?

## Output

Results are saved to `eval/results/{timestamp}-{persona}.json` with:
- Full transcript
- All tool calls with arguments
- Dimension scores + overall average
- Judge notes and flagged turns

Console prints a summary table after running all personas.

## Related

- Issue: #122 (conversation quality problems)
- Issue: #134 (this eval harness)
- Spec: `docs/planning/SPEC-134-ai-eval-harness.md`
