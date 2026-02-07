import { test, expect } from '@playwright/test';

/**
 * UI Controls - Zoom, Speed, Panning, Buffer Stop
 *
 * Required data-testid attributes (add to implementation if missing):
 *
 *   EXISTING (already in codebase):
 *   - data-testid="close-planning-panel"    on planning panel close button
 *   - data-testid="stock-locomotive"        on locomotive stock item
 *   - data-testid="stock-passenger"         on passenger car stock item
 *   - data-testid="stock-flatbed"           on flatbed stock item
 *   - data-testid="consist-area"            on the consist builder scroll area
 *   - data-testid="consist-item-locomotive" on locomotive items in consist
 *   - data-testid="consist-item-passenger"  on passenger car items in consist
 *   - data-testid="consist-item-flatbed"    on flatbed items in consist
 *
 *   NEW (need to be added to implementation):
 *   - data-testid="svg-canvas"              on the main SVG element (viewCanvas)
 *   - data-testid="game-clock"              on the clock container in the header
 *   - data-testid="play-pause-button"       on the play/pause button
 *   - data-testid="speed-control-1x"        on the 1x speed button
 *   - data-testid="speed-control-2x"        on the 2x speed button
 *   - data-testid="speed-control-4x"        on the 4x speed button
 *   - data-testid="speed-control-8x"        on the 8x speed button
 *   - data-testid="mode-indicator"          on the PLANNING/RUNNING/PAUSED badge
 *   - data-testid="buffer-stop"             on the buffer stop SVG group
 */

