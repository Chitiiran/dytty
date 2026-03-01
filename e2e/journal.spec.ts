import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  expectTextVisible,
  clickByLabel,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

test.describe('Journal CRUD', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('navigates from home to daily journal screen', async ({ page }) => {
    await clickByLabel(page, 'Today button');

    // Should show category cards (check via semantic labels)
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Negative Things category')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Gratitude category')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Beauty category')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Identity category')).toBeVisible({ timeout: 10_000 });
  });

  test('adds an entry to positive category', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();

    // Type in the bottom sheet
    const textField = page.getByRole('textbox');
    await expect(textField).toBeVisible({ timeout: 10_000 });
    await textField.fill('Had a great morning walk');

    await page.getByRole('button', { name: 'Save' }).click();

    // Verify entry appears in semantic tree
    await expect(page.getByLabel('Journal entry: Had a great morning walk')).toBeVisible({ timeout: 10_000 });
  });

  test('edits an existing entry', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add an entry first
    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();
    const textField = page.getByRole('textbox');
    await expect(textField).toBeVisible({ timeout: 10_000 });
    await textField.fill('Original text');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Journal entry: Original text')).toBeVisible({ timeout: 10_000 });

    // Click edit button on the entry
    await page.getByRole('button', { name: 'Edit entry' }).click();

    // Update text in the bottom sheet
    const editField = page.getByRole('textbox');
    await expect(editField).toBeVisible({ timeout: 10_000 });
    await editField.clear();
    await editField.fill('Updated text');
    await page.getByRole('button', { name: 'Update' }).click();

    // Verify updated
    await expect(page.getByLabel('Journal entry: Updated text')).toBeVisible({ timeout: 10_000 });
  });

  test('deletes an entry', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    // Add an entry first
    await page.getByRole('button', { name: 'Add Positive Things entry' }).click();
    const textField = page.getByRole('textbox');
    await expect(textField).toBeVisible({ timeout: 10_000 });
    await textField.fill('Entry to delete');
    await page.getByRole('button', { name: 'Save' }).click();
    await expect(page.getByLabel('Journal entry: Entry to delete')).toBeVisible({ timeout: 10_000 });

    // Delete it — now uses optimistic delete (no confirmation dialog)
    await page.getByRole('button', { name: 'Delete entry' }).click();

    // Wait for deletion and verify gone
    await page.waitForTimeout(2000);
    await expect(page.getByLabel('Journal entry: Entry to delete')).not.toBeVisible();
  });

  test('adds entries across multiple categories', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });

    const categories = [
      { name: 'Positive Things', text: 'Sunny day' },
      { name: 'Negative Things', text: 'Traffic jam' },
      { name: 'Gratitude', text: 'Good health' },
      { name: 'Beauty', text: 'Sunset colors' },
      { name: 'Identity', text: 'Helped a friend' },
    ];

    for (const { name, text } of categories) {
      await page.getByRole('button', { name: `Add ${name} entry` }).click();
      const textField = page.getByRole('textbox');
      await expect(textField).toBeVisible({ timeout: 10_000 });
      await textField.fill(text);
      await page.getByRole('button', { name: 'Save' }).click();
      await expect(page.getByLabel(`Journal entry: ${text}`)).toBeVisible({ timeout: 10_000 });
    }
  });
});

test.describe('Calendar Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('shows calendar on home screen', async ({ page }) => {
    const calendar = page.getByLabel('Calendar');
    await expect(calendar).toBeVisible({ timeout: 10_000 });
  });

  test('navigates to daily journal by clicking Today button', async ({ page }) => {
    await clickByLabel(page, 'Today button');
    await expect(page.getByLabel('Positive Things category')).toBeVisible({ timeout: 10_000 });
  });
});
