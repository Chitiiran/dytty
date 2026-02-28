import { test } from '@playwright/test';

test('debug: check if Flutter initializes', async ({ page }) => {
  const logs: string[] = [];
  page.on('console', msg => {
    logs.push(msg.text());
    console.log('BROWSER:', msg.text());
  });
  page.on('pageerror', err => {
    logs.push('ERROR: ' + err.message);
    console.log('PAGE ERROR:', err.message);
  });

  await page.goto('/');

  // Wait 90s, polling
  for (let i = 0; i < 30; i++) {
    await page.waitForTimeout(3000);

    const hasFlutter = await page.evaluate(() => {
      return {
        hasFlutterView: !!document.querySelector('flutter-view'),
        hasGlassPane: !!document.querySelector('flt-glass-pane'),
        hasSemantics: !!document.querySelector('flt-semantics'),
        bodyChildCount: document.body.children.length,
        bodyFirstChildTag: document.body.children[0]?.tagName?.toLowerCase() || 'none',
      };
    });

    const elapsed = (i + 1) * 3;
    console.log(`${elapsed}s: view=${hasFlutter.hasFlutterView} glass=${hasFlutter.hasGlassPane} sem=${hasFlutter.hasSemantics} bodyKids=${hasFlutter.bodyChildCount} first=${hasFlutter.bodyFirstChildTag}`);

    if (hasFlutter.hasFlutterView || hasFlutter.hasSemantics) {
      console.log('SUCCESS: Flutter rendered');
      break;
    }
  }
});
