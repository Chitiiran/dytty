# Category Detail Page with Entry Browsing & AI Review Call (#71)

## Context
Issue #71 introduces a full-screen Category Detail Page accessible by tapping category icons in Today's Progress. This page displays entries for a single category across a rolling 7-day window, supports inline editing, and enables AI-powered review calls via Gemini Live with category-specific questions. Design decisions are captured in ADR-008.

This work also lays the foundation for #73 (talk to AI about entries) and #70 (weekly summary).

---

## Phase 1: Data Layer — Models, Repository, Review Questions

### New Files
- **`lib/core/constants/review_questions.dart`** — Static `Map<String, List<String>>` mapping category IDs to their two review questions
- **`lib/data/models/review_summary.dart`** — `ReviewSummary` model (id, categoryId, weekStart, summary, audioUrl?, createdAt, updatedAt). Firestore serialization. `weekStart` is the Monday of the week.

### Modified Files
- **`lib/data/models/category_entry.dart`** — Add `bool isReviewed` field (default `false`). Update `fromFirestore`/`toFirestore`/`props`/constructor. Backward-compatible (missing field = false).
- **`lib/data/repositories/journal_repository.dart`** — Add methods:
  - `getCategoryEntriesForDateRange(String categoryId, List<String> dates)` — For each date, query `categoryEntries` subcollection filtered by `category == categoryId`. Returns `Map<String, List<CategoryEntry>>` keyed by date. (N queries where N = number of dates with entries; avoids needing collection group index.)
  - `markEntryReviewed(String date, String entryId)` — Sets `isReviewed: true` on the entry doc.
  - `saveReviewSummary(ReviewSummary summary)` — Upsert to `users/{uid}/reviewSummaries/` collection. Query by categoryId + weekStart; update if exists, create if not.
  - `getReviewSummary(String categoryId, String weekStart)` — Fetch review summary for a category and week.

### Why N-query approach (not collection group)
Collection group queries on `categoryEntries` would require adding a `date` field to every entry doc (migration) plus a composite Firestore index. The N-query approach (one per date in the 7-day window) is simpler — max 7 queries, and we already have `daysWithEntries` to skip empty dates.

### Tests First
- `test/core/constants/review_questions_test.dart` — All 5 categories have exactly 2 questions
- `test/data/models/review_summary_test.dart` — Serialization round-trip, defaults
- `test/data/models/category_entry_test.dart` — Add tests for `isReviewed` serialization (true, false, missing)
- `test/data/repositories/journal_repository_test.dart` — Tests for all 4 new methods using `FakeFirebaseFirestore`

---

## Phase 2: CategoryDetailBloc — State Management

### New Files
- **`lib/features/category_detail/bloc/category_detail_bloc.dart`** — Events, state, bloc
- **`lib/features/category_detail/bloc/category_detail_event.dart`** (or inline in bloc file)
- **`lib/features/category_detail/bloc/category_detail_state.dart`** (or inline in bloc file)

### State Design
```dart
enum CategoryDetailStatus { initial, loading, loaded, error }

class DateGroup {
  final String date;           // "2026-03-18"
  final String displayDate;    // "Today", "Yesterday", "3 days ago", "Mar 12"
  final List<CategoryEntry> entries;
  final bool isCollapsed;      // collapsible headers
}

class CategoryDetailState {
  final CategoryDetailStatus status;
  final String categoryId;
  final List<DateGroup> recentEntries;    // last 7 days
  final List<DateGroup> olderEntries;     // beyond 7 days (lazy loaded)
  final ReviewSummary? reviewSummary;
  final bool hasRecentEntries;            // controls call icon enabled/disabled
  final String? editingEntryId;           // which entry is in inline-edit mode
  final String? error;
}
```

### Events
- `LoadCategoryDetail(String categoryId)` — Fetches rolling 7-day entries + review summary
- `LoadOlderEntries()` — Paginates beyond 7 days
- `ToggleDateGroup(String date)` — Expand/collapse a date group
- `StartInlineEdit(String entryId)` — Enter edit mode for an entry
- `SaveInlineEdit(String date, String entryId, String newText)` — Persist edit
- `CancelInlineEdit()` — Exit edit mode
- `EntryAddedFromCall(CategoryEntry entry)` — Live entry from review call
- `EntryEditedFromCall(String entryId, String newText)` — Edit from review call
- `MarkEntriesReviewed(List<String> entryIds, List<String> dates)` — Post-call badge
- `SaveReviewSummary(ReviewSummary summary)` — Post-call summary card

### Implementation Notes
- Uses `JournalRepository` for data access (injected)
- `LoadCategoryDetail`: Gets `daysWithEntries` for current + previous month, filters to last 7 days, calls `getCategoryEntriesForDateRange` with those dates
- Optimistic updates for inline edits (update state immediately, then Firestore)
- Dispatches `UpdateEntry` to `JournalBloc` to keep single-date state in sync

