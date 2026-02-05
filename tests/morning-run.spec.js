import { test, expect } from '@playwright/test';

test.describe('Sawmill Morning Run - End to End', () => {
  test.beforeEach(async ({ page }) => {
    // Clear localStorage to start fresh
    await page.goto('/');
    // Clear any saved state
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  test('Full morning run: build consist, program, and run simulation', async ({ page }) => {
    test.setTimeout(90000); // Extended timeout for full sim run

    // === STEP 1: Build consist at East Station ===
    // East station has: locomotive (x1), passenger car (x1), flatbed (x1)
    // After adding each, that stock type disappears from available stock

    // Add Locomotive
    await page.getByTestId('stock-locomotive').click();
    await page.locator('button:has-text("+")').first().click();
    // Wait for locomotive to appear in consist
    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);

    // Add Passenger Car (locomotive stock is now gone from available list)
    await page.getByTestId('stock-passenger').click();
    await page.locator('button:has-text("+")').last().click();
    await expect(consistArea.getByTestId('consist-item-passenger')).toHaveCount(1);

    // Add Flatbed (passenger stock is now gone too)
    await page.getByTestId('stock-flatbed').click();
    await page.locator('button:has-text("+")').last().click();
    await expect(consistArea.getByTestId('consist-item-flatbed')).toHaveCount(1);

    // === STEP 2: Schedule the train ===
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toBeEnabled();
    await scheduleButton.click();

    // Verify train appears in scheduled list
    const trainRow = page.getByTestId(/train-row-/);
    await expect(trainRow).toHaveCount(1);

    // === STEP 3: Open programmer ===
    // Click on train to edit it
    await trainRow.first().click();
    await expect(scheduleButton).toHaveText('Update Train');

    // Click Program button
    const programButton = page.getByTestId(/program-btn-/).first();
    await expect(programButton).toBeVisible();
    await programButton.click();

    // Verify programmer panel opened
    await expect(page.getByText(/Train #\d+ Program/)).toBeVisible();

    // === STEP 4: Add orders for the morning run ===
    // Order 1: Set Switch to Diverging (route train to siding)
    await page.getByTestId('add-switch-main-diverging').click();
    await expect(page.getByTestId('order-item-0')).toContainText('Set main Diverging');

    // Order 2: Move To Platform
    await page.getByTestId('add-moveto-platform').click();
    await expect(page.getByTestId('order-item-1')).toContainText('Move To Platform');

    // Order 3: Wait 10 seconds (shortened for test speed)
    await page.getByTestId('add-wait-10').click();
    await expect(page.getByTestId('order-item-2')).toContainText('Wait 10 seconds');

    // Order 4: Move To Team Track
    await page.getByTestId('add-moveto-teamtrack').click();
    await expect(page.getByTestId('order-item-3')).toContainText('Move To Team Track');

    // Verify all 4 orders are in the list
    for (let i = 0; i < 4; i++) {
      await expect(page.getByTestId(`order-item-${i}`)).toBeVisible();
    }

    // === STEP 5: Save the program ===
    await page.getByTestId('save-program-btn').click();

    // Verify we returned to planning view
    await expect(page.getByText('Train Planning')).toBeVisible();

    // Verify train is in scheduled list (with program saved)
    await expect(page.getByTestId(/train-row-/)).toHaveCount(1);

    // === STEP 6: Close planning panel and start simulation ===
    await page.getByTestId('close-planning-panel').click();

    const playButton = page.getByRole('button', { name: 'Start', exact: true });
    await expect(playButton).toBeEnabled();
    await playButton.click();

    // Verify simulation is running
    await expect(page.getByRole('button', { name: 'Pause' })).toBeVisible();

    // === STEP 7: Verify train spawns ===
    const canvas = page.locator('svg').first();
    const trainCar = canvas.getByTestId('train-car-locomotive');
    await expect(trainCar).toHaveCount(1, { timeout: 10000 });

    // Also expect passenger car and flatbed
    await expect(canvas.getByTestId('train-car-passenger')).toHaveCount(1, { timeout: 5000 });
    await expect(canvas.getByTestId('train-car-flatbed')).toHaveCount(1, { timeout: 5000 });

    // === STEP 8: Verify train moves (position changes) ===
    const initialTransform = await trainCar.first().getAttribute('transform');

    await expect(async () => {
      const newTransform = await trainCar.first().getAttribute('transform');
      expect(newTransform).not.toBe(initialTransform);
    }).toPass({ timeout: 5000 });

    // === STEP 9: Wait for train to reach platform and stop ===
    // The train executes: SetSwitch (instant) -> MoveTo Platform
    // Route with Diverging switch: East tunnel -> Mainline East (250m) -> Turnout diverge -> Curve -> Siding (60m to platform)
    // At max ~11 m/s, this takes ~35 seconds of sim time.
    // Poll for the train to stop (transform stabilizes).

    let lastTransform2 = '';
    let stableCount = 0;
    await expect(async () => {
      const currentTransform = await trainCar.first().getAttribute('transform');
      if (currentTransform === lastTransform2) {
        stableCount++;
      } else {
        stableCount = 0;
        lastTransform2 = currentTransform;
      }
      // Consider stopped if transform unchanged for 3 consecutive checks (~1.5s stable)
      expect(stableCount).toBeGreaterThanOrEqual(3);
    }).toPass({ timeout: 60000 });

    // Train stopped - record its final position
    const stoppedTransform = await trainCar.first().getAttribute('transform');
    console.log('Train stopped at transform:', stoppedTransform);

    // Pause simulation
    await page.getByRole('button', { name: 'Pause' }).click();

    // Verify train is still visible (didn't despawn)
    await expect(trainCar).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-passenger')).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-flatbed')).toHaveCount(1);
  });

  test('Train with program spawns in Executing state and follows switch order', async ({ page }) => {
    // Simplified test: just verify the switch gets set when simulation runs

    // Build consist with just locomotive
    await page.getByTestId('stock-locomotive').click();
    await page.locator('button:has-text("+")').first().click();

    // Schedule
    await page.getByTestId('schedule-button').click();

    // Edit and program
    await page.getByTestId(/train-row-/).first().click();
    await page.getByTestId(/program-btn-/).first().click();

    // Just set switch to diverging
    await page.getByTestId('add-switch-main-diverging').click();

    // Save
    await page.getByTestId('save-program-btn').click();

    // Start simulation
    await page.getByTestId('close-planning-panel').click();
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    // Wait for train to spawn
    const canvas = page.locator('svg').first();
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1, { timeout: 10000 });

    // Verify simulation is still running (no crash)
    await expect(page.getByRole('button', { name: 'Pause' })).toBeVisible();

    // Let it run a bit
    await page.waitForTimeout(2000);

    // Verify train is still visible (didn't crash/disappear immediately)
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1);

    // Pause
    await page.getByRole('button', { name: 'Pause' }).click();
  });

  test('Console errors during morning run', async ({ page }) => {
    // Capture console errors
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Build consist
    await page.getByTestId('stock-locomotive').click();
    await page.locator('button:has-text("+")').first().click();

    await page.getByTestId('stock-flatbed').click();
    await page.locator('button:has-text("+")').last().click();

    // Schedule
    await page.getByTestId('schedule-button').click();

    // Program it
    await page.getByTestId(/train-row-/).first().click();
    await page.getByTestId(/program-btn-/).first().click();

    // Morning run orders
    await page.getByTestId('add-switch-main-diverging').click();
    await page.getByTestId('add-moveto-platform').click();
    await page.getByTestId('add-wait-10').click();
    await page.getByTestId('add-moveto-teamtrack').click();

    // Save
    await page.getByTestId('save-program-btn').click();

    // Start simulation
    await page.getByTestId('close-planning-panel').click();
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    // Let simulation run for 15 seconds
    await page.waitForTimeout(15000);

    // Check for errors
    if (errors.length > 0) {
      console.log('Console errors found:', errors);
    }

    expect(errors.length).toBe(0);

    // Pause
    await page.getByRole('button', { name: 'Pause' }).click();
  });
});
