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

    // Should show category cards
    await expectTextVisible(page, 'Positive Things');
    await expectTextVisible(page, 'Negative Things');
    await expectTextVisible(page, 'Gratitude');
    await expectTextVisible(page, 'Beauty');
    await expectTextVisible(page, 'Identity');
  });

  test('adds an entry to positive category', async ({ page }) => {
    await clickByLabel(page, 'Today button');

    await clickByLabel(page, 'Add Positive Things entry');

    // Type in the dialog
    const textField = page.getByLabel('Entry text');
    await expect(textField).toBeVisible({ timeout: 10_000 });
    await textField.fill('Had a great morning walk');

    await clickByLabel(page, 'Save entry');

    // Verify entry appears
    await expectTextVisible(page, 'Had a great morning walk');
  });

  test('edits an existing entry', async ({ page }) => {
    await clickByLabel(page, 'Today button');

    // Add an entry first
    await clickByLabel(page, 'Add Positive Things entry');
    const textField = page.getByLabel('Entry text');
    await textField.fill('Original text');
    await clickByLabel(page, 'Save entry');
    await expectTextVisible(page, 'Original text');

    // Click edit on the entry
    await clickByLabel(page, 'Edit entry');

    // Update text
    const editField = page.getByLabel('Entry text');
    await expect(editField).toBeVisible({ timeout: 10_000 });
    await editField.clear();
    await editField.fill('Updated text');
    await clickByLabel(page, 'Save changes');

    // Verify updated
    await expectTextVisible(page, 'Updated text');
  });

  test('deletes an entry', async ({ page }) => {
    await clickByLabel(page, 'Today button');

    // Add an entry first
    await clickByLabel(page, 'Add Positive Things entry');
    const textField = page.getByLabel('Entry text');
    await textField.fill('Entry to delete');
    await clickByLabel(page, 'Save entry');
    await expectTextVisible(page, 'Entry to delete');

    // Delete it
    await clickByLabel(page, 'Delete entry');

    // Confirm deletion in the dialog
    const deleteConfirm = page.getByText('Delete', { exact: true }).last();
    await expect(deleteConfirm).toBeVisible({ timeout: 10_000 });
    await deleteConfirm.click();

    // Wait for deletion and verify gone
    await page.waitForTimeout(1000);
    await expect(page.getByText('Entry to delete')).not.toBeVisible();
  });

  test('adds entries across multiple categories', async ({ page }) => {
    await clickByLabel(page, 'Today button');

    const categories = [
      { name: 'Positive Things', text: 'Sunny day' },
      { name: 'Negative Things', text: 'Traffic jam' },
      { name: 'Gratitude', text: 'Good health' },
      { name: 'Beauty', text: 'Sunset colors' },
      { name: 'Identity', text: 'Helped a friend' },
    ];

    for (const { name, text } of categories) {
      await clickByLabel(page, `Add ${name} entry`);
      const textField = page.getByLabel('Entry text');
      await expect(textField).toBeVisible({ timeout: 10_000 });
      await textField.fill(text);
      await clickByLabel(page, 'Save entry');
      await expectTextVisible(page, text);
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
    await expectTextVisible(page, 'Positive Things');
  });
});
