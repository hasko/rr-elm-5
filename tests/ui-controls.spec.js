import { test, expect } from '@playwright/test';

test.describe('UI Controls - Zoom, Speed, Panning', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  test.describe('Mouse wheel zoom on canvas', () => {
    test('wheel event changes the SVG viewBox', async ({ page }) => {
      // Close planning panel to get to the canvas
      await page.getByTestId('close-planning-panel').click();

      const canvas = page.locator('svg').first();
      await expect(canvas).toBeVisible();

      // Get initial viewBox
      const initialViewBox = await canvas.getAttribute('viewBox');

      // Perform wheel zoom in (negative deltaY = zoom in)
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, -100);

      // Wait for viewBox to change
      await expect(async () => {
        const newViewBox = await canvas.getAttribute('viewBox');
        expect(newViewBox).not.toBe(initialViewBox);
      }).toPass({ timeout: 3000 });
    });

    test('zoom in reduces viewBox dimensions (shows less area)', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      const canvas = page.locator('svg').first();
      await expect(canvas).toBeVisible();

      const initialViewBox = await canvas.getAttribute('viewBox');
      const [, , initialWidth] = initialViewBox.split(' ').map(Number);

      // Zoom in
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, -100);

      await expect(async () => {
        const newViewBox = await canvas.getAttribute('viewBox');
        const [, , newWidth] = newViewBox.split(' ').map(Number);
        expect(newWidth).toBeLessThan(initialWidth);
      }).toPass({ timeout: 3000 });
    });

    test('zoom out increases viewBox dimensions (shows more area)', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      const canvas = page.locator('svg').first();
      await expect(canvas).toBeVisible();

      const initialViewBox = await canvas.getAttribute('viewBox');
      const [, , initialWidth] = initialViewBox.split(' ').map(Number);

      // Zoom out
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, 100);

      await expect(async () => {
        const newViewBox = await canvas.getAttribute('viewBox');
        const [, , newWidth] = newViewBox.split(' ').map(Number);
        expect(newWidth).toBeGreaterThan(initialWidth);
      }).toPass({ timeout: 3000 });
    });
  });

  test.describe('Time speed control buttons', () => {
    test('speed buttons 1x, 2x, 4x, 8x are visible', async ({ page }) => {
      // Speed buttons should be in the header bar
      await expect(page.getByRole('button', { name: '1x' })).toBeVisible();
      await expect(page.getByRole('button', { name: '2x' })).toBeVisible();
      await expect(page.getByRole('button', { name: '4x' })).toBeVisible();
      await expect(page.getByRole('button', { name: '8x' })).toBeVisible();
    });

    test('1x button is active by default', async ({ page }) => {
      const btn1x = page.getByRole('button', { name: '1x' });
      // Active button has bold font weight
      await expect(btn1x).toHaveCSS('font-weight', '700');
    });

    test('clicking 4x button activates it', async ({ page }) => {
      const btn4x = page.getByRole('button', { name: '4x' });
      await btn4x.click();
      // Active button should have bold font weight
      await expect(btn4x).toHaveCSS('font-weight', '700');

      // 1x should no longer be bold
      const btn1x = page.getByRole('button', { name: '1x' });
      await expect(btn1x).toHaveCSS('font-weight', '400');
    });

    test('higher speed makes clock advance faster', async ({ page }) => {
      // Close planning panel
      await page.getByTestId('close-planning-panel').click();

      // Set 8x speed
      await page.getByRole('button', { name: '8x' }).click();

      // Start simulation
      await page.getByRole('button', { name: 'Start', exact: true }).click();

      // Wait a brief moment for sim to advance
      await page.waitForTimeout(2000);

      // Pause
      await page.getByRole('button', { name: 'Pause' }).click();

      // At 8x speed, 2 seconds real time = 16 seconds sim time
      // Starting at 06:00:00, after 16s sim time we should be at ~06:00:16
      // Check that seconds have advanced significantly
      await expect(async () => {
        const timeText = await page.locator('span').filter({ hasText: /:\d{2}/ }).textContent();
        // Extract seconds value -- the span shows ":SS"
        const seconds = parseInt(timeText.replace(':', ''), 10);
        expect(seconds).toBeGreaterThan(5);
      }).toPass({ timeout: 3000 });
    });
  });

  test.describe('Clock advances when simulation runs', () => {
    test('clock shows initial time 06:00', async ({ page }) => {
      await expect(page.getByText('06:00')).toBeVisible();
    });

    test('clock advances after simulation starts', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      // Start simulation
      await page.getByRole('button', { name: 'Start', exact: true }).click();

      // Wait for seconds to change
      await expect(async () => {
        const secondsSpan = page.locator('span').filter({ hasText: /:\d{2}/ });
        const secondsText = await secondsSpan.textContent();
        expect(secondsText).not.toBe(':00');
      }).toPass({ timeout: 10000 });

      // Pause
      await page.getByRole('button', { name: 'Pause' }).click();
    });

    test('clock stops advancing when paused', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      // Start simulation
      await page.getByRole('button', { name: 'Start', exact: true }).click();
      await page.waitForTimeout(1000);

      // Pause
      await page.getByRole('button', { name: 'Pause' }).click();

      // Record time
      const secondsSpan = page.locator('span').filter({ hasText: /:\d{2}/ });
      const pausedTime = await secondsSpan.textContent();

      // Wait and check time hasn't changed
      await page.waitForTimeout(1000);
      const afterWaitTime = await secondsSpan.textContent();
      expect(afterWaitTime).toBe(pausedTime);
    });
  });

  test.describe('Consist builder horizontal panning', () => {
    test('consist builder area is visible with items', async ({ page }) => {
      // Add a locomotive to consist
      await page.getByTestId('stock-locomotive').click();
      await page.locator('button:has-text("+")').first().click();

      // Consist area should show the item
      const consistArea = page.getByTestId('consist-area');
      await expect(consistArea).toBeVisible();
      await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    });

    test('consist area supports mouse drag panning', async ({ page }) => {
      // Add a locomotive to the consist
      await page.getByTestId('stock-locomotive').click();
      await page.locator('button:has-text("+")').first().click();

      // Wait for consist item to appear
      const consistArea = page.getByTestId('consist-area');
      await expect(consistArea).toBeVisible();
      await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);

      // Perform a mouse drag on the consist area
      const box = await consistArea.boundingBox();
      if (box) {
        // Mouse down, move left, mouse up
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await page.mouse.down();
        await page.mouse.move(box.x + box.width / 2 - 50, box.y + box.height / 2);
        await page.mouse.up();
      }

      // The test verifies the drag doesn't crash the app
      // Visual panning is CSS transform based and hard to assert precisely
      await expect(consistArea).toBeVisible();
    });
  });

  test.describe('Buffer stop visual presence', () => {
    test('buffer stop is rendered on the canvas', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      const canvas = page.locator('svg').first();
      await expect(canvas).toBeVisible();

      // Buffer stop is rendered as a group with rect elements (red/brown colored)
      // Check for the buffer beam element (dark red colored rect)
      const bufferRects = canvas.locator('rect[fill="#8a2a2a"]');
      await expect(bufferRects).toHaveCount(1);
    });

    test('buffer stop has post elements', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      const canvas = page.locator('svg').first();
      await expect(canvas).toBeVisible();

      // Buffer posts are darker red
      const postRects = canvas.locator('rect[fill="#6a1a1a"]');
      // There are 2 posts
      await expect(postRects).toHaveCount(2);
    });
  });
});
