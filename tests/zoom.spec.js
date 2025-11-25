import { test, expect } from '@playwright/test';

test.describe('Scroll Wheel Zoom', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for the page to load
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  test('Zoom out with scroll wheel down', async ({ page }) => {
    // Get the SVG canvas
    const canvas = page.locator('svg').first();
    const box = await canvas.boundingBox();

    // Position mouse in center of canvas
    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;
    await page.mouse.move(centerX, centerY);

    // Get initial viewBox
    const initialViewBox = await canvas.getAttribute('viewBox');
    const initialParts = initialViewBox.split(' ').map(Number);
    const initialWidth = initialParts[2];

    // Scroll down to zoom out
    await page.mouse.wheel(0, 100);
    await page.waitForTimeout(100);

    // Get new viewBox - width should be larger (zoomed out)
    const newViewBox = await canvas.getAttribute('viewBox');
    const newParts = newViewBox.split(' ').map(Number);
    const newWidth = newParts[2];

    expect(newWidth).toBeGreaterThan(initialWidth);
  });

  test('Zoom in with scroll wheel up', async ({ page }) => {
    // Get the SVG canvas
    const canvas = page.locator('svg').first();
    const box = await canvas.boundingBox();

    // Position mouse in center of canvas
    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;
    await page.mouse.move(centerX, centerY);

    // Get initial viewBox
    const initialViewBox = await canvas.getAttribute('viewBox');
    const initialParts = initialViewBox.split(' ').map(Number);
    const initialWidth = initialParts[2];

    // Scroll up to zoom in
    await page.mouse.wheel(0, -100);
    await page.waitForTimeout(100);

    // Get new viewBox - width should be smaller (zoomed in)
    const newViewBox = await canvas.getAttribute('viewBox');
    const newParts = newViewBox.split(' ').map(Number);
    const newWidth = newParts[2];

    expect(newWidth).toBeLessThan(initialWidth);
  });

  test('Zoom respects minimum zoom level', async ({ page }) => {
    // Get the SVG canvas
    const canvas = page.locator('svg').first();
    const box = await canvas.boundingBox();

    // Position mouse in center
    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;
    await page.mouse.move(centerX, centerY);

    // Zoom in many times to hit the limit
    for (let i = 0; i < 20; i++) {
      await page.mouse.wheel(0, -200);
      await page.waitForTimeout(50);
    }

    // Get viewBox after max zoom
    const maxZoomViewBox = await canvas.getAttribute('viewBox');
    const maxParts = maxZoomViewBox.split(' ').map(Number);
    const maxZoomWidth = maxParts[2];

    // Try to zoom in more
    await page.mouse.wheel(0, -200);
    await page.waitForTimeout(100);

    // Width should not decrease further (hit min limit)
    const afterViewBox = await canvas.getAttribute('viewBox');
    const afterParts = afterViewBox.split(' ').map(Number);
    const afterWidth = afterParts[2];

    // Should be approximately the same (within floating point tolerance)
    expect(Math.abs(afterWidth - maxZoomWidth)).toBeLessThan(1);
  });

  test('Zoom respects maximum zoom level (zoomed out)', async ({ page }) => {
    // Get the SVG canvas
    const canvas = page.locator('svg').first();
    const box = await canvas.boundingBox();

    // Position mouse in center
    const centerX = box.x + box.width / 2;
    const centerY = box.y + box.height / 2;
    await page.mouse.move(centerX, centerY);

    // Zoom out many times to hit the limit
    for (let i = 0; i < 20; i++) {
      await page.mouse.wheel(0, 200);
      await page.waitForTimeout(50);
    }

    // Get viewBox after max zoom out
    const maxZoomOutViewBox = await canvas.getAttribute('viewBox');
    const maxParts = maxZoomOutViewBox.split(' ').map(Number);
    const maxZoomOutWidth = maxParts[2];

    // Try to zoom out more
    await page.mouse.wheel(0, 200);
    await page.waitForTimeout(100);

    // Width should not increase further (hit max limit)
    const afterViewBox = await canvas.getAttribute('viewBox');
    const afterParts = afterViewBox.split(' ').map(Number);
    const afterWidth = afterParts[2];

    // Should be approximately the same (within floating point tolerance)
    expect(Math.abs(afterWidth - maxZoomOutWidth)).toBeLessThan(1);
  });

  test('Zoom keeps point under cursor fixed', async ({ page }) => {
    // Get the SVG canvas
    const canvas = page.locator('svg').first();
    const box = await canvas.boundingBox();

    // Position mouse at a specific offset from center (not center, to test the math)
    const mouseX = box.x + box.width * 0.25; // 25% from left
    const mouseY = box.y + box.height * 0.25; // 25% from top
    await page.mouse.move(mouseX, mouseY);

    // Get initial viewBox
    const initialViewBox = await canvas.getAttribute('viewBox');
    const initialParts = initialViewBox.split(' ').map(Number);
    const [initMinX, initMinY, initWidth, initHeight] = initialParts;

    // Calculate world point under mouse before zoom
    // Screen offset from canvas top-left
    const screenOffsetX = mouseX - box.x;
    const screenOffsetY = mouseY - box.y;
    // World point = viewBox min + (screen offset / screen size) * viewBox size
    const worldXBefore = initMinX + (screenOffsetX / box.width) * initWidth;
    const worldYBefore = initMinY + (screenOffsetY / box.height) * initHeight;

    // Zoom in
    await page.mouse.wheel(0, -100);
    await page.waitForTimeout(100);

    // Get new viewBox
    const newViewBox = await canvas.getAttribute('viewBox');
    const newParts = newViewBox.split(' ').map(Number);
    const [newMinX, newMinY, newWidth, newHeight] = newParts;

    // Calculate world point under mouse after zoom
    const worldXAfter = newMinX + (screenOffsetX / box.width) * newWidth;
    const worldYAfter = newMinY + (screenOffsetY / box.height) * newHeight;

    // The world point should be approximately the same (cursor-fixed zoom)
    // Allow some tolerance due to floating point math and discrete zoom steps
    expect(Math.abs(worldXAfter - worldXBefore)).toBeLessThan(20);
    expect(Math.abs(worldYAfter - worldYBefore)).toBeLessThan(20);
  });
});
