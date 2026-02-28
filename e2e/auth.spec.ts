import { test, expect } from '@playwright/test';
import { waitForFlutterReady, expectTextVisible, signInAnonymously, clearEmulatorAuth } from './helpers';

test.describe('Auth Flow', () => {
  test.beforeEach(async () => {
    await clearEmulatorAuth();
  });

  test('shows login screen with sign-in buttons', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    await expectTextVisible(page, 'Dytty');
    await expectTextVisible(page, 'Your daily journal');

    const googleButton = page.getByLabel('Sign in with Google');
    await expect(googleButton).toBeVisible({ timeout: 10_000 });

    // Debug-mode anonymous button should also be visible
    const anonButton = page.getByText('Sign in anonymously (emulator)');
    await expect(anonButton).toBeVisible({ timeout: 10_000 });
  });

  test('anonymous sign-in navigates to home screen', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    await signInAnonymously(page);

    // Should be on the home screen
    await expectTextVisible(page, "Today's Journal");
  });

  test('sign out returns to login screen', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await signInAnonymously(page);

    // Click sign out
    const signOutButton = page.getByLabel('Sign out');
    await expect(signOutButton).toBeVisible({ timeout: 10_000 });
    await signOutButton.click();

    // Should be back on login screen
    await expectTextVisible(page, 'Dytty');
    await expectTextVisible(page, 'Your daily journal');
  });
});
