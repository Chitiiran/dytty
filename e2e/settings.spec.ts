import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  signInAnonymously,
  clearEmulatorAuth,
  clearEmulatorFirestore,
} from './helpers';

test.describe('Settings Screen', () => {
  test.beforeEach(async ({ page }) => {
    await clearEmulatorAuth();
    await clearEmulatorFirestore();
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);
  });

  test('navigates to settings from home screen', async ({ page }) => {
    await page.getByRole('button', { name: 'Settings' }).click();

    // Should show Settings title in app bar
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible({ timeout: 10_000 });
  });

  test('shows appearance section with theme options', async ({ page }) => {
    await page.getByRole('button', { name: 'Settings' }).click();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible({ timeout: 10_000 });

    // Theme options should be visible
    await expect(page.getByText('Appearance')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('System')).toBeVisible();
    await expect(page.getByText('Light')).toBeVisible();
    await expect(page.getByText('Dark')).toBeVisible();
  });

  test('shows account section with sign out', async ({ page }) => {
    await page.getByRole('button', { name: 'Settings' }).click();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible({ timeout: 10_000 });

    await expect(page.getByText('Account')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText('Sign Out')).toBeVisible();
  });

  test('can navigate back from settings', async ({ page }) => {
    await page.getByRole('button', { name: 'Settings' }).click();
    await expect(page.getByRole('heading', { name: 'Settings' })).toBeVisible({ timeout: 10_000 });

    await page.goBack();
    await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 10_000 });
  });
});
