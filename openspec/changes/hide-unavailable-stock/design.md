## Context

The inventory panel in `Planning/View.elm` uses `groupAndCountStock` to enumerate stock types. This function hardcodes all 4 types (`Locomotive`, `PassengerCar`, `Flatbed`, `Boxcar`) and returns entries even when count is 0. The view then renders unavailable items at 40% opacity with a gray "0" badge.

This conflicts with the consist-builder E2E test (which expects only available types) and contradicts the design principle of not showing what can't be acted on.

## Goals / Non-Goals

**Goals:**
- Only display stock types with ≥1 item at the selected station
- Remove dead unavailable-item styling code
- Fix the failing consist-builder E2E test
- Remove the stock-display E2E tests that assert opposite behavior

**Non-Goals:**
- Changing how provisional stock works in the consist builder
- Redesigning the inventory panel layout
- Applying the "hide unavailable" principle to other UI areas (future work)

## Decisions

### 1. Filter in `groupAndCountStock` rather than in the view

Change `groupAndCountStock` to only return types that have ≥1 matching item in the inventory list, instead of filtering in `viewStockTypeItem`. This keeps the view simple — it renders whatever it receives.

Alternative: keep `groupAndCountStock` returning all types and filter with `List.filter` before rendering. Rejected because the grouping function is the natural place for this — no caller wants 0-count entries.

### 2. Remove unavailable styling rather than keeping it dormant

Delete the `isUnavailable` branch, opacity dimming, and gray badge color from `viewStockTypeItem`. Dead code that serves no purpose adds confusion for future readers.

Alternative: leave the styling in case we want it later. Rejected — easy to re-add if needed, and dead code decays.

## Risks / Trade-offs

- **Player loses visibility of what exists elsewhere** → Acceptable. The player can switch stations to see what's there. The consist builder is for building with what you have, not browsing the catalog.
- **Tests removed, not replaced** → The stock-display tests tested the wrong behavior. The consist-builder test already covers the correct behavior (station shows only its available types).
