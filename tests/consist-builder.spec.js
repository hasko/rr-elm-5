import { test, expect } from '@playwright/test';

test.describe('Train Planning - Consist Builder', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for the planning panel to be visible (app starts in Planning mode)
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  test('Scenario 1: Initial state shows single + button and disabled schedule button', async ({ page }) => {
    // Verify single + button is visible (when consist is empty, only one + button shows)
    const addButtons = page.locator('button:has-text("+")');
    await expect(addButtons).toHaveCount(1);

    // Verify schedule button is disabled
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toBeDisabled();

    // Verify hint text is shown
    await expect(page.getByText('Add stock to consist first')).toBeVisible();
  });

  test('Scenario 2: Select stock makes + buttons highlighted', async ({ page }) => {
    // Click on a locomotive to select it (click on the clickable div wrapper)
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();

    // Verify selection indicator appears
    await expect(page.locator('text=/Selected: Locomotive/')).toBeVisible();

    // Verify add button has highlighted border color (blue border when enabled)
    const addButton = page.locator('button:has-text("+")').first();
    await expect(addButton).toHaveCSS('border-color', /rgb\(74, 158, 255\)/);
  });

  test('Scenario 3: Add locomotive to consist shows [+] [loco] [+] pattern', async ({ page }) => {
    // Select locomotive
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();

    // Click + button to add
    const addButton = page.locator('button:has-text("+")').first();
    await addButton.click();

    // Should now have 2 + buttons (one at front, one at back)
    const addButtons = page.locator('button:has-text("+")');
    await expect(addButtons).toHaveCount(2);

    // Verify locomotive item appears in consist by checking for locomotive icon in the dark background area
    // The consist builder has a dark background (#151520) where items are displayed
    await expect(page.getByTestId('consist-area').getByTestId('consist-item-locomotive')).toHaveCount(1);
  });

  test('Scenario 4: Schedule button enabled when locomotive is in consist', async ({ page }) => {
    // Add locomotive
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Verify schedule button is now enabled
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toBeEnabled();
    await expect(scheduleButton).toHaveCSS('background-color', /rgb\(74, 158, 255\)/);
  });

  test('Scenario 5: Add cars to consist using front and back buttons', async ({ page }) => {
    // Note: East station has 1 loco, 1 passenger car, 1 flatbed
    // We'll build a train with all three to test front/back adding

    // Add locomotive first (middle position)
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Now we have [+] [loco] [+]
    const addButtons = page.locator('button:has-text("+")');
    await expect(addButtons).toHaveCount(2);

    // Add flatbed to back
    const flatbedStock = page.getByTestId('stock-flatbed');
    await flatbedStock.click();
    await addButtons.last().click();

    // Now we have [+] [loco] [flatbed] [+] - verify
    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    await expect(consistArea.getByTestId('consist-item-flatbed')).toHaveCount(1);

    // Add passenger car to front
    const passengerCarStock = page.getByTestId('stock-passenger');
    await passengerCarStock.click();
    await addButtons.first().click();

    // Now we should have 3 items: [+] [passenger] [loco] [flatbed] [+]
    await expect(consistArea.getByTestId('consist-item-passenger')).toHaveCount(1);
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    await expect(consistArea.getByTestId('consist-item-flatbed')).toHaveCount(1);
  });

  test('Scenario 6: Remove item with X button compacts consist', async ({ page }) => {
    // Build a consist: loco + flatbed
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    const flatbedStock = page.getByTestId('stock-flatbed');
    await flatbedStock.click();
    await page.locator('button:has-text("+")').last().click();

    // Verify 2 items in consist (should have both loco and flatbed icons in consist builder)
    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    await expect(consistArea.getByTestId('consist-item-flatbed')).toHaveCount(1);

    // Click X button on first consist item (small circular button with position: absolute)
    const xButton = consistArea.locator('button[style*="position: absolute"]').first();
    await xButton.click();

    // Should now have only 1 item - poll until removal completes
    await expect(async () => {
      const locoCount = await consistArea.getByTestId('consist-item-locomotive').count();
      const flatbedCount = await consistArea.getByTestId('consist-item-flatbed').count();
      expect(locoCount + flatbedCount).toBe(1);
    }).toPass({ timeout: 2000 });
  });

  test('Scenario 7: Schedule train adds it to scheduled trains list', async ({ page }) => {
    // Build a consist with locomotive
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Click schedule button
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toHaveText('Schedule Train');
    await scheduleButton.click();

    // Verify train appears in scheduled trains list
    const trainRow = page.getByTestId(/train-row-/);
    await expect(trainRow).toHaveCount(1);

    // Verify consist builder is cleared
    const consistItems = page.locator('div[style*="position: relative"] div[style*="width: 60px"]').filter({ has: page.locator('svg') });
    await expect(consistItems).toHaveCount(0);

    // Verify schedule button is disabled again
    await expect(scheduleButton).toBeDisabled();
  });

  test('Scenario 8: Click scheduled train to edit changes button to Update Train', async ({ page }) => {
    // Schedule a train first
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    const scheduleButton = page.getByTestId('schedule-button');
    await scheduleButton.click();

    // Wait for train to appear in list
    const trainRow = page.getByTestId(/train-row-/).first();
    await expect(trainRow).toBeVisible();

    // Click on the scheduled train
    await trainRow.click();

    // Verify button changes to "Update Train"
    await expect(scheduleButton).toHaveText('Update Train');
    await expect(scheduleButton).toBeEnabled();

    // Verify consist is loaded into builder (locomotive icon should be present)
    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);

    // Note: When editing, the train is temporarily removed from the list, so checking the border
    // on the train row wouldn't work. Instead, we verify the button text changed to "Update Train"
  });

  test('Scenario 9: Clear consist returns to initial state', async ({ page }) => {
    // Add locomotive
    const locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Click Clear button
    await page.getByRole('button', { name: 'Clear' }).click();

    // Verify consist is empty
    const addButtons = page.locator('button:has-text("+")');
    await expect(addButtons).toHaveCount(1);

    // Verify schedule button is disabled
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toBeDisabled();

    // Verify hint appears
    await expect(page.getByText('Add stock to consist first')).toBeVisible();
  });

  test('Scenario 10: Switch between East/West stations shows different inventory', async ({ page }) => {
    // Note initial station (should be East Station with locomotive, passenger car, flatbed)
    const eastButton = page.getByRole('button', { name: 'East Station' });
    await expect(eastButton).toHaveCSS('border-color', /rgb\(74, 158, 255\)/);

    // Count initial stock types - East has locomotive, passenger car, flatbed
    const eastStockItems = page.locator('[data-testid^="stock-"]');
    await expect(eastStockItems).toHaveCount(3);

    // Switch to West Station
    const westButton = page.getByRole('button', { name: 'West Station' });
    await westButton.click();
    await expect(westButton).toHaveCSS('border-color', /rgb\(74, 158, 255\)/);

    // Count West stock types - West has locomotive, boxcar (2x but shows as 1 type)
    await expect(page.locator('[data-testid^="stock-"]')).toHaveCount(2);

    // Verify boxcar is present (red color #8a4a4a)
    const boxcarStock = page.getByTestId('stock-boxcar');
    await expect(boxcarStock).toHaveCount(1);
  });

  test('Complete workflow: Build, schedule, edit, and update train', async ({ page }) => {
    // Note: This test uses West station which has 2 boxcars we can use
    // Switch to West Station
    await page.getByRole('button', { name: 'West Station' }).click();

    // Step 1: Build initial consist with just locomotive
    let locomotiveStock = page.getByTestId('stock-locomotive');
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Step 2: Schedule the train
    let scheduleButton = page.getByTestId('schedule-button');
    await scheduleButton.click();

    // Step 3: Verify train is in list
    let trainRow = page.getByTestId(/train-row-/).first();
    await expect(trainRow).toBeVisible();
    await expect(trainRow).toContainText('1 loco');

    // Step 4: Edit the train
    await trainRow.click();
    await expect(scheduleButton).toHaveText('Update Train');

    // Step 5: Add first boxcar
    const boxcarStock = page.getByTestId('stock-boxcar').first();
    await boxcarStock.click();
    await page.locator('button:has-text("+")').last().click();

    // Step 6: Add second boxcar (West station has 2 boxcars)
    await page.locator('button:has-text("+")').last().click();

    // Step 7: Verify consist now has 3 items before updating (loco + 2 boxcars)
    const consistArea = page.getByTestId('consist-area');
    await expect(consistArea.getByTestId('consist-item-locomotive')).toHaveCount(1);
    await expect(consistArea.getByTestId('consist-item-boxcar')).toHaveCount(2);

    // Verify button is enabled and says "Update Train"
    await expect(scheduleButton).toBeEnabled();
    await expect(scheduleButton).toHaveText('Update Train');

    // Step 8: Update the train
    await scheduleButton.click();

    // Step 9: Verify consist builder is cleared (confirms update completed)
    const addButtons = page.locator('button:has-text("+")');
    await expect(addButtons).toHaveCount(1);

    // Step 10: Verify schedule button is disabled and back to "Schedule Train"
    await expect(scheduleButton).toBeDisabled();
    await expect(scheduleButton).toHaveText('Schedule Train');
  });
});
