import { Page, expect } from '@playwright/test';

const FIREBASE_AUTH_EMULATOR = 'http://localhost:9099';
const FIREBASE_FIRESTORE_EMULATOR = 'http://localhost:8080';
const FIREBASE_PROJECT_ID = 'dytty-4b83d';

/**
 * Clears all Auth emulator accounts.
 */
export async function clearEmulatorAuth() {
  await fetch(
    `${FIREBASE_AUTH_EMULATOR}/emulator/v1/projects/${FIREBASE_PROJECT_ID}/accounts`,
    { method: 'DELETE' }
  );
}

/**
 * Clears the Firestore emulator.
 */
export async function clearEmulatorFirestore() {
  await fetch(
    `${FIREBASE_FIRESTORE_EMULATOR}/emulator/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
}

/**
 * Waits for Flutter web app to be fully loaded.
 * Looks for the Flutter view element and waits for the semantics tree.
 */
export async function waitForFlutterReady(page: Page) {
  // Wait for Flutter's custom element to appear in the DOM
  await page.waitForSelector('flutter-view, flt-glass-pane', {
    timeout: 60_000,
  });

  // Wait for at least one semantic element (proves rendering is complete)
  await page.waitForSelector('flt-semantics', { timeout: 30_000 });

  // Brief extra wait for rendering to settle
  await page.waitForTimeout(1000);
}

/**
 * Signs in anonymously by clicking the emulator sign-in button.
 * Waits for the home screen to appear after sign-in.
 */
export async function signInAnonymously(page: Page) {
  const anonButton = page.getByRole('button', { name: 'Sign in anonymously (emulator)' });
  await expect(anonButton).toBeVisible({ timeout: 10_000 });
  await anonButton.click();

  // Wait for navigation to home screen — look for "Today's Journal" button
  await expect(page.getByRole('button', { name: 'Today button' })).toBeVisible({ timeout: 15_000 });
}

/**
 * Clicks a Flutter element by its semantic label.
 */
export async function clickByLabel(page: Page, label: string) {
  const element = page.getByLabel(label);
  await expect(element).toBeVisible({ timeout: 10_000 });
  await element.click();
}

/**
 * Checks that text is visible on the page (within the accessibility tree).
 */
export async function expectTextVisible(page: Page, text: string) {
  await expect(page.getByText(text)).toBeVisible({ timeout: 10_000 });
}
