# Feedback to Issues Process

> Standard process for converting raw user/tester feedback into actionable GitHub Issues.

---

## 1. Capture Raw Feedback

Save the raw, unedited feedback immediately to:

```
docs/planning/feedback/YYYY-MM-DD-user-feedback.md
```

Format:
```markdown
# User Feedback — YYYY-MM-DD

Raw, unedited feedback from user testing session.
Issues derived from this feedback are tracked on GitHub (#NN–#NN).

---

[paste feedback verbatim, one item per paragraph]
```

Rules:
- Never edit the raw feedback — preserve the tester's exact words
- One file per session, dated
- Add issue reference range at the top once issues are created

---

## 2. Triage: Parse Into Items

Read through the feedback and identify discrete items. Each item is one of:

| Type | Description | Action |
|------|-------------|--------|
| **Bug** | Something broken or not working as expected | Create issue |
| **Feature request** | New functionality or UX change | Create issue |
| **Question** | Tester asking about behavior or data | Answer directly, no issue |
| **Positive confirmation** | Something works well | Note for morale, no issue |
| **Duplicate** | Already tracked in an existing issue | Update existing issue |

---

## 3. Review One-by-One

Do NOT batch-create issues. Review each item with the user:

1. **Propose** — Claude suggests: title, labels, priority, milestone, dependencies, body
2. **User reviews** — approves or amends
3. **Create** — only after approval

This ensures:
- Correct priority from the person who understands the product
- Dependencies are captured (what blocks what)
- Product decisions are flagged, not assumed
- Duplicates are caught and merged into existing issues

---

## 4. Issue Template

```markdown
## User Feedback
[What the tester said, paraphrased with context]

## Acceptance Criteria
- [ ] [Specific, testable criteria]

## Dependencies
- Blocked by #NN (description)
- Blocks #NN (description)
```

### Labels (pick all that apply)

**Type** (required, pick one):
- `bug` — something broken
- `feature` — new functionality
- `chore` — maintenance, CI, config
- `refactor` — code improvement, no behavior change

**Priority** (required, pick one):
- `P0-critical` — must fix immediately
- `P1-important` — fix during current milestone
- `P2-nice-to-have` — next milestone or when capacity allows
- `P3-someday` — when time permits

**Area** (optional, pick any):
- `ux-ui` — user experience and interface
- `state-management` — bloc/state emission issues
- `product-decision` — needs design/product decision before implementation

### Milestones

Assign to the milestone where the work fits:

| Milestone | Focus |
|-----------|-------|
| M3: Voice Call Prototypes | Voice input, STT, LLM integration |
| M4: Daily Call | Scheduled voice call feature |
| M5: Weekly Review | Summary and review features |
| M6: Configurable Categories + Polish | UX polish, customization, GenUI |
| M7: Launch Prep | Final polish, landscape, bundle size |

---

## 5. Dependencies

Track issue dependencies in the issue body using:

```markdown
## Dependencies
- Blocked by #NN (short reason)
- Blocks #NN (short reason)
```

Common dependency patterns:
- **GenUI blocker** — UX features that should wait for GenUI framework
- **Product decision** — needs user/stakeholder input before implementation
- **Quick fix first** — ship a simple fix now, full solution later (e.g., #57 portrait lock before #58 landscape support)

---

## 6. After Triage

- Update `docs/planning/BACKLOG.md` with new issues
- Update `PROGRESS.md` if any items affect current work
- Commit feedback file and backlog updates

---

## 7. Claude-Specific Instructions

When processing feedback:
1. **Save raw feedback first** — before any triage
2. **Check for duplicates** — search existing issues before creating new ones
3. **One at a time** — propose each issue individually, wait for approval
4. **Don't assume priority** — always let the user set priority
5. **Flag product decisions** — if an item requires a design choice, add the `product-decision` label
6. **Link dependencies** — always note what blocks what
7. **Answer questions inline** — not everything needs an issue
