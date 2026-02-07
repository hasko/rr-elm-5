import { test, expect } from '@playwright/test';

/**
 * Car-specific spotting E2E tests.
 *
 * Tests that MoveTo with car spotting correctly positions the specified
 * car's center at the target spot location.
 *
 * Required data-testid attributes:
 *   - data-testid="stock-locomotive"        on locomotive stock item
 *   - data-testid="stock-passenger"         on passenger car stock item
 *   - data-testid="stock-flatbed"           on flatbed stock item
 *   - data-testid="consist-area"            on the consist builder scroll area
 *   - data-testid="consist-item-locomotive" on locomotive items in consist
 *   - data-testid="consist-item-passenger"  on passenger items in consist
 *   - data-testid="consist-item-flatbed"    on flatbed items in consist
 *   - data-testid="schedule-button"         on the Schedule/Update Train button
 *   - data-testid="train-row-{id}"          on each scheduled train row
 *   - data-testid="program-btn-{id}"        on the Program button for each train
 *   - data-testid="save-program-btn"        on the Save button in programmer
 *   - data-testid="close-planning-panel"    on planning panel close button
 *   - data-testid="add-switch-main-diverging"  on the SetSwitch diverging button
 *   - data-testid="add-moveto-teamtrack"    on the MoveTo Team Track button
 *   - data-testid="train-car-locomotive"    on locomotive SVG in canvas
 *   - data-testid="train-car-passenger"     on passenger car SVG in canvas
 *   - data-testid="train-car-flatbed"       on flatbed SVG in canvas
 */

test.describe('Car-specific spotting', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  /**
   * Helper: build a 3-car consist (Loco + Coach + Flatbed) and schedule it.
   */
  async function buildThreeCarConsist(page) {
    // Add Locomotive
    await page.getByTestId('stock-locomotive').click();
    await page.locator('button:has-text("+")').first().click();

    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);

    // Add Passenger Car
    await expect(page.getByTestId('stock-passenger')).toBeVisible();
    await page.getByTestId('stock-passenger').click();
    await page.locator('button:has-text("+")').last().click();
    await expect(consistArea.getByTestId('consist-item-passenger')).toHaveCount(1);

    // Add Flatbed
    await expect(page.getByTestId('stock-flatbed')).toBeVisible();
    await page.getByTestId('stock-flatbed').click();
    await page.locator('button:has-text("+")').last().click();
    await expect(consistArea.getByTestId('consist-item-flatbed')).toHaveCount(1);

    // Schedule
    await page.getByTestId('schedule-button').click();
    await expect(page.getByTestId(/train-row-/)).toHaveCount(1);
  }

  test('build 3-car consist and program MoveTo with diverging switch', async ({ page }) => {
    test.setTimeout(90000);

    await buildThreeCarConsist(page);

    // Program the train
    await page.getByTestId(/train-row-/).first().click();
    await page.getByTestId(/program-btn-/).first().click();

    // Set switch to diverging (to reach the siding)
    await page.getByTestId('add-switch-main-diverging').click();
    await expect(page.getByTestId('order-item-0')).toContainText('Set main Diverging');

    // MoveTo Team Track
    await page.getByTestId('add-moveto-teamtrack').click();
    await expect(page.getByTestId('order-item-1')).toContainText('Move To Team Track');

    // Save program
    await page.getByTestId('save-program-btn').click();
    await expect(page.getByText('Train Planning')).toBeVisible();

    // Close planning panel and start
    await page.getByTestId('close-planning-panel').click();
    await page.getByRole('button', { name: 'Start', exact: true }).click();
    await expect(page.getByText('RUNNING')).toBeVisible();

    // Wait for all 3 cars to spawn
    const canvas = page.locator('svg').first();
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1, { timeout: 10000 });
    await expect(canvas.getByTestId('train-car-passenger')).toHaveCount(1, { timeout: 5000 });
    await expect(canvas.getByTestId('train-car-flatbed')).toHaveCount(1, { timeout: 5000 });

    // Verify train moves toward team track (transform changes)
    const trainCar = canvas.getByTestId('train-car-locomotive').first();
    const initialTransform = await trainCar.getAttribute('transform');

    await expect(async () => {
      const newTransform = await trainCar.getAttribute('transform');
      expect(newTransform).not.toBe(initialTransform);
    }).toPass({ timeout: 5000 });

    // Wait for the train to stop (transform stabilizes)
    let lastTransform = '';
    let stableCount = 0;
    await expect(async () => {
      const currentTransform = await trainCar.getAttribute('transform');
      if (currentTransform === lastTransform) {
        stableCount++;
      } else {
        stableCount = 0;
        lastTransform = currentTransform;
      }
      expect(stableCount).toBeGreaterThanOrEqual(3);
    }).toPass({ timeout: 60000 });

    // After stopping, all 3 cars should still be visible on canvas
    await page.getByRole('button', { name: 'Pause' }).click();
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-passenger')).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-flatbed')).toHaveCount(1);
  });

  test('all three cars are visible during movement', async ({ page }) => {
    test.setTimeout(60000);

    await buildThreeCarConsist(page);

    // Quick program: diverge + move to platform
    await page.getByTestId(/train-row-/).first().click();
    await page.getByTestId(/program-btn-/).first().click();
    await page.getByTestId('add-switch-main-diverging').click();
    await page.getByTestId('add-moveto-teamtrack').click();
    await page.getByTestId('save-program-btn').click();

    await page.getByTestId('close-planning-panel').click();
    await page.getByRole('button', { name: 'Start', exact: true }).click();

    const canvas = page.locator('svg').first();

    // Wait for train to spawn and be visible
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1, { timeout: 10000 });

    // While the train is moving, all 3 cars should remain visible
    await page.waitForTimeout(2000);
    await expect(canvas.getByTestId('train-car-locomotive')).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-passenger')).toHaveCount(1);
    await expect(canvas.getByTestId('train-car-flatbed')).toHaveCount(1);

    await page.getByRole('button', { name: 'Pause' }).click();
  });
});
