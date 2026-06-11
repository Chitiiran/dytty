import { test, expect, Page } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

/**
 * State-management E2E regression suite (#162).
 *
 * Covers the UI-wiring paths bloc tests cannot see:
 * - entries surviving cross-date navigation (#153 family)
 * - delete + Undo restoring on the correct date
 * - progress card staying today-sourced when a past date is selected
 *   (#154 contract — the card NEVER switches to the selected date)
 *
 * "Radial menu checkmarks" from the issue checklist is covered at widget
 * level (home_screen_radial_menu_test: badges-from-state); its E2E needs
 * accessible labels on CircularMenuItem bubbles, deferred to the #190
 * menu rework.
 */

/** Adds an entry in a category on the daily journal screen. */
async function addEntry(page: Page, categoryName: string, text: string) {
  await page.getByRole('button', { name: `Add ${categoryName} entry` }).click();
  const textField = page.getByRole('textbox');
  await expect(textField).toBeVisible({ timeout: 10_000 });
  await textField.fill(text);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByLabel(`Journal entry: ${text}`)).toBeVisible({
    timeout: 10_000,
  });
}

test.describe('State regression: cross-date navigation and undo', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('entry added on a past date survives A -> B -> A navigation', async ({
    page,
  }) => {
    // Go to today's journal, then step back one day (date A = yesterday).
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({
      timeout: 10_000,
    });
    await page.getByRole('button', { name: 'Previous day' }).click();
    await addEntry(page, 'Positive Things', 'Yesterday entry A');

    // Navigate to date B (two days ago), then back to A.
    await page.getByRole('button', { name: 'Previous day' }).click();
    await expect(
      page.getByLabel('Journal entry: Yesterday entry A'),
    ).not.toBeVisible({ timeout: 10_000 });
    await page.getByRole('button', { name: 'Next day' }).click();

    // Entry must still be on date A.
    await expect(
      page.getByLabel('Journal entry: Yesterday entry A'),
    ).toBeVisible({ timeout: 10_000 });
  });

  test('delete then Undo restores the entry on the correct date', async ({
    page,
  }) => {
    // Add an entry on yesterday (a non-today date so a wrong-date restore
    // would be visible as a failure).
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({
      timeout: 10_000,
    });
    await page.getByRole('button', { name: 'Previous day' }).click();
    await addEntry(page, 'Positive Things', 'Undo target entry');

    // Delete it, then Undo from the snackbar.
    await page.getByRole('button', { name: 'Delete entry' }).first().click();
    // Confirm dialog if present; otherwise the snackbar appears directly.
    const confirmDelete = page.getByRole('button', { name: 'Delete' });
    if (await confirmDelete.isVisible({ timeout: 2_000 }).catch(() => false)) {
      await confirmDelete.click();
    }
    await expect(
      page.getByLabel('Journal entry: Undo target entry'),
    ).not.toBeVisible({ timeout: 10_000 });
    await page.getByRole('button', { name: 'Undo' }).click();

    // Restored on this (past) date...
    await expect(
      page.getByLabel('Journal entry: Undo target entry'),
    ).toBeVisible({ timeout: 10_000 });

    // ...and NOT on today: navigate to today and assert absence.
    await page.getByRole('button', { name: 'Next day' }).click();
    await expect(
      page.getByLabel('Journal entry: Undo target entry'),
    ).not.toBeVisible({ timeout: 10_000 });

    // Round-trip back to the past date — still there (persisted, not
    // just optimistic state).
    await page.getByRole('button', { name: 'Previous day' }).click();
    await expect(
      page.getByLabel('Journal entry: Undo target entry'),
    ).toBeVisible({ timeout: 10_000 });
  });

  test('progress card stays today-sourced when a past date is selected (#154)', async ({
    page,
  }) => {
    // Add one entry today so today's progress is 1 of 5.
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({
      timeout: 10_000,
    });
    await addEntry(page, 'Positive Things', 'Today progress source');

    // Select a past date via the journal chevron (same SelectDate event a
    // calendar tap dispatches; day cells aren't actionable on web and the
    // radial overlay isn't needed for this contract).
    await page.getByRole('button', { name: 'Previous day' }).click();
    await expect(
      page.getByLabel('Journal entry: Today progress source'),
    ).not.toBeVisible({ timeout: 10_000 });

    // Back to home — selectedDate is still yesterday (HomeScreen is not
    // re-mounted on pop, so initState's SelectDate(today) does not fire).
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({
      timeout: 10_000,
    });

    // The dashboard must show TODAY's progress (1 of 5), not the selected
    // past date's (0 entries) — pre-#154 code showed 'Progress 0 of 5'
    // here. The card title isn't asserted: the Semantics wrapper means
    // inner text isn't exposed to the DOM; the label carries the contract.
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({
      timeout: 10_000,
    });
  });
});
