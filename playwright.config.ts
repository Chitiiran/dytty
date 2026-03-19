import { defineConfig } from '@playwright/test';

const outputBase = process.env.TEST_OUTPUT_DIR ?? 'test-output/latest';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: [
    ['html', { outputFolder: `${outputBase}/playwright/report` }],
    ['json', { outputFile: `${outputBase}/playwright/results.json` }],
  ],
  outputDir: `${outputBase}/playwright/screenshots`,
  timeout: 120_000,

  use: {
    baseURL: 'http://localhost:5555',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    viewport: { width: 1280, height: 720 },
    launchOptions: {
      args: [
        '--enable-webgl',
        '--use-gl=angle',
        '--use-angle=swiftshader',
        '--enable-gpu-rasterization',
      ],
    },
  },

  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],

  webServer: {
    command:
      'flutter build web --no-tree-shake-icons --dart-define=USE_EMULATORS=true --dart-define=FIREBASE_WEB_API_KEY=$FIREBASE_WEB_API_KEY && npx serve build/web -l 5555 --no-clipboard',
    url: 'http://localhost:5555',
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
});
