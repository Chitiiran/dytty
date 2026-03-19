# ADR-008: Category Detail Page — UI Design & Review Call Decisions

## Status
Accepted

## Context
Issue #71 introduces a Category Detail Page accessible from Today's Progress icons. This page shows entries for a single category and enables AI-powered review calls via Gemini Live. Design decisions were needed for layout, interaction patterns, and review call behavior.

## Decisions

### UI Layout & Navigation
1. **Full-screen page** with back arrow (not bottom sheet/modal). New route: `/category-detail`.
2. **Both filled and unfilled** category icons in Today's Progress are tappable — unfilled opens the page with empty state.
3. **Call icon disabled/greyed out** when there are zero entries for the past 7 days.

### Entry Cards
4. **Rolling 7-day window** — shows entries from the past 7 days, not a fixed week. Days with multiple entries grouped under a **collapsible** date header ("Today — 3 entries"). Collapsed by default for days with many entries, expanded for recent days.
5. **Card content**: Entry text (transcript or summary if summarized), relative date ("3 days ago"), source icon (voice/text — included but removable if awkward). Tap to expand for truncated entries.
6. **Original transcript easter egg**: Tapping the text field toggles between summary and original transcript. No visible button — discoverable interaction.
7. **Past entries on scroll**: Entries older than 7 days are visible when scrolling down, rendered with subtly greyed styling to indicate "in the past."
8. **Inline editing**: Tapping an entry card makes the text editable in-place (not a bottom sheet). Save triggers: tap outside the card (auto-save), small checkmark that appears during edit, or keyboard "done" key — all three work.
9. **Scroll position**: Page lands at the most recent entry (top of list), not at the review summary card.

### AI Review Call
9. **Call UI overlay**: Entry list remains scrollable during the call. No full grey tint — instead, subtle color shift to indicate call-active state. User can still read and reflect on entries.
10. **Call badge**: Green (idle) → Red (active). Icon in top section.
11. **Review scope**: AI reviews current 7-day entries but can reference older entries to help user reflect and spot trends.
12. **Entry save & edit during call**: AI can create new entries and edit existing entries via tool calls (extends existing `save_entry` tool pattern).
13. **Live entry updates during call**: When AI creates or edits an entry mid-call, it appears/updates in the list immediately with a subtle animation (consistent with existing optimistic update pattern).
14. **Post-call artifacts**:
    - Full call audio saved to Firebase Cloud Storage
    - Entries created/edited during call are persisted
    - Reviewed entries marked with a **badge** indicator (small visual badge on the entry card)
    - **Review summary card** added above entries — summarizes how well user did on the two category questions, uses user's own words, keeps tone positive
15. **Review summary card persistence**: One review card per category per week. Multiple review sessions in the same week are condensed into a single card (updated, not duplicated). Card persists permanently.

### Category-Specific Review Questions

| Category | Q1 | Q2 |
|----------|----|----|
| **Positive** | Is the feeling lasting? | Did you take action on this feeling? |
| **Negative** | Is the feeling lasting — same intensity? | Did you take action toward resolving or cherishing it? |
| **Gratitude** | Grateful for good things, and that bad things weren't the worst? | Is your ability to be grateful improving? |
| **Beauty** | Appreciating good things daily? | Appreciating beyond visual — taste, sound, other senses? |
| **Identity** | Overall identity for the week based on entries? | Which to adopt more, which to forgo? |

## Consequences

### Easier
- Natural entry point for per-category AI review — no separate "weekly review" screen needed initially
- Inline editing reduces navigation friction
- Review summary card gives users a tangible takeaway per category
- Scrollable entries during call supports reflection-while-talking

### Harder
- Inline editing is more complex than bottom sheet (focus management, keyboard handling, optimistic updates in-place)
- Subtle call-active styling needs careful design to be noticeable but not distracting
- `save_entry` and new `edit_entry` tool calls during review require extending VoiceCallBloc
- "Reviewed" marker and review summary card are new data model additions (CategoryEntry needs `reviewed` flag, new ReviewSummary model)

### Supersedes
- This supersedes #55 (make category icons tappable) — that feature is now a subset of this work.
