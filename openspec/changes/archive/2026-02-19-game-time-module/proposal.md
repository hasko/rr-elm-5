## Why

Game time is represented inconsistently across the codebase. `DepartureTime` in `Planning/Types.elm` uses a `{ day, hour, minute }` record, while `Main.elm` has a local `GameTime` alias wrapping `{ elapsedSeconds : Float }`. Conversion between these is duplicated and broken — `Train/Spawn.elm` has a placeholder that only returns the minute field, while `Planning/View.elm` inline-computes the correct formula.

A unified, transparent `GameTime` type in `Util/GameTime.elm` will own construction, decomposition, formatting, and comparison — following the existing `Util/Vec2.elm` and `Util/Transform.elm` pattern.

## What Changes

- New `Util/GameTime.elm` module with a transparent `Float` type alias (seconds since Monday 00:00)
- `DepartureTime` type removed from `Planning/Types.elm` — the name lives on as variable names, not a type
- `Main.elm`'s local `GameTime` alias replaced by the shared module
- Spawn timing, train sorting, and time display all use `GameTime` helpers
- Serialization updated to encode/decode `GameTime` as a float

## Capabilities

### New Capabilities
- `game-time`: Unified game time type with construction, decomposition, and formatting

### Modified Capabilities
- Train scheduling uses `GameTime` instead of `DepartureTime` record
- Simulation clock uses shared `GameTime` module instead of local alias

## Impact

- `src/Util/GameTime.elm`: New module
- `src/Planning/Types.elm`: Remove `DepartureTime`, use `GameTime` in `ScheduledTrain`
- `src/Planning/View.elm`: Use `GameTime` formatting/sorting helpers
- `src/Main.elm`: Remove local `GameTime` alias, use `Util.GameTime`
- `src/Train/Spawn.elm`: Remove `departureTimeToSeconds`, compare `GameTime` values directly
- `src/Storage.elm`: Update encode/decode for `GameTime`
- `tests/`: New `GameTimeTest.elm`, update existing tests
