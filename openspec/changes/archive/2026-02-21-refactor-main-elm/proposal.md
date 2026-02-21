## Why

Main.elm is 2024 lines handling everything from camera panning to consist scheduling to the simulation loop. As features are added (couple/uncouple, multi-day scheduling, win/lose conditions), this file will only grow. Breaking it into focused modules now makes each piece easier to understand, test, and extend independently.

## What Changes

- Extract consist builder and train scheduling update logic into `Planning.Update` (completing the Planning module family alongside existing `Planning.Types` and `Planning.View`)
- Extract order manipulation and program save logic into `Programmer.Update` (completing the Programmer module family alongside existing `Programmer.Types` and `Programmer.View`)
- Extract camera types and pan/zoom update logic into `Camera.elm`
- Extract the simulation tick handler (time advance, spawn, execute, move, despawn, route rebuild) into `Simulation.elm`
- Main.elm retains: Model/Msg types, init, update (delegating to extracted modules), subscriptions, top-level view routing

This is a pure structural refactor. No behavior changes, no API changes, no new features.

## Capabilities

### New Capabilities

None. This change reorganizes existing code without introducing new capabilities.

### Modified Capabilities

None. No requirement-level behavior changes.

## Impact

- `src/Main.elm` — shrinks from ~2024 lines to ~600-700 lines
- `src/Planning/Update.elm` — new file (~275 lines)
- `src/Programmer/Update.elm` — new file (~210 lines)
- `src/Camera.elm` — new file (~135 lines)
- `src/Simulation.elm` — new file (~120 lines)
- All existing Elm unit tests and Playwright E2E tests should pass unchanged
- No changes to HTML structure, `data-testid` attributes, or user-facing behavior
