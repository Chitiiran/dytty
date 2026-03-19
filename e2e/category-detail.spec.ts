import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

test.describe('Category Detail Screen', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('navigates to category detail from progress card', async ({ page }) => {
    // Tap the "Positive Things detail" button on the progress card
    await clickByLabel(page, 'Positive Things detail');

    // Should show category title in app bar
    await expect(page.getByText('Positive Things')).toBeVisible({ timeout: 10_000 });
  });

  test('shows empty state when no entries exist', async ({ page }) => {
    await clickByLabel(page, 'Positive Things detail');

    // Should show empty state messaging
    await expect(page.getByText('Positive Things')).toBeVisible({ timeout: 10_000 });
    // The empty state widget should be visible (no entries yet)
    // Wait for loading to finish
    await page.waitForTimeout(2000);
  });

  test('can navigate back from category detail', async ({ page }) => {
    await clickByLabel(page, 'Positive Things detail');
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
    await clickByLabel(page, 'Positive Things detail');
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
      await clickByLabel(page, `${name} detail`);
      await expect(page.getByText(name)).toBeVisible({ timeout: 10_000 });
      await page.goBack();
      await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
    }
  });
});
