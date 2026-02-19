## Context

The codebase has two time representations: a structured `DepartureTime` record and a raw `Float` wrapped in a local `GameTime` alias. Conversion between them is duplicated and inconsistent.

## Goals / Non-Goals

**Goals:**
- Single time type used throughout the game logic
- Conversion and formatting logic centralized in one module
- Follow existing `Util/` module pattern

**Non-Goals:**
- Calendar dates, timezones, or real-world time handling
- Changing the simulation tick mechanism
- Opaque type enforcement (transparent alias is sufficient for now)

## Decisions

### Decision 1: Transparent type alias

`type alias GameTime = Float` — keeps things simple. Standard comparison operators work directly. Can be made opaque later if needed.

### Decision 2: Seconds since Monday 00:00

Internal representation is seconds from the start of the game week (Monday 00:00:00). This matches the existing `elapsedSeconds` convention in Main.elm where the sim starts at `6 * 60 * 60` (06:00 Monday).

### Decision 3: Module location

`Util/GameTime.elm` — follows the existing pattern of `Util/Vec2.elm` and `Util/Transform.elm` for foundational utility types.

### Decision 4: UI pickers stay as separate ints

The time picker UI continues to work with separate `timePickerDay`, `timePickerHour`, `timePickerMinute` ints in `PlanningState`. These are assembled into a `GameTime` via `fromDayHourMinute` at the point where a `ScheduledTrain` is created, and decomposed back via `toDayHourMinute` when editing. The pickers are pure UI state and don't need to store `GameTime`.

### Decision 5: Storage format

`GameTime` serializes as a plain JSON float. This is a breaking change to the save format for `departureTime` (was `{ day, hour, minute }` object, becomes a number). Since this is pre-release, no migration needed.
