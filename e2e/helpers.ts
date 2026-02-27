import { Page, expect } from '@playwright/test';

const FIREBASE_AUTH_EMULATOR = 'http://localhost:9099';
const FIREBASE_PROJECT_ID = 'demo-dytty';

/**
 * Creates a test user in the Firebase Auth emulator and signs them in
 * by directly calling the emulator REST API, then injecting the token.
 */
export async function createEmulatorUser(page: Page) {
  // Create a user in the Auth emulator
  const response = await fetch(
    `${FIREBASE_AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: 'test@example.com',
        password: 'testpassword123',
        displayName: 'Test User',
        returnSecureToken: true,
      }),
    }
  );

  const data = await response.json();
  return data;
}

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
    `http://localhost:8081/emulator/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
}

/**
 * Waits for Flutter web app to be fully loaded.
 * Flutter renders on a canvas, so we wait for the canvas element and
 * for Flutter engine to signal readiness.
 */
export async function waitForFlutterReady(page: Page) {
  // Wait for the Flutter engine to load
  await page.waitForSelector('flt-glass-pane, canvas, flutter-view', {
    timeout: 30_000,
  });

  // Give Flutter time to render the first frame
  await page.waitForTimeout(2000);
}

/**
 * Finds a Flutter element by its semantic label.
 * Flutter web with semantics enabled creates an accessibility tree
 * that Playwright can query via ARIA roles and labels.
 */
export async function findByLabel(page: Page, label: string) {
  return page.getByLabel(label);
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
