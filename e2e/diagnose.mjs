import { chromium } from '@playwright/test';

const browser = await chromium.launch({
  headless: true,
  args: [
    '--enable-webgl',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-gpu-rasterization',
  ],
});
const page = await browser.newPage();

const errors = [];
const logs = [];

page.on('console', (msg) => {
  const line = `[${msg.type()}] ${msg.text()}`;
  logs.push(line);
  console.log('CONSOLE:', line);
});
page.on('pageerror', (err) => {
  errors.push(err.message);
  console.log('PAGE ERROR:', err.message);
});

// Catch unhandled promise rejections via CDP
const cdp = await page.context().newCDPSession(page);
await cdp.send('Runtime.enable');
cdp.on('Runtime.exceptionThrown', (event) => {
  const desc = event.exceptionDetails.exception?.description || event.exceptionDetails.text;
  console.log('RUNTIME EXCEPTION:', desc);
  errors.push(desc);
});
cdp.on('Runtime.consoleAPICalled', (event) => {
  if (event.type === 'error' || event.type === 'warning') {
    const text = event.args.map(a => a.value || a.description || '').join(' ');
    console.log(`RUNTIME [${event.type}]:`, text);
  }
});

// Monitor network requests
page.on('request', (req) => {
  if (req.url().includes('canvaskit') || req.url().includes('wasm')) {
    console.log('NET REQUEST:', req.method(), req.url());
  }
});
page.on('response', (res) => {
  if (res.url().includes('canvaskit') || res.url().includes('wasm')) {
    console.log('NET RESPONSE:', res.status(), res.url());
  }
});
page.on('requestfailed', (req) => {
  console.log('NET FAILED:', req.url(), req.failure()?.errorText);
});

await page.goto('http://localhost:5555');
console.log('Page loaded, waiting 30s for Flutter to init...');

// Check every 2 seconds for more detail
for (let i = 0; i < 15; i++) {
  await page.waitForTimeout(2000);
  const state = await page.evaluate(() => {
    const scripts = document.querySelectorAll('script');
    return {
      bodyChildren: document.body.children.length,
      scriptCount: scripts.length,
      hasFlutter: !!window._flutter,
      flutterKeys: window._flutter ? Object.keys(window._flutter) : [],
      hasCanvasKit: !!window.flutterCanvasKit,
      canvasKitLoaded: !!window.flutterCanvasKitLoaded,
    };
  });
  console.log(`${(i + 1) * 2}s:`, JSON.stringify(state));
  if (state.bodyChildren > 1) break;
}

const dom = await page.evaluate(() => {
  return {
    bodyChildCount: document.body.children.length,
    firstChildTag: document.body.children[0]?.tagName || 'none',
    hasFlutterView: document.querySelector('flutter-view') !== null,
    hasGlassPane: document.querySelector('flt-glass-pane') !== null,
    hasSemantics: document.querySelector('flt-semantics') !== null,
    bodyHTML: document.body.innerHTML.substring(0, 3000),
  };
});

console.log('\n=== DOM STATE ===');
console.log(JSON.stringify(dom, null, 2));
console.log('\n=== ERRORS ===');
console.log(errors.length ? errors.join('\n') : 'No errors');
console.log('\n=== LOG COUNT ===');
console.log(`${logs.length} console messages`);

await browser.close();
