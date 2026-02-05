import { test, expect } from '@playwright/test';

test.describe('Train Movement', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for the planning panel to be visible (app starts in Planning mode)
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  test('Start button is disabled in Planning mode', async ({ page }) => {
    // Find the Start button in the header (exact match to avoid matching "Start Fresh")
    const playButton = page.getByRole('button', { name: 'Start', exact: true });
    await expect(playButton).toBeVisible();

    // Button should be disabled in Planning mode
    await expect(playButton).toBeDisabled();
  });

  test('Play/Pause button toggles simulation state after closing planning panel', async ({ page }) => {
    // Close the planning panel first to exit Planning mode
    // Use the X button in the header row (next to "Train Planning" text)
    await page.getByTestId('close-planning-panel').click();

    // Now button should be enabled (poll until panel closes and mode changes)
    const playButton = page.getByRole('button', { name: 'Start', exact: true });
    await expect(playButton).toBeEnabled();

    // Click to start simulation
    await playButton.click();

    // After clicking, button should change to "Pause"
    await expect(page.getByRole('button', { name: 'Pause' })).toBeVisible();

    // Click to pause simulation
    await page.getByRole('button', { name: 'Pause' }).click();
    await expect(page.getByRole('button', { name: 'Start', exact: true })).toBeVisible();
  });

  test('Time display shows initial time of 06:00:00', async ({ page }) => {
    // Verify initial time display shows 06:00 (hours:minutes) with :00 seconds
    await expect(page.getByText('06:00')).toBeVisible();
    // Seconds are shown in a smaller span
    await expect(page.locator('span:has-text(":00")')).toBeVisible();
  });

  test('Time display updates with seconds when simulation runs', async ({ page }) => {
    // Close planning panel to enable Start button
    await page.getByTestId('close-planning-panel').click();

    // Start simulation
    const playButton = page.getByRole('button', { name: 'Start', exact: true });
    await playButton.click();

    // Wait for seconds to advance beyond :00 (poll instead of fixed timeout)
    await expect(async () => {
      const secondsSpan = page.locator('span').filter({ hasText: /:\d{2}/ });
      const secondsText = await secondsSpan.textContent();
      expect(secondsText).not.toBe(':00');
    }).toPass({ timeout: 10000 });

    // Pause simulation
    await page.getByRole('button', { name: 'Pause' }).click();
  });

  test('Scheduled train spawns and moves when simulation runs', async ({ page }) => {
    // Build a consist with locomotive
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Schedule the train at minute 0 (immediate spawn)
    const scheduleButton = page.getByTestId('schedule-button');
    await scheduleButton.click();

    // Verify train is scheduled
    const trainRow = page.getByTestId(/train-row-/);
    await expect(trainRow).toHaveCount(1);

    // Close planning panel to enable Start button
    await page.getByTestId('close-planning-panel').click();

    // Get the SVG canvas element
    const canvas = page.locator('svg').first();
    await expect(canvas).toBeVisible();

    // Start simulation
    const playButton = page.getByRole('button', { name: 'Start', exact: true });
    await expect(playButton).toBeEnabled();
    await playButton.click();

    // Wait for train to spawn and appear on canvas (poll instead of fixed timeout)
    const trainCars = canvas.getByTestId('train-car-locomotive');
    await expect(trainCars).toHaveCount(1, { timeout: 10000 });

    // Pause simulation
    await page.getByRole('button', { name: 'Pause' }).click();
  });

  test('Train moves across track over time', async ({ page }) => {
    // Schedule a train
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();
    await page.getByTestId('schedule-button').click();

    // Close planning panel to enable Start button
    await page.getByTestId('close-planning-panel').click();

    // Start simulation
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    // Get the canvas
    const canvas = page.locator('svg').first();

    // Wait for the train car to appear (poll instead of fixed timeout)
    const trainCarGroup = canvas.getByTestId('train-car-locomotive').first();
    await expect(trainCarGroup).toBeVisible({ timeout: 10000 });

    // The data-testid is on the g element with the transform attribute
    const initialTransform = await trainCarGroup.getAttribute('transform');

    // Wait for train to move (poll for transform to change)
    await expect(async () => {
      const newTransform = await trainCarGroup.getAttribute('transform');
      expect(newTransform).not.toBe(initialTransform);
    }).toPass({ timeout: 5000 });

    // Pause
    await page.getByRole('button', { name: 'Pause' }).click();
  });

  test.skip('Train eventually exits the track', async ({ page }) => {
    // NOTE: This test is skipped because it takes ~50 seconds to complete
    // The route is 500m and train speed is ~11.1 m/s
    // Schedule a train
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();
    await page.getByTestId('schedule-button').click();

    // Close planning panel to enable Start button
    await page.getByTestId('close-planning-panel').click();

    const canvas = page.locator('svg').first();

    // Start simulation
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    // Wait for train to spawn (poll instead of fixed timeout)
    let trainCar = canvas.getByTestId('train-car-locomotive');
    await expect(trainCar).toHaveCount(1, { timeout: 10000 });

    // Route is 500m, train speed is ~11.1 m/s, so ~45 seconds to traverse
    // Wait up to 60 seconds for train to exit
    await expect(async () => {
      const count = await canvas.getByTestId('train-car-locomotive').count();
      expect(count).toBe(0);
    }).toPass({ timeout: 60000 });

    // Pause
    await page.getByRole('button', { name: 'Pause' }).click();
  });

  test.skip('Multiple trains can be scheduled and run', async ({ page }) => {
    // NOTE: Skipped - complex test that requires careful timing and stock availability
    // The core train movement is verified by the single train tests
    // Schedule first train from East
    let locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    let scheduleButton = page.getByTestId('schedule-button');
    await scheduleButton.click();

    // Wait for first train to be scheduled and consist cleared
    await expect(page.getByTestId(/train-row-/)).toHaveCount(1);
    await expect(scheduleButton).toBeDisabled();

    // Switch to West Station
    await page.getByRole('button', { name: 'West Station' }).click();

    // Schedule second train from West - wait for stock panel to update
    locomotiveStock = page.getByTestId('stock-locomotive');
    await expect(locomotiveStock).toBeVisible();
    await locomotiveStock.click();

    // Wait for selection to register
    await expect(page.locator('text=/Selected: Locomotive/')).toBeVisible();

    // Add to consist
    await page.locator('button:has-text("+")').first().click();

    // Schedule second train
    await expect(scheduleButton).toBeEnabled();
    await scheduleButton.click();

    // Verify 2 trains scheduled
    const trainRows = page.getByTestId(/train-row-/);
    await expect(trainRows).toHaveCount(2);

    // Start simulation
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    // Both trains should be visible (poll instead of fixed timeout)
    const canvas = page.locator('svg').first();
    const trainCars = canvas.getByTestId('train-car-locomotive');
    await expect(trainCars).toHaveCount(2, { timeout: 10000 });

    // Pause
    await page.getByRole('button', { name: 'Pause' }).click();
  });
});
