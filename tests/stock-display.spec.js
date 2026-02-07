import { test, expect } from '@playwright/test';

/**
 * Unavailable stock display E2E tests.
 *
 * Tests that all stock types appear in the inventory panel, including
 * those with 0 available count. Unavailable items should have a visual
 * indicator (dashed outline).
 *
 * Required data-testid attributes:
 *   - data-testid="stock-locomotive"    on locomotive stock item
 *   - data-testid="stock-passenger"     on passenger car stock item
 *   - data-testid="stock-flatbed"       on flatbed stock item
 *   - data-testid="stock-boxcar"        on boxcar stock item
 */

test.describe('Unavailable stock display', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
    await expect(page.getByText('Train Planning')).toBeVisible();
  });

  // ---------------------------------------------------------------------------
  // All stock types visible in inventory
  // ---------------------------------------------------------------------------
  test.describe('All stock types visible in inventory', () => {
    test('East Station shows Locomotive, Passenger Car, and Flatbed (available)', async ({ page }) => {
      // East Station is selected by default
      await expect(page.getByTestId('stock-locomotive')).toBeVisible();
      await expect(page.getByTestId('stock-passenger')).toBeVisible();
      await expect(page.getByTestId('stock-flatbed')).toBeVisible();
    });

    test('East Station shows Boxcar with 0 count (unavailable)', async ({ page }) => {
      // East Station has no boxcars, but the type should still appear
      // with a 0 count or visual indicator that it's unavailable
      const boxcar = page.getByTestId('stock-boxcar');
      await expect(boxcar).toBeVisible();

      // Verify the count shows 0 (look for text "0" within the boxcar element)
      await expect(boxcar).toContainText('0');
    });

    test('West Station shows all 4 stock types', async ({ page }) => {
      // Switch to West Station
      await page.getByRole('button', { name: 'West Station' }).click();

      // All types should be visible
      await expect(page.getByTestId('stock-locomotive')).toBeVisible();
      await expect(page.getByTestId('stock-passenger')).toBeVisible();
      await expect(page.getByTestId('stock-flatbed')).toBeVisible();
      await expect(page.getByTestId('stock-boxcar')).toBeVisible();
    });

    test('West Station shows PassengerCar and Flatbed with 0 count', async ({ page }) => {
      await page.getByRole('button', { name: 'West Station' }).click();

      const passenger = page.getByTestId('stock-passenger');
      await expect(passenger).toBeVisible();
      await expect(passenger).toContainText('0');

      const flatbed = page.getByTestId('stock-flatbed');
      await expect(flatbed).toBeVisible();
      await expect(flatbed).toContainText('0');
    });
  });

  // ---------------------------------------------------------------------------
  // Dashed outline on unavailable/provisional items
  // ---------------------------------------------------------------------------
  test.describe('Visual indicator for unavailable stock', () => {
    test('unavailable stock has dashed border style', async ({ page }) => {
      // East Station boxcar should have a dashed outline
      const boxcar = page.getByTestId('stock-boxcar');
      await expect(boxcar).toBeVisible();

      // Check for dashed border (the implementation should use border-style: dashed)
      await expect(boxcar).toHaveCSS('border-style', 'dashed');
    });

    test('available stock does NOT have dashed border', async ({ page }) => {
      // Locomotive is available at East Station, should NOT be dashed
      const loco = page.getByTestId('stock-locomotive');
      await expect(loco).toBeVisible();

      // Available stock should have solid (or none) border, not dashed
      const borderStyle = await loco.evaluate((el) => {
        return window.getComputedStyle(el).borderStyle;
      });
      expect(borderStyle).not.toBe('dashed');
    });
  });

  // ---------------------------------------------------------------------------
  // Consuming stock and count updates
  // ---------------------------------------------------------------------------
  test.describe('Stock count updates when items are consumed', () => {
    test('consuming the only locomotive shows it with 0 count', async ({ page }) => {
      // East Station has 1 locomotive
      const loco = page.getByTestId('stock-locomotive');
      await expect(loco).toBeVisible();

      // Add locomotive to consist (consumes it from inventory)
      await loco.click();
      await page.locator('button:has-text("+")').first().click();

      // Locomotive should still be visible in inventory but with count 0
      await expect(loco).toBeVisible();
      await expect(loco).toContainText('0');
    });
  });
});