### Tests First
- `test/features/category_detail/bloc/category_detail_bloc_test.dart` — Using `blocTest` pattern:
  - Load entries groups correctly by date with relative labels
  - Empty state when no entries
  - Collapsible toggle works
  - Inline edit starts/saves/cancels
  - Review summary loads
  - Live entry from call appears in correct date group
  - Call icon disabled when no recent entries

---

## Phase 3: GeminiLiveService — Parameterized Connect + edit_entry Tool

### Modified Files
- **`lib/services/voice_call/gemini_live_service.dart`**:
  - Change `connect()` signature to accept optional parameters:
    ```dart
    Future<void> connect({
      String? systemPrompt,
      List<FunctionDeclaration>? tools,
    })
    ```
  - Default to existing `_systemPrompt` and `[_saveEntryDeclaration]` when params are null (backward-compatible)
  - Add `_editEntryDeclaration` as a static `FunctionDeclaration`:
    ```dart
    static final editEntryDeclaration = FunctionDeclaration(
      'edit_entry',
      'Edit an existing journal entry...',
      parameters: {
        'entry_id': Schema.string(description: 'ID of the entry to edit'),
        'text': Schema.string(description: 'New text for the entry'),
      },
    );
    ```
  - Make both declarations public static so callers can compose tool lists

- **`lib/features/voice_call/bloc/voice_call_bloc.dart`**:
  - Add handling for `edit_entry` tool call in `_onToolCallReceived`:
    - Extract `entry_id` and `text` from args
    - Dispatch `UpdateEntry` to `JournalBloc`
    - Acknowledge tool call
  - Keep existing daily call behavior unchanged

### New File
- **`lib/core/constants/review_prompts.dart`** — Function to build category-specific review system prompt:
  ```dart
  String buildReviewPrompt(String categoryName, List<String> questions, List<CategoryEntry> entries)
  ```
  Includes: role (review companion), the two questions, entry context, instructions to use `save_entry` and `edit_entry` tools.

### Tests First
- `test/services/voice_call/gemini_live_service_test.dart` — Test that connect accepts custom params (mock FirebaseAI)
- `test/features/voice_call/voice_call_bloc_test.dart` — Add test for `edit_entry` tool call dispatching UpdateEntry
- `test/core/constants/review_prompts_test.dart` — Prompt includes questions and entry text

---

## Phase 4: Category Detail Page — UI Shell (No Call Yet)

### New Files
- **`lib/features/category_detail/category_detail_screen.dart`** — Main screen widget
- **`lib/features/category_detail/widgets/`**:
  - `category_detail_header.dart` — Top section: back button, category name, icon + call badge
  - `review_summary_card.dart` — Card showing review summary (above entries)
  - `date_group_header.dart` — Collapsible header: "Today — 3 entries" with expand/collapse chevron
  - `inline_entry_tile.dart` — Entry card: text (tap to toggle summary/transcript), source icon, relative date, tap to expand, inline edit mode with checkmark/auto-save
  - `empty_category_state.dart` — Empty illustration + prompt

### Modified Files
- **`lib/app.dart`** — Add route `'/category-detail'` that reads `categoryId` from `RouteSettings.arguments` and creates `CategoryDetailScreen`
- **`lib/features/daily_journal/home_screen.dart`** — Wrap each category icon in `_ProgressCard` with `GestureDetector` -> `Navigator.pushNamed('/category-detail', arguments: cat.id)`

### Widget Behavior Details
- **`inline_entry_tile.dart`**:
  - Display mode: Text (truncated), tap to expand, source icon, relative date
  - Easter egg: `GestureDetector` on text -> toggles between `entry.text` and `entry.transcript`
  - Edit mode: `TextField` replaces text, checkmark button appears, auto-save on focus lost (`FocusNode.addListener`) and keyboard done action
  - Reviewed badge: Small icon/indicator when `entry.isReviewed == true`
  - Greyed styling: Entries in `olderEntries` get reduced opacity

- **`date_group_header.dart`**:
  - Row: relative date label + entry count + chevron icon
  - `GestureDetector` dispatches `ToggleDateGroup(date)` to bloc
  - Animated expand/collapse of children

- **`category_detail_header.dart`**:
  - Call badge: Small green circle overlapping the category icon (like a notification dot)
  - Greyed out when `!hasRecentEntries`

### Tests First
- `test/robots/category_detail_screen_robot.dart` — Robot for finding/asserting on widgets
- `test/widgets/category_detail_screen_test.dart` — Widget tests:
  - Renders category name and icon
  - Shows entries grouped by date
  - Collapsible date headers
  - Empty state when no entries
  - Review summary card when summary exists
  - Inline edit triggers SaveInlineEdit event
  - Transcript toggle (easter egg)
  - Past entries have greyed styling
  - Call icon disabled when no recent entries
- `test/widgets/home_screen_test.dart` — Add test: tapping category icon navigates to `/category-detail`

---

## Phase 5: Embedded Review Call

