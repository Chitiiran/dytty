# Dytty — Backlog

> Feature requests and bugs, tracked separately from milestones.
> Prioritized by impact and urgency. Pulled into work based on current milestone context.
>
> **Priority levels:**
> - **P0**: Broken/blocking — fix immediately regardless of milestone
> - **P1**: Affects daily use — fix during current milestone
> - **P2**: Important but not urgent — next milestone or when capacity allows
> - **P3**: Nice to have — when time permits
>
> All open issues tracked on GitHub. IDs below link to GitHub issue numbers.

---

## Bugs

| GH# | Priority | Summary | Labels | Status |
|-----|----------|---------|--------|--------|
| [#50](https://github.com/Chitiiran/dytty/issues/50) | P0 | Voice note with no clear category hangs on LLM categorization | bug | Open |
| [#24](https://github.com/Chitiiran/dytty/issues/24) | P0 | Voice call stuck at "ready to connect" with no active call feedback | bug | Open |
| [#25](https://github.com/Chitiiran/dytty/issues/25) | P0 | End-call button has no clear affordance — user unknowingly hangs up | bug, ux-ui | Open |
| [#26](https://github.com/Chitiiran/dytty/issues/26) | P0 | Push notifications not delivered when app is closed | bug, ux-ui | Open |
| [#35](https://github.com/Chitiiran/dytty/issues/35) | P0 | STT cuts off mid-speech due to short silence timeout | bug | Open |
| [#49](https://github.com/Chitiiran/dytty/issues/49) | P1 | Category icons greyed out on app restart until interaction | bug, state-management | Open |
| [#27](https://github.com/Chitiiran/dytty/issues/27) | P2 | App version stuck at 0.1.0, not incrementing across releases | bug | Open |
| [#28](https://github.com/Chitiiran/dytty/issues/28) | P2 | Emulator toggle visible in production build | bug | Open |
| [#29](https://github.com/Chitiiran/dytty/issues/29) | P2 | Re-signing in with Google does not show account picker | bug | Open |
| [#30](https://github.com/Chitiiran/dytty/issues/30) | P2 | Write-journal and voice FABs overlap on journal screen | bug, ux-ui | Open |

---

## Feature Requests

| GH# | Priority | Summary | Labels | Status |
|-----|----------|---------|--------|--------|
| [#32](https://github.com/Chitiiran/dytty/issues/32) | P0 | Voice note review & edit screen before saving | feature, ux-ui | Open |
| [#1](https://github.com/Chitiiran/dytty/issues/1) | P2 | Onboarding flow with custom categories | feature | Open |
| [#2](https://github.com/Chitiiran/dytty/issues/2) | P2 | App logo and branding | feature, ux-ui | Open |
| [#34](https://github.com/Chitiiran/dytty/issues/34) | P2 | Replace minidot with completion ring that fills as entries are added | feature, ux-ui, state-management | Open |
| [#36](https://github.com/Chitiiran/dytty/issues/36) | P2 | Category settings page with change history strategy | feature, product-decision | Open |
| [#37](https://github.com/Chitiiran/dytty/issues/37) | P2 | Rotating journal prompts that vary per session | feature, ux-ui | Open |
| [#38](https://github.com/Chitiiran/dytty/issues/38) | P2 | Granular microphone permission flow per use-case | feature, ux-ui | Open |
| [#39](https://github.com/Chitiiran/dytty/issues/39) | P2 | Tap anywhere on empty journal tab to add entry | feature, ux-ui | Open |
| [#31](https://github.com/Chitiiran/dytty/issues/31) | P3 | Should future date journaling be allowed? | feature, product-decision | Open |
| [#40](https://github.com/Chitiiran/dytty/issues/40) | P3 | Jira-style avatar selector and randomized username | feature, ux-ui | Open |
| [#41](https://github.com/Chitiiran/dytty/issues/41) | P3 | Surface crisis support line when suicidal content is detected | feature, product-decision | Open |

---

## Chores

| GH# | Priority | Summary | Labels | Status |
|-----|----------|---------|--------|--------|
| [#43](https://github.com/Chitiiran/dytty/issues/43) | P2 | Investigate and reduce app bundle size | chore | Open |

---

## Completed

| GH# | Summary | Resolved |
|-----|---------|----------|
| #20 | Calendar minidot not updating for today's entry in real-time | 2026-03-15 (#44) |
| #21 | "You haven't journaled today" CTA persists after entry is added | 2026-03-15 (#44) |
| #22 | Category completion symbols stale after entry is added | 2026-03-15 (#44) |
| #23 | Voice note from CTA not saved to journal correctly | 2026-03-15 (#44) |
| #42 | Audit JournalBloc state emissions for real-time UI refresh | 2026-03-15 (#44) |
| B-001 | Journal entry not visible until page re-entry | 2026-03-12 |
| F-001 | Fixed-time daily notification | 2026-03-12 |
| F-002 | Home screen CTA nudge (always-on) | 2026-03-12 |
