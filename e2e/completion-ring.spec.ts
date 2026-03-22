import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

/**
 * Completion Ring E2E tests.
 *
 * The calendar shows a multi-color segmented completion ring per date cell.
 * Each journal category maps to a fixed arc segment. When an entry is added,
 * the corresponding segment fills in with the category's color.
 *
 * The ring is painted via CustomPainter (canvas arcs) so individual segments
 * are not in the accessibility tree. We verify ring behavior through:
 * 1. Progress card state (proxy for category fill state)
 * 2. Nudge banner visibility (proxy for entries-exist state)
 * 3. Screenshots for visual regression
 *
 * Test matrix:
 * - True positive:  ring state matches after add/delete (verified via progress + nudge)
 * - True negative:  empty state shows 0 of 5, nudge visible (no false "filled" ring)
 * - False positive: adding entry to one category doesn't falsely show other categories filled
 * - False negative: deleting all entries returns ring to fully empty state
 */

/** Helper: navigate to journal, add an entry, stay on journal screen */
async function addEntry(
  page: import('@playwright/test').Page,
  categoryName: string,
  text: string,
) {
  await page.getByRole('button', { name: `Add ${categoryName} entry` }).click();
  const textField = page.getByRole('textbox');
  await expect(textField).toBeVisible({ timeout: 10_000 });
  await textField.fill(text);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByLabel(`Journal entry: ${text}`)).toBeVisible({ timeout: 10_000 });
}

/** Helper: navigate to home, verify home screen loaded */
async function goBackToHome(page: import('@playwright/test').Page) {
  await page.goBack();
  await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
  // Wait for ring animation to settle
  await page.waitForTimeout(500);
}

test.describe('Completion ring on calendar', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  // --- TRUE NEGATIVE: Empty state is correctly empty ---
  // Note: overlaps with home-state.spec.ts but serves as ring-specific regression
  // anchor. If the ring feature regresses, this file fails independently.

  test('empty calendar shows 0 of 5 progress and nudge banner (true negative)', async ({ page }) => {
    // Calendar should be visible
    await expect(page.getByLabel('Calendar')).toBeVisible({ timeout: 10_000 });

    // Progress must show 0 of 5 — no categories falsely filled
    await expect(page.getByLabel('Progress 0 of 5')).toBeVisible({ timeout: 10_000 });

    // Nudge banner must be visible — ring should be all-dim
    await expect(page.getByText("You haven't journaled today")).toBeVisible({ timeout: 10_000 });

    // Screenshot: empty ring state
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/ring-empty.png' });
  });

  // --- TRUE POSITIVE: Adding entries fills ring correctly ---

  test('adding one entry updates ring to 1 of 5 (true positive)', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    await addEntry(page, 'Positive Things', 'Ring TP single');
    await goBackToHome(page);

    // Progress must show exactly 1 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Nudge must be gone (journaledToday = true)
    await expect(page.getByText("You haven't journaled today")).not.toBeVisible({ timeout: 10_000 });

    // Screenshot: one segment filled
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/ring-one-segment.png' });
  });

  test('adding entries to multiple categories shows correct count (true positive)', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    await addEntry(page, 'Positive Things', 'Ring TP multi 1');
    await addEntry(page, 'Gratitude', 'Ring TP multi 2');
    await addEntry(page, 'Identity', 'Ring TP multi 3');
    await goBackToHome(page);

    // Progress must show exactly 3 of 5
    await expect(page.getByLabel('Progress 3 of 5')).toBeVisible({ timeout: 10_000 });

    // Screenshot: three segments filled
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/ring-three-segments.png' });
  });

  test('filling all 5 categories shows complete ring (true positive)', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    const categories = [
      { name: 'Positive Things', text: 'Ring complete 1' },
      { name: 'Negative Things', text: 'Ring complete 2' },
      { name: 'Gratitude', text: 'Ring complete 3' },
      { name: 'Beauty', text: 'Ring complete 4' },
      { name: 'Identity', text: 'Ring complete 5' },
    ];
    for (const { name, text } of categories) {
      await addEntry(page, name, text);
    }
    await goBackToHome(page);

    // Progress must show 5 of 5
    await expect(page.getByLabel('Progress 5 of 5')).toBeVisible({ timeout: 10_000 });

    // Screenshot: full ring
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/ring-full.png' });
  });

  // --- FALSE POSITIVE CHECK: One category doesn't falsely fill others ---

  test('adding entry to one category shows exactly 1 of 5, not more (false positive check)', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    await addEntry(page, 'Gratitude', 'Ring FP check');
    await goBackToHome(page);

    // Must be exactly 1, not 2 or more
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Progress 2 of 5')).not.toBeVisible({ timeout: 3_000 });
  });

  test('adding two entries to same category still shows 1 of 5 (false positive check)', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add two entries to the same category
    await addEntry(page, 'Positive Things', 'Ring FP same cat 1');
    await addEntry(page, 'Positive Things', 'Ring FP same cat 2');
    await goBackToHome(page);

    // Ring should show 1 of 5 (one category filled), not 2 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Progress 2 of 5')).not.toBeVisible({ timeout: 3_000 });
  });

  // --- FALSE NEGATIVE CHECK: Deleting returns to empty state ---

  test('deleting only entry returns ring to 0 of 5 and nudge reappears (false negative check)', async ({ page }) => {
    // Add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntry(page, 'Positive Things', 'Ring FN delete');

    // Verify 1 of 5 on home
    await goBackToHome(page);
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Go back to journal and delete the entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await page.getByRole('button', { name: 'Delete entry' }).click();
    await expect(page.getByLabel('Journal entry: Ring FN delete')).not.toBeVisible({ timeout: 10_000 });

    // Go back to home — should be fully empty again
    await goBackToHome(page);
    await expect(page.getByLabel('Progress 0 of 5')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText("You haven't journaled today")).toBeVisible({ timeout: 10_000 });

    // Screenshot: ring back to empty after delete
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/ring-after-delete.png' });
  });

  // --- PERSISTENCE: Ring survives month navigation ---

  test('ring data persists across month navigation (regression check)', async ({ page }) => {
    // Add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntry(page, 'Positive Things', 'Ring persist test');
    await goBackToHome(page);

    // Verify 1 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Navigate to next month — chevron buttons have no accessible name,
    // so we find them within the Calendar group by position.
    // TODO(#142): add semantic labels to chevron buttons, then use getByLabel
    // Layout within Calendar group: [left chevron] [month title] [format toggle] [right chevron]
    const calendarGroup = page.getByLabel('Calendar');
    const rightChevron = calendarGroup.getByRole('button').nth(3);
    await rightChevron.click();
    await page.waitForTimeout(1000);

    // Navigate back to current month
    const leftChevron = calendarGroup.getByRole('button').nth(0); // 1st button = left chevron
    await leftChevron.click();
    await page.waitForTimeout(1000);

    // Ring data should persist — progress still 1 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Nudge should still be hidden
    await expect(page.getByText("You haven't journaled today")).not.toBeVisible({ timeout: 10_000 });
  });
});
