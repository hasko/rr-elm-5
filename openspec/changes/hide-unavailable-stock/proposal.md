## Why

Screen real estate is limited and player cognitive bandwidth is even more so. The UI currently shows all stock types at every station, including those with 0 available count (dimmed at 40% opacity). This clutters the inventory panel with items the player can't use, adding visual noise without value.

Principle: **don't show what is unavailable.** If a stock type has no items at a station, it shouldn't appear in the inventory. This principle applies broadly — not just to the stock picker, but anywhere the UI presents options that aren't actionable.

## What Changes

- Only show stock types that have ≥1 item available at the selected station
- Remove the "show all types with 0-count" logic from inventory rendering
- Remove the unavailable styling (opacity dimming, gray badge) that becomes unnecessary
- Update the E2E test that expects only 2 stock types at West Station (currently failing because all 4 are shown)
- Remove the stock-display E2E tests that test for unavailable stock visibility and dashed borders (these test the opposite of the desired behavior)

## Capabilities

### New Capabilities

_(none — this simplifies existing behavior rather than adding new capability)_

### Modified Capabilities

_(no existing specs affected)_

## Impact

- `src/Planning/View.elm` — `groupAndCountStock` function and `viewStockTypeItem` styling
- `tests/consist-builder.spec.js` — Scenario 10 should pass after fix
- `tests/stock-display.spec.js` — Tests for unavailable stock display should be removed
- `tests/StockDisplayTest.elm` — Elm unit tests for unavailable stock rendering may need updating
