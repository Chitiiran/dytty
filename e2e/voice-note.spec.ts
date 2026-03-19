import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

test.describe('Voice Recording Sheet', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('opens voice recording sheet from mic button', async ({ page }) => {
    await page.getByRole('button', { name: 'Record voice note' }).click();

    // Sheet should open and show a voice note status title
    await expect(
      page.getByText('Listening...', { exact: true })
    ).toBeVisible({ timeout: 15_000 });
  });

  test('shows listening state with speech indicator', async ({ page }) => {
    await page.getByRole('button', { name: 'Record voice note' }).click();

    // Should show listening status
    await expect(page.getByText('Listening...', { exact: true })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByText('Listening for speech')).toBeVisible({ timeout: 5_000 });
  });
});
