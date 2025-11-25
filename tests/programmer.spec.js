import { test, expect } from '@playwright/test';

test.describe('Train Programmer', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for the planning panel to be visible
    await expect(page.getByText('Train Planning')).toBeVisible();

    // Create a train first so we can program it
    // Select locomotive
    const locomotiveStock = page.locator('div[style*="cursor: pointer"]').filter({ has: page.locator('rect[fill="#4a6a8a"]') }).first();
    await locomotiveStock.click();
    await page.locator('button:has-text("+")').first().click();

    // Schedule the train
    const scheduleButton = page.getByTestId('schedule-button');
    await scheduleButton.click();

    // Wait for train to appear in list
    await expect(page.getByTestId(/train-row-/)).toBeVisible();
  });

  test('Scenario 1: Program button appears when train is selected for editing', async ({ page }) => {
    // Click on the scheduled train to select it for editing
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();

    // Wait for button text to change to "Update Train" (confirms editing mode)
    const scheduleButton = page.getByTestId('schedule-button');
    await expect(scheduleButton).toHaveText('Update Train');

    // Verify Program button appears in schedule controls area
    const programButton = page.getByTestId(/program-btn-/);
    await expect(programButton).toBeVisible();
    await expect(programButton).toHaveText('Program');
  });

  test('Scenario 2: Program button not visible when no train is being edited', async ({ page }) => {
    // Without selecting a train to edit, Program button should not be visible
    const programButton = page.getByTestId(/program-btn-/);
    await expect(programButton).toHaveCount(0);
  });

  test('Scenario 3: Clicking Program opens programmer panel', async ({ page }) => {
    // Select train to edit
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();

    // Click Program button
    const programButton = page.getByTestId(/program-btn-/).first();
    await programButton.click();

    // Verify programmer panel is visible
    await expect(page.getByText(/Train #\d+ Program/)).toBeVisible();
    await expect(page.getByText('← Back')).toBeVisible();
    await expect(page.getByText('PROGRAM', { exact: true })).toBeVisible();
    await expect(page.getByText('ADD ORDER', { exact: true })).toBeVisible();
  });

  test('Scenario 4: Empty program shows hint text', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Verify empty state message
    await expect(page.getByText('No orders yet. Add orders below.')).toBeVisible();
  });

  test('Scenario 5: Add MoveTo order', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Click MoveTo Platform button
    await page.getByTestId('add-moveto-platform').click();

    // Verify order appears in list
    const orderItem = page.getByTestId('order-item-0');
    await expect(orderItem).toBeVisible();
    await expect(orderItem).toContainText('Move To Platform');
  });

  test('Scenario 6: Add SetReverser order', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add SetReverser Forward
    await page.getByTestId('add-reverser-forward').click();

    // Verify order appears
    const orderItem = page.getByTestId('order-item-0');
    await expect(orderItem).toContainText('Set Reverser Forward');

    // Add SetReverser Reverse
    await page.getByTestId('add-reverser-reverse').click();

    // Verify second order
    const orderItem1 = page.getByTestId('order-item-1');
    await expect(orderItem1).toContainText('Set Reverser Reverse');
  });

  test('Scenario 7: Add SetSwitch orders', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add Switch Normal
    await page.getByTestId('add-switch-main-normal').click();
    await expect(page.getByTestId('order-item-0')).toContainText('Set main Normal');

    // Add Switch Diverging
    await page.getByTestId('add-switch-main-diverging').click();
    await expect(page.getByTestId('order-item-1')).toContainText('Set main Diverging');
  });

  test('Scenario 8: Add WaitSeconds orders', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add different wait times
    await page.getByTestId('add-wait-10').click();
    await expect(page.getByTestId('order-item-0')).toContainText('Wait 10 seconds');

    await page.getByTestId('add-wait-30').click();
    await expect(page.getByTestId('order-item-1')).toContainText('Wait 30 seconds');

    await page.getByTestId('add-wait-60').click();
    await expect(page.getByTestId('order-item-2')).toContainText('Wait 60 seconds');
  });

  test('Scenario 9: Remove order with X button', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add two orders
    await page.getByTestId('add-reverser-forward').click();
    await page.getByTestId('add-moveto-platform').click();

    // Verify both orders
    await expect(page.getByTestId('order-item-0')).toBeVisible();
    await expect(page.getByTestId('order-item-1')).toBeVisible();

    // Remove first order
    await page.getByTestId('order-item-0').locator('button:has-text("X")').click();

    // Verify only MoveTo remains (now at index 0)
    await expect(page.getByTestId('order-item-0')).toContainText('Move To Platform');
    await expect(page.getByTestId('order-item-1')).toHaveCount(0);
  });

  test('Scenario 10: Move order up', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add two orders
    await page.getByTestId('add-reverser-forward').click();
    await page.getByTestId('add-moveto-platform').click();

    // Verify initial order
    await expect(page.getByTestId('order-item-0')).toContainText('Set Reverser Forward');
    await expect(page.getByTestId('order-item-1')).toContainText('Move To Platform');

    // Move second order up
    await page.getByTestId('order-item-1').locator('button:has-text("↑")').click();

    // Verify new order
    await expect(page.getByTestId('order-item-0')).toContainText('Move To Platform');
    await expect(page.getByTestId('order-item-1')).toContainText('Set Reverser Forward');
  });

  test('Scenario 11: Move order down', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add two orders
    await page.getByTestId('add-reverser-forward').click();
    await page.getByTestId('add-moveto-platform').click();

    // Move first order down
    await page.getByTestId('order-item-0').locator('button:has-text("↓")').click();

    // Verify new order
    await expect(page.getByTestId('order-item-0')).toContainText('Move To Platform');
    await expect(page.getByTestId('order-item-1')).toContainText('Set Reverser Forward');
  });

  test('Scenario 12: Up button disabled for first item', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add order
    await page.getByTestId('add-reverser-forward').click();

    // Verify up button is disabled
    const upButton = page.getByTestId('order-item-0').locator('button:has-text("↑")');
    await expect(upButton).toBeDisabled();
  });

  test('Scenario 13: Down button disabled for last item', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add order
    await page.getByTestId('add-reverser-forward').click();

    // Verify down button is disabled
    const downButton = page.getByTestId('order-item-0').locator('button:has-text("↓")');
    await expect(downButton).toBeDisabled();
  });

  test('Scenario 14: Back button returns to planning view without saving', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add an order
    await page.getByTestId('add-reverser-forward').click();
    await expect(page.getByTestId('order-item-0')).toBeVisible();

    // Click back
    await page.getByRole('button', { name: '← Back' }).click();

    // Verify we're back to planning view (still in editing mode)
    await expect(page.getByText('Train Planning')).toBeVisible();
    await expect(page.getByTestId('schedule-button')).toHaveText('Update Train');

    // Re-open programmer (still editing same train, just click Program again)
    await page.getByTestId(/program-btn-/).first().click();

    // Should be empty again (order was not saved)
    await expect(page.getByText('No orders yet. Add orders below.')).toBeVisible();
  });

  test('Scenario 15: Save button saves program and returns to planning view', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Add orders
    await page.getByTestId('add-reverser-forward').click();
    await page.getByTestId('add-moveto-platform').click();

    // Click Save
    await page.getByTestId('save-program-btn').click();

    // Verify we're back to planning view
    await expect(page.getByText('Train Planning')).toBeVisible();

    // Re-open programmer and verify orders are saved
    const newTrainRow = page.getByTestId(/train-row-/).first();
    await newTrainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Orders should be present
    await expect(page.getByTestId('order-item-0')).toContainText('Set Reverser Forward');
    await expect(page.getByTestId('order-item-1')).toContainText('Move To Platform');
  });

  test('Complete workflow: Build a full program', async ({ page }) => {
    // Open programmer
    const trainRow = page.getByTestId(/train-row-/).first();
    await trainRow.click();
    await page.getByTestId(/program-btn-/).first().click();

    // Build a realistic switching program
    // 1. Set switch to diverging
    await page.getByTestId('add-switch-main-diverging').click();

    // 2. Set reverser to reverse
    await page.getByTestId('add-reverser-reverse').click();

    // 3. Move to platform
    await page.getByTestId('add-moveto-platform').click();

    // 4. Wait 60 seconds
    await page.getByTestId('add-wait-60').click();

    // 5. Set reverser forward
    await page.getByTestId('add-reverser-forward').click();

    // 6. Move to East Tunnel
    await page.getByTestId('add-moveto-easttunnel').click();

    // 7. Set switch back to normal
    await page.getByTestId('add-switch-main-normal').click();

    // Verify all 7 orders
    for (let i = 0; i < 7; i++) {
      await expect(page.getByTestId(`order-item-${i}`)).toBeVisible();
    }

    // Verify order descriptions
    await expect(page.getByTestId('order-item-0')).toContainText('Set main Diverging');
    await expect(page.getByTestId('order-item-1')).toContainText('Set Reverser Reverse');
    await expect(page.getByTestId('order-item-2')).toContainText('Move To Platform');
    await expect(page.getByTestId('order-item-3')).toContainText('Wait 60 seconds');
    await expect(page.getByTestId('order-item-4')).toContainText('Set Reverser Forward');
    await expect(page.getByTestId('order-item-5')).toContainText('Move To East Tunnel');
    await expect(page.getByTestId('order-item-6')).toContainText('Set main Normal');

    // Save and verify persistence
    await page.getByTestId('save-program-btn').click();
    await expect(page.getByText('Train Planning')).toBeVisible();

    // Re-open and verify all orders persisted
    await page.getByTestId(/train-row-/).first().click();
    await page.getByTestId(/program-btn-/).first().click();

    await expect(page.getByTestId('order-item-6')).toContainText('Set main Normal');
  });
});
