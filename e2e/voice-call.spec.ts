import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

test.describe('Voice Call Screen', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('navigates to voice call screen from home', async ({ page }) => {
    // Click the "Call" button on home screen
    const callButton = page.getByRole('button', { name: 'Call' });
    await expect(callButton).toBeVisible({ timeout: 10_000 });
    await callButton.click();

    // Should show "Daily Call" title
    await expect(page.getByText('Daily Call')).toBeVisible({ timeout: 10_000 });
  });

  test('shows pre-call UI with status and start button', async ({ page }) => {
    await page.getByRole('button', { name: 'Call' }).click();
    await expect(page.getByText('Daily Call')).toBeVisible({ timeout: 10_000 });

    // Status bar should show "Ready to connect"
    await expect(page.getByText('Ready to connect')).toBeVisible({ timeout: 10_000 });

    // Start Call button should be visible
    const startButton = page.getByRole('button', { name: 'Start Call' });
    await expect(startButton).toBeVisible({ timeout: 10_000 });
  });

  test('can navigate back from voice call screen', async ({ page }) => {
    await page.getByRole('button', { name: 'Call' }).click();
    await expect(page.getByText('Daily Call')).toBeVisible({ timeout: 10_000 });

    // Navigate back
    await page.goBack();

    // Should be back on home screen
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
  });
});
