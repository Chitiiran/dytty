import { test, expect } from '@playwright/test';
import { waitForFlutterReady, expectTextVisible, clickByLabel } from './helpers';

// These tests require the Firebase Auth + Firestore emulators running,
// and a signed-in user. They will be skipped until emulator auth
// integration is configured.
//
// To run these tests:
// 1. Start Firebase emulators: firebase emulators:start
// 2. Ensure the Flutter app is configured to use emulators
// 3. Sign in via the emulator auth (or implement email/password for test)

test.describe('Journal CRUD', () => {
  test.skip(true, 'Requires Firebase emulators + auth setup');

  test('navigates from home to daily journal screen', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // Click today's journal button
    await clickByLabel(page, 'Today button');

    // Should show the daily journal screen with category cards
    await expectTextVisible(page, 'Positive Things');
    await expectTextVisible(page, 'Negative Things');
    await expectTextVisible(page, 'Gratitude');
    await expectTextVisible(page, 'Beauty');
    await expectTextVisible(page, 'Identity');
  });

  test('adds an entry to positive category', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await clickByLabel(page, 'Today button');

    // Click add button for positive category
    await clickByLabel(page, 'Add Positive Things entry');

    // Type in the dialog
    const textField = page.getByLabel('Entry text');
    await expect(textField).toBeVisible();
    await textField.fill('Had a great morning walk');

    // Save
    await clickByLabel(page, 'Save entry');

    // Verify entry appears
    await expectTextVisible(page, 'Had a great morning walk');
  });

  test('edits an existing entry', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
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
    await editField.clear();
    await editField.fill('Updated text');
    await clickByLabel(page, 'Save changes');

    // Verify updated
    await expectTextVisible(page, 'Updated text');
  });

  test('deletes an entry', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await clickByLabel(page, 'Today button');

    // Add an entry first
    await clickByLabel(page, 'Add Positive Things entry');
    const textField = page.getByLabel('Entry text');
    await textField.fill('Entry to delete');
    await clickByLabel(page, 'Save entry');
    await expectTextVisible(page, 'Entry to delete');

    // Delete it
    await clickByLabel(page, 'Delete entry');

    // Verify gone
    await expect(page.getByText('Entry to delete')).not.toBeVisible();
  });

  test('adds entries across multiple categories', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
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
      await textField.fill(text);
      await clickByLabel(page, 'Save entry');
      await expectTextVisible(page, text);
    }
  });
});

test.describe('Calendar Navigation', () => {
  test.skip(true, 'Requires Firebase emulators + auth setup');

  test('shows calendar on home screen', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    const calendar = page.getByLabel('Calendar');
    await expect(calendar).toBeVisible();
  });

  test('navigates to daily journal by tapping a date', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // Click on today in the calendar
    await clickByLabel(page, 'Today button');

    // Should show journal screen
    await expectTextVisible(page, 'Positive Things');
  });
});
