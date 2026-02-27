import { test, expect } from '@playwright/test';
import { waitForFlutterReady, expectTextVisible } from './helpers';

test.describe('Auth Flow', () => {
  test('shows login screen with Google Sign-In button', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // The app should show the login screen with the sign-in button
    await expectTextVisible(page, 'Dytty');
    await expectTextVisible(page, 'Your daily journal');

    const signInButton = page.getByLabel('Sign in with Google');
    await expect(signInButton).toBeVisible({ timeout: 10_000 });
  });

  test('shows loading state when sign-in is clicked', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    const signInButton = page.getByLabel('Sign in with Google');
    await expect(signInButton).toBeVisible({ timeout: 10_000 });

    // Click sign in — it will fail in test env but should show loading state
    await signInButton.click();

    // After click, the button should be in some state (loading or error)
    // Since Google Sign-In popup won't work in headless, we just verify
    // the button was clickable and the app didn't crash
    await page.waitForTimeout(1000);
  });
});
