## 1. Change groupAndCountStock to filter out 0-count types

- [x] 1.1 Update `groupAndCountStock` in `src/Planning/View.elm` to only return types with ≥1 item (remove the hardcoded `allStockTypes` list, instead derive types from actual inventory items)
- [x] 1.2 Remove `isUnavailable` logic and unavailable styling (opacity 0.4, gray badge) from `viewStockTypeItem`
- [x] 1.3 Verify Elm compiles and run `npx elm-test`

## 2. Update tests

- [x] 2.1 Remove `tests/StockDisplayTest.elm` (tests the opposite behavior — "all types always visible")
- [x] 2.2 Remove `tests/stock-display.spec.js` (E2E tests for unavailable stock display)
- [x] 2.3 Run full test suite: `npx elm-test` and `npx playwright test` — consist-builder Scenario 10 now passes. Also fixed SpawnPointId/label mismatch in viewSpawnPointSelector (swapped IDs to match display names), which fixed the Complete workflow test too.
