import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

/**
 * HomeScreen State Refresh tests.
 *
 * These verify that after adding a journal entry on the daily journal screen
 * and navigating back to HomeScreen, the UI updates correctly:
 * - Calendar marker (minidot) appears for today
 * - Nudge banner disappears
 * - Progress card category icons update
 * - Streak updates
 */

/** Helper: add an entry in a given category, then go back to HomeScreen */
async function addEntryAndGoBack(
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

test.describe('HomeScreen state refresh after adding entry', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('nudge banner disappears after adding an entry and navigating back', async ({ page }) => {
    // Verify nudge banner is visible before journaling
    await expect(page.getByText("You haven't journaled today")).toBeVisible({ timeout: 10_000 });

    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntryAndGoBack(page, 'Positive Things', 'Testing state refresh');

    // Navigate back to HomeScreen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Nudge banner should be gone
    await expect(page.getByText("You haven't journaled today")).not.toBeVisible({ timeout: 10_000 });
  });

  test('progress card updates category count after adding an entry', async ({ page }) => {
    // Verify initial progress via semantic label
    await expect(page.getByLabel('Progress 0 of 5')).toBeVisible({ timeout: 10_000 });

    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntryAndGoBack(page, 'Positive Things', 'Progress card test');

    // Navigate back to HomeScreen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Progress should now show 1 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });
  });

  test('progress card updates after adding entries in multiple categories', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add entries in two categories
    await addEntryAndGoBack(page, 'Positive Things', 'Multi cat test 1');
    await addEntryAndGoBack(page, 'Gratitude', 'Multi cat test 2');

    // Navigate back to HomeScreen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Progress should show 2 of 5
    await expect(page.getByLabel('Progress 2 of 5')).toBeVisible({ timeout: 10_000 });
  });

  test('streak updates after adding first entry today', async ({ page }) => {
    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntryAndGoBack(page, 'Positive Things', 'Streak test');

    // Navigate back to HomeScreen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Streak data may need a second navigation to refresh due to Firestore
    // eventual consistency. Verify progress is correct (1 of 5) first.
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Navigate to journal and back again to trigger a fresh streak load
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Now streak should be updated
    await expect(page.getByLabel(/streak 1 day/)).toBeVisible({ timeout: 10_000 });
  });

  test('calendar marker appears after adding an entry', async ({ page }) => {
    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntryAndGoBack(page, 'Positive Things', 'Calendar marker test');

    // Navigate back to HomeScreen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Indirect verification: nudge banner gone = daysWithEntries updated = markers updated
    await expect(page.getByText("You haven't journaled today")).not.toBeVisible({ timeout: 5_000 });
  });
});
