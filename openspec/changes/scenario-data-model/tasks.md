## 1. Baseline

- [x] 1.1 Run `npx elm-test` and `npx playwright test` to record the baseline pass/fail state before any changes

## 2. Scenario types and JSON decoders

- [x] 2.1 Create `src/Scenario.elm` with `Scenario` record type and all sub-types: `TrackNode`, `TrackEdge`, `Spot`, `Station`, `StockEntry`, `Goal`, and `NodeType`/`EdgeType` unions — all using string IDs
- [x] 2.2 Write JSON decoders in `src/Scenario.elm` for all types: nodes (portal/turnout/buffer), edges (straight/curve with optional port and spots), stations (with stock), and goals (with optional `from`)
- [x] 2.3 Create `public/scenarios/sawmill.json` with the sawmill scenario data: 4 nodes, 3 edges, 2 stations with stock (East: 1 loco + 2 coaches, West: 1 loco + 1 flatbed + 1 coach), 2 spots, 4 goals, metadata (name "Morning Run", startTime "06:00", endTime "07:00")
- [x] 2.4 Write `tests/ScenarioTest.elm` with Elm tests for every decoder: portal node, turnout node, unknown node type rejection, straight edge, curve edge, edge with spots, edge with port, station with stock, directional goal, non-directional goal, and full sawmill scenario decode

## 3. Test decoders

- [x] 3.1 Run `npx elm-test` — new decoder tests pass, existing tests unaffected
- [x] 3.2 Fix any compilation or test failures introduced in phase 2

## 4. Track layout engine

- [x] 4.1 Create `src/Scenario/Layout.elm` with graph walker: depth-first traversal from anchor portal at (0,0) orientation 0, producing a `Track.Layout` and element-to-node-id mapping
- [x] 4.2 Implement straight edge → `StraightTrack`, curve edge → `CurvedTrack`, turnout node → `Turnout` element, portal/buffer node → `TrackEnd` element conversion
- [x] 4.3 Implement merge point validation: when the walker revisits a node, check position agreement within 0.001 units (1mm tolerance)
- [x] 4.4 Implement spot position computation: place spots at their `at` distance along the parent edge's track element
- [x] 4.5 Extract initial turnout states from turnout nodes (`initialState` field) into a `Dict String SwitchState`
- [x] 4.6 Write `tests/ScenarioLayoutTest.elm` with tests: sawmill graph produces correct element count and types, spot positions are correct, turnout initial state extraction, merge point validation (pass and fail cases)

## 5. Test layout engine

- [x] 5.1 Run `npx elm-test` — layout tests pass, existing tests unaffected
- [x] 5.2 Fix any compilation or test failures introduced in phase 4

## 6. Two-phase init and scenario threading

- [ ] 6.1 Add `AppState` type (`Loading | LoadFailed String | Ready Model`) to `Main.elm`, change `init` to fire `Http.get` for the scenario JSON, change `update`/`view`/`subscriptions` to dispatch on `AppState`
- [ ] 6.2 Add `scenario : Scenario` field to `Model`, make `defaultModel` a function of `Scenario`
- [ ] 6.3 Build `Track.Layout` from scenario graph (using `Scenario/Layout.elm`) instead of `Sawmill.Layout.trackLayout`
- [ ] 6.4 Initialize `turnoutStates : Dict String SwitchState` from scenario data, replacing the single `turnoutState : SwitchState` field in `SimState` and `Model`
- [ ] 6.5 Add loading screen view and load-failed error view

## 7. Test two-phase init

- [ ] 7.1 Run `npx elm-test` and `npx playwright test` — identify regressions from phase 6
- [ ] 7.2 Fix all compilation errors and test failures from the init/model restructuring

## 8. Planning UI from scenario data

- [ ] 8.1 Replace `SpawnPointId` enum usage with string station ids from scenario — station selector buttons generated from `scenario.stations`, labels from station `name` field
- [ ] 8.2 Replace `initPlanningState` hardcoded inventories with stock derived from scenario station data
- [ ] 8.3 Replace hardcoded spot names in `Programmer/Types.elm` with spot data from scenario
- [ ] 8.4 Replace `destinationLabel` function in consist builder with a departure direction arrow indicating which end is the front — no station name

## 9. Test planning UI

- [ ] 9.1 Run `npx elm-test` and `npx playwright test` — identify regressions from phase 8
- [ ] 9.2 Fix all test failures from planning UI changes, update E2E selectors if needed

## 10. Simulation from scenario data

- [ ] 10.1 Replace hardcoded exit point detection (`ElementId 1` → EastStation, etc.) in `Simulation.elm` with portal-to-station lookup from scenario data and element-to-node mapping
- [ ] 10.2 Update route building in `Train/Route.elm` to use scenario graph data instead of hardcoded `ElementId` references
- [ ] 10.3 Update all turnout-related code (simulation tick, programmer orders, switch commands) to use `Dict String SwitchState` keyed by turnout node id
- [ ] 10.4 Update portal click handlers in `Main.elm` to use scenario station-to-portal mapping instead of hardcoded `ElementId` pattern matching

## 11. Test simulation

- [ ] 11.1 Run `npx elm-test` and `npx playwright test` — identify regressions from phase 10
- [ ] 11.2 Fix all test failures from simulation changes

## 12. Goal system

- [ ] 12.1 Add visit log (`List VisitEvent`) to simulation state, record visits when cars arrive at spots or exit through portals
- [ ] 12.2 Implement goal verification: match each goal against the visit log at scenario end, handling directional (with `from`) and non-directional goals, with distinct-visit counting for duplicate goals
- [ ] 12.3 Add goal display UI: show all goals with flavor text and pending/satisfied status, update live during simulation
- [ ] 12.4 Write `tests/GoalTest.elm` with tests: directional goal satisfied, directional goal wrong origin, non-directional goal satisfied, wrong stock type, count matching (2 goals need 2 visits)

## 13. Test goals

- [ ] 13.1 Run `npx elm-test` and `npx playwright test` — goal tests pass, no regressions
- [ ] 13.2 Fix any test failures from goal system integration

## 14. Stock visuals and scenario metadata

- [ ] 14.1 Create stock type visual lookup module: hardcoded Elm table mapping well-known type strings ("locomotive", "coach", "flatbed", etc.) to SVG side-profiles and on-map car appearances, with a generic fallback for unknown types
- [ ] 14.2 Update portal labels on the map to display the linked station's `name` from scenario data
- [ ] 14.3 Display scenario name and game time range (startTime–endTime) from scenario metadata

## 15. Test visuals and metadata

- [ ] 15.1 Run `npx elm-test` and `npx playwright test` — no regressions
- [ ] 15.2 Fix any test failures

## 16. Cleanup

- [ ] 16.1 Delete `src/Sawmill/Layout.elm` — all layout data now comes from the scenario JSON
- [ ] 16.2 Remove `SpawnPointId` enum from `Planning/Types.elm` and all remaining references
- [ ] 16.3 Remove hardcoded `ElementId` pattern matching from `Simulation.elm`, `Train/Route.elm`, and `Main.elm`
- [ ] 16.4 Remove any dead code: unused imports, orphaned helper functions, old tunnel portal label logic

## 17. Final verification

- [ ] 17.1 Run `npx elm-test` — all Elm tests pass
- [ ] 17.2 Run `npx playwright test` — all E2E tests pass (at least as good as baseline from 1.1)
- [ ] 17.3 Manual smoke test: load sawmill scenario, build consist, run simulation, verify spots and goals work
