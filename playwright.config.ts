import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'html',
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
    command: 'flutter run -d web-server --web-port=5555 --web-hostname=localhost',
    url: 'http://localhost:5555',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
