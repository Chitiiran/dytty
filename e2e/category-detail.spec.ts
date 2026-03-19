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
    await expect(page.getByRole('heading', { name: 'Positive Things' })).toBeVisible({ timeout: 10_000 });
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
    await expect(page.getByRole('heading', { name: 'Positive Things' })).toBeVisible({ timeout: 10_000 });

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
    await expect(page.getByRole('heading', { name: 'Positive Things' })).toBeVisible({ timeout: 10_000 });

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
      // Use exact heading role to avoid matching tooltip announcement text
      await expect(page.getByRole('heading', { name })).toBeVisible({ timeout: 10_000 });
      await page.goBack();
      await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
    }
  });

  test('shows empty state message text', async ({ page }) => {
    await clickCategoryIcon(page, 'Gratitude');
    await expect(page.getByText('Gratitude', { exact: true })).toBeVisible({ timeout: 10_000 });

    // Should show the empty state message
    await expect(page.getByText('No entries yet for Gratitude')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('Your reflections will appear here.')).toBeVisible({ timeout: 10_000 });
  });

  test('shows multiple entries with date group header', async ({ page }) => {
    // Add two entries to the same category
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // First entry
    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();
    const textField1 = page.getByRole('textbox');
    await expect(textField1).toBeVisible({ timeout: 10_000 });
    await textField1.fill('First positive thought');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Journal entry: First positive thought')).toBeVisible({ timeout: 10_000 });

    // Second entry
    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();
    const textField2 = page.getByRole('textbox');
    await expect(textField2).toBeVisible({ timeout: 10_000 });
    await textField2.fill('Second positive thought');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Journal entry: Second positive thought')).toBeVisible({ timeout: 10_000 });

    // Navigate to category detail
    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
    await clickCategoryIcon(page, 'Positive Things');
    await expect(page.getByRole('heading', { name: 'Positive Things' })).toBeVisible({ timeout: 10_000 });

    // Both entries should be visible
    await expect(page.getByText('First positive thought')).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Second positive thought')).toBeVisible({ timeout: 10_000 });

    // Should show "Today" date group header
    await expect(page.getByText('Today')).toBeVisible({ timeout: 10_000 });
  });
});
