import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

/**
 * Completion Ring tests.
 *
 * The calendar shows a multi-color segmented completion ring per date cell.
 * Each journal category (positive, negative, gratitude, beauty, identity) maps
 * to a fixed arc segment on the ring. When an entry is added the corresponding
 * segment fills in.
 *
 * Because the ring is painted via CustomPainter (canvas arcs), we cannot query
 * individual segments from the accessibility tree. Screenshots are used for
 * visual verification of ring state changes.
 */

/** Helper: navigate to journal, add an entry in a category, stay on journal screen */
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

test.describe('Completion ring on calendar', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('calendar shows completion ring cells with date numbers', async ({ page }) => {
    // Verify calendar is present on home screen
    const calendar = page.getByLabel('Calendar');
    await expect(calendar).toBeVisible({ timeout: 10_000 });

    // Today's date number should be visible in the calendar
    const todayDate = new Date().getDate().toString();
    await expect(page.getByText(todayDate).first()).toBeVisible({ timeout: 10_000 });

    // Screenshot for visual verification of empty ring state
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/completion-ring-empty.png' });
  });

  test('completion ring updates after adding entry to one category', async ({ page }) => {
    // Navigate to daily journal
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add entry to Positive Things
    await addEntry(page, 'Positive Things', 'Ring test positive');

    // Navigate back to home screen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Wait for ring animation to complete before screenshot
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/completion-ring-one-category.png' });

    // Indirect verification: progress should show 1 of 5
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });
  });

  test('completion ring shows multiple segments after multiple categories', async ({ page }) => {
    // Navigate to daily journal
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add entries to Positive Things and Gratitude
    await addEntry(page, 'Positive Things', 'Ring multi test 1');
    await addEntry(page, 'Gratitude', 'Ring multi test 2');

    // Navigate back to home screen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Wait for ring animation to complete before screenshot
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/completion-ring-multiple-categories.png' });

    // Indirect verification: progress should show 2 of 5
    await expect(page.getByLabel('Progress 2 of 5')).toBeVisible({ timeout: 10_000 });
  });

  test('completion ring updates when entry is deleted', async ({ page }) => {
    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntry(page, 'Positive Things', 'Ring delete test');

    // Go back to verify ring has one segment
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Navigate back to journal to delete the entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Delete the entry (optimistic delete, no confirmation dialog)
    await page.getByRole('button', { name: 'Delete entry' }).click();
    await page.waitForTimeout(2000);
    await expect(page.getByLabel('Journal entry: Ring delete test')).not.toBeVisible();

    // Go back to home screen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Wait for ring animation to complete before screenshot
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'test-output/latest/playwright/screenshots/completion-ring-after-delete.png' });

    // Indirect verification: nudge banner should reappear (no entries left)
    await expect(page.getByText("You haven't journaled today")).toBeVisible({ timeout: 10_000 });
  });

  test('calendar rings persist across month navigation', async ({ page }) => {
    // Navigate to daily journal and add entry
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await addEntry(page, 'Positive Things', 'Ring persist test');

    // Go back to home screen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Verify ring is present (progress shows 1 of 5)
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Navigate to next month
    await page.getByRole('button', { name: 'Next month' }).click();
    await page.waitForTimeout(1000);

    // Navigate back to current month
    await page.getByRole('button', { name: 'Previous month' }).click();
    await page.waitForTimeout(1000);

    // Progress should still show 1 of 5 (ring data persisted)
    await expect(page.getByLabel('Progress 1 of 5')).toBeVisible({ timeout: 10_000 });

    // Nudge should still be gone (entry still exists)
    await expect(page.getByText("You haven't journaled today")).not.toBeVisible({ timeout: 10_000 });
  });
});
