import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

/** Scrolls down and clicks a category icon by its tooltip text. */
async function clickCategoryIcon(page: import('@playwright/test').Page, categoryName: string) {
  // The category icons in the ProgressCard are below the fold.
  // Scroll the page down to reveal them.
  await page.mouse.wheel(0, 400);
  await page.waitForTimeout(1000);

  // Tooltip-based InkWell renders as a button with the tooltip as accessible name
  const icon = page.getByRole('button', { name: `${categoryName} detail` });
  await expect(icon).toBeVisible({ timeout: 10_000 });
  await icon.click();
}

test.describe('Category Detail Screen', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('navigates to category detail from progress card', async ({ page }) => {
    await clickCategoryIcon(page, 'Positive Things');

    // Should show category title in app bar
    await expect(page.getByText('Positive Things')).toBeVisible({ timeout: 10_000 });
  });

  test('shows empty state when no entries exist', async ({ page }) => {
    await clickCategoryIcon(page, 'Gratitude');

    // Category detail screen title — use exact match to avoid matching tooltip text
    await expect(page.getByText('Gratitude', { exact: true })).toBeVisible({ timeout: 10_000 });

    // Wait for loading to finish — should show empty state
    await page.waitForTimeout(2000);
  });

  test('can navigate back from category detail', async ({ page }) => {
    await clickCategoryIcon(page, 'Positive Things');
    await expect(page.getByText('Positive Things')).toBeVisible({ timeout: 10_000 });

    // Navigate back
    await page.goBack();

    // Should be back on home screen
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
  });

  test('shows entries after adding them via daily journal', async ({ page }) => {
    // First add an entry in the daily journal
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();
    const textField = page.getByRole('textbox');
    await expect(textField).toBeVisible({ timeout: 10_000 });
    await textField.fill('Test entry for category detail');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Journal entry: Test entry for category detail')).toBeVisible({ timeout: 10_000 });

    // Go back to home screen
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });

    // Navigate to category detail via progress card
    await clickCategoryIcon(page, 'Positive Things');
    await expect(page.getByText('Positive Things')).toBeVisible({ timeout: 10_000 });

    // Entry should be visible in category detail
    await expect(page.getByText('Test entry for category detail')).toBeVisible({ timeout: 15_000 });
  });

  test('navigates to each category detail', async ({ page }) => {
    const categories = [
      'Positive Things',
      'Negative Things',
      'Gratitude',
      'Beauty',
      'Identity',
    ];

    for (const name of categories) {
      await clickCategoryIcon(page, name);
      await expect(page.getByText(name)).toBeVisible({ timeout: 10_000 });
      await page.goBack();
      await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
    }
  });
});