test.describe('UI Controls - Zoom, Speed, Panning', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  // ---------------------------------------------------------------------------
  // Helper: get the canvas SVG element (tries data-testid first, falls back)
  // ---------------------------------------------------------------------------
  const getCanvas = (page) => {
    const byTestId = page.getByTestId('svg-canvas');
    // Fall back to first <svg> if data-testid not yet wired up
    return byTestId.or(page.locator('svg').first());
  };

  // ---------------------------------------------------------------------------
  // Helper: get the play/pause button
  // ---------------------------------------------------------------------------
  const getPlayPauseButton = (page) => {
    return page.getByTestId('play-pause-button')
      .or(page.getByRole('button', { name: 'Start', exact: true }))
      .or(page.getByRole('button', { name: 'Pause' }));
  };

  const getStartButton = (page) => {
    return page.getByTestId('play-pause-button')
      .or(page.getByRole('button', { name: 'Start', exact: true }));
  };

  const getPauseButton = (page) => {
    return page.getByTestId('play-pause-button')
      .or(page.getByRole('button', { name: 'Pause' }));
  };

  // ---------------------------------------------------------------------------
  // Helper: get speed buttons
  // ---------------------------------------------------------------------------
  const getSpeedButton = (page, multiplier) => {
    return page.getByTestId(`speed-control-${multiplier}x`)
      .or(page.getByRole('button', { name: `${multiplier}x` }));
  };

  // ---------------------------------------------------------------------------
  // Mouse wheel zoom on canvas
  // ---------------------------------------------------------------------------
  test.describe('Mouse wheel zoom on canvas', () => {
    test('wheel event changes the SVG viewBox', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      const canvas = getCanvas(page);
      await expect(canvas).toBeVisible();

      const initialViewBox = await canvas.getAttribute('viewBox');

      // Zoom in (negative deltaY = scroll up = zoom in)
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, -100);

      await expect(async () => {
        const newViewBox = await canvas.getAttribute('viewBox');
        expect(newViewBox).not.toBe(initialViewBox);
      }).toPass({ timeout: 3000 });
    });

    test('zoom in reduces viewBox width (shows less area)', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      const canvas = getCanvas(page);
      await expect(canvas).toBeVisible();

      const initialViewBox = await canvas.getAttribute('viewBox');
      const initialWidth = Number(initialViewBox.split(' ')[2]);

      // Wait until canvas has a bounding box (fully laid out)
      await expect(async () => {
        const box = await canvas.boundingBox();
        expect(box).not.toBeNull();
      }).toPass({ timeout: 3000 });
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, -100);

      await expect(async () => {
        const vb = await canvas.getAttribute('viewBox');
        const newWidth = Number(vb.split(' ')[2]);
        expect(newWidth).toBeLessThan(initialWidth);
      }).toPass({ timeout: 3000 });
    });

    test('zoom out increases viewBox width (shows more area)', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      const canvas = getCanvas(page);
      await expect(canvas).toBeVisible();

      const initialViewBox = await canvas.getAttribute('viewBox');
      const initialWidth = Number(initialViewBox.split(' ')[2]);

      // Wait until canvas has a bounding box (fully laid out)
      await expect(async () => {
        const box = await canvas.boundingBox();
        expect(box).not.toBeNull();
      }).toPass({ timeout: 3000 });
      const box = await canvas.boundingBox();
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, 100);

      await expect(async () => {
        const vb = await canvas.getAttribute('viewBox');
        const newWidth = Number(vb.split(' ')[2]);
        expect(newWidth).toBeGreaterThan(initialWidth);
      }).toPass({ timeout: 3000 });
    });
  });

  // ---------------------------------------------------------------------------
  // Time speed control buttons
  // ---------------------------------------------------------------------------
  test.describe('Time speed control buttons', () => {
    test('speed buttons 1x, 2x, 4x, 8x are visible', async ({ page }) => {
      for (const m of [1, 2, 4, 8]) {
        await expect(getSpeedButton(page, m)).toBeVisible();
      }
    });

    test('1x button is active by default (bold)', async ({ page }) => {
      const btn1x = getSpeedButton(page, 1);
      await expect(btn1x).toHaveCSS('font-weight', '700');
    });

    test('clicking 4x activates it and deactivates 1x', async ({ page }) => {
      const btn4x = getSpeedButton(page, 4);
      await btn4x.click();
      await expect(btn4x).toHaveCSS('font-weight', '700');

      const btn1x = getSpeedButton(page, 1);
      await expect(btn1x).toHaveCSS('font-weight', '400');
    });

    test('8x speed makes clock advance significantly in 2 seconds', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      await getSpeedButton(page, 8).click();

      // Start simulation
      await page.getByRole('button', { name: 'Start', exact: true }).click();
      await page.waitForTimeout(2000);
      await page.getByRole('button', { name: 'Pause' }).click();

      // At 8x, 2s real time ~ 16s sim time. Seconds should be > 5.
      await expect(async () => {
        const secondsSpan = page.locator('span').filter({ hasText: /:\d{2}/ });
        const txt = await secondsSpan.textContent();
        const seconds = parseInt(txt.replace(':', ''), 10);
        expect(seconds).toBeGreaterThan(5);
      }).toPass({ timeout: 3000 });
    });
  });

  // ---------------------------------------------------------------------------
  // Clock behaviour
  // ---------------------------------------------------------------------------
  test.describe('Clock advances when simulation runs', () => {
    test('clock shows initial time 06:00', async ({ page }) => {
      await expect(page.getByText('06:00')).toBeVisible();
    });

    test('clock advances after simulation starts', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      await page.getByRole('button', { name: 'Start', exact: true }).click();

      await expect(async () => {
        const txt = await page.locator('span').filter({ hasText: /:\d{2}/ }).textContent();
        expect(txt).not.toBe(':00');
      }).toPass({ timeout: 10000 });

      await page.getByRole('button', { name: 'Pause' }).click();
    });

    test('clock freezes when paused', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();
      await page.getByRole('button', { name: 'Start', exact: true }).click();
      await page.waitForTimeout(1000);
      await page.getByRole('button', { name: 'Pause' }).click();

      const secondsSpan = page.locator('span').filter({ hasText: /:\d{2}/ });
      const pausedTime = await secondsSpan.textContent();
      await page.waitForTimeout(1000);
      const afterWait = await secondsSpan.textContent();
      expect(afterWait).toBe(pausedTime);
    });
  });

  // ---------------------------------------------------------------------------
  // Consist builder horizontal panning
  // ---------------------------------------------------------------------------
  test.describe('Consist builder horizontal panning', () => {
    test('consist area shows items after adding stock', async ({ page }) => {
      await page.getByTestId('stock-locomotive').click();
      await page.locator('button:has-text("+")').first().click();

      const consistArea = page.getByTestId('consist-area');
      await expect(consistArea).toBeVisible();
      await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    });

    test('mouse drag on consist area does not crash the app', async ({ page }) => {
      await page.getByTestId('stock-locomotive').click();
      await page.locator('button:has-text("+")').first().click();

      const consistArea = page.getByTestId('consist-area');
      await expect(consistArea).toBeVisible();
      await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);

      const box = await consistArea.boundingBox();
      if (box) {
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await page.mouse.down();
        await page.mouse.move(box.x + box.width / 2 - 50, box.y + box.height / 2);
        await page.mouse.up();
      }

      // App should still be functional
      await expect(consistArea).toBeVisible();
    });
  });

  // ---------------------------------------------------------------------------
  // Buffer stop visual presence
  // ---------------------------------------------------------------------------
  test.describe('Buffer stop visual presence', () => {
    test('buffer stop beam is rendered on the canvas', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      const canvas = getCanvas(page);
      await expect(canvas).toBeVisible();

      // Buffer beam: dark red rect (#8a2a2a)
      const bufferGroup = canvas.getByTestId('buffer-stop');
      await expect(bufferGroup).toBeVisible();
    });

    test('buffer stop has two post elements', async ({ page }) => {
      await page.getByTestId('close-planning-panel').click();

      const canvas = getCanvas(page);
      await expect(canvas).toBeVisible();

      // Posts: darker red rects (#6a1a1a)
      const postRects = canvas.locator('rect[fill="#6a1a1a"]');
      await expect(postRects).toHaveCount(2);
    });
  });
});