### Modified Files
- **`lib/features/category_detail/category_detail_screen.dart`**:
  - Create `VoiceCallBloc` when call icon tapped (same pattern as `VoiceCallScreen`)
  - Create `GeminiLiveService` and call `connect(systemPrompt: reviewPrompt, tools: [saveEntry, editEntry])`
  - Manage `AudioRecorder` + `AudioPlaybackService` lifecycle
  - Listen to `VoiceCallBloc` state for:
    - Tool calls -> dispatch `EntryAddedFromCall` / `EntryEditedFromCall` to `CategoryDetailBloc`
    - Status changes -> update call badge color + UI tint
  - **Call active UI**: `AnimatedContainer` with subtle category-color tint on background, entries remain in a scrollable list
  - **Call controls**: Minimal bottom bar (mute, end call) — reuse from VoiceCallScreen or extract shared widget

- **`lib/features/category_detail/widgets/call_controls_overlay.dart`** — Bottom bar: mute toggle + end call FAB. Positioned at bottom, doesn't push entries up.

### New Events on CategoryDetailBloc
- Already defined in Phase 2: `EntryAddedFromCall`, `EntryEditedFromCall`

### Tests First
- `test/widgets/category_detail_screen_test.dart` — Add tests:
  - Tap call icon -> VoiceCallBloc receives StartCall
  - During call: badge turns red, background tint applied
  - End call: badge returns green, tint removed
  - Entry from tool call appears live in list
- `test/features/category_detail/widgets/call_controls_overlay_test.dart`

---

## Phase 6: Post-Call — Review Summary + Reviewed Badge

### Modified Files
- **`lib/features/category_detail/category_detail_screen.dart`** — After `VoiceCallStatus.ended`:
  1. Generate review summary via `LlmService.generateResponse()` with prompt including the two review questions + call transcript + user's entries. Tone: positive, uses user's words.
  2. Save `ReviewSummary` to Firestore via `CategoryDetailBloc.add(SaveReviewSummary(...))`
  3. Mark all 7-day entries as reviewed via `CategoryDetailBloc.add(MarkEntriesReviewed(...))`
  4. Upload call audio via `AudioStorageService`

- **`lib/features/category_detail/widgets/review_summary_card.dart`** — Display: summary text, date generated, category color accent

- **`lib/features/category_detail/widgets/inline_entry_tile.dart`** — Show reviewed badge (small checkmark or star icon) on entries where `isReviewed == true`

### Tests First
- `test/features/category_detail/bloc/category_detail_bloc_test.dart` — Tests for MarkEntriesReviewed and SaveReviewSummary events
- `test/widgets/category_detail_screen_test.dart` — Post-call: summary card appears, entries show reviewed badge

---

## Phase 7: Integration & Polish

- Wire everything together end-to-end
- Entry animations during call (use existing animation patterns)
- Ensure `JournalBloc` stays in sync when entries are modified from CategoryDetailBloc
- Handle edge cases: call disconnects unexpectedly, no LLM service available, empty review summary
- Verify dark mode styling

### Tests
- Full integration widget test: home -> tap icon -> see entries -> start call -> end call -> see summary
- Maestro E2E flow (if time permits)

---

## File Summary

### New Files (14)
| File | Purpose |
|------|---------|
| `lib/core/constants/review_questions.dart` | Category review question pairs |
| `lib/core/constants/review_prompts.dart` | Review call system prompt builder |
| `lib/data/models/review_summary.dart` | ReviewSummary model |
| `lib/features/category_detail/bloc/category_detail_bloc.dart` | Bloc, events, state |
| `lib/features/category_detail/category_detail_screen.dart` | Main screen |
| `lib/features/category_detail/widgets/category_detail_header.dart` | Top section with call badge |
| `lib/features/category_detail/widgets/review_summary_card.dart` | Weekly review card |
| `lib/features/category_detail/widgets/date_group_header.dart` | Collapsible date header |
| `lib/features/category_detail/widgets/inline_entry_tile.dart` | Entry card with inline edit |
| `lib/features/category_detail/widgets/empty_category_state.dart` | Empty state |
| `lib/features/category_detail/widgets/call_controls_overlay.dart` | Call bottom bar |
| `test/robots/category_detail_screen_robot.dart` | Test robot |
| `test/widgets/category_detail_screen_test.dart` | Widget tests |
| `test/features/category_detail/bloc/category_detail_bloc_test.dart` | Bloc tests |

### Modified Files (6)
| File | Change |
|------|--------|
| `lib/data/models/category_entry.dart` | Add `isReviewed` field |
| `lib/data/repositories/journal_repository.dart` | 4 new methods |
| `lib/services/voice_call/gemini_live_service.dart` | Parameterize `connect()`, add `editEntryDeclaration` |
| `lib/features/voice_call/bloc/voice_call_bloc.dart` | Handle `edit_entry` tool call |
| `lib/features/daily_journal/home_screen.dart` | Category icon tap -> navigate |
| `lib/app.dart` | Add `/category-detail` route |

---

## Verification

1. `flutter analyze` — zero issues
2. `flutter test` — all existing + new tests pass
3. `flutter test --coverage` — coverage stays above 80%
4. Manual: Run app -> tap category icon -> see entries -> inline edit -> start review call -> end call -> see summary card + reviewed badges
5. Dark mode: verify all new widgets respect theme
