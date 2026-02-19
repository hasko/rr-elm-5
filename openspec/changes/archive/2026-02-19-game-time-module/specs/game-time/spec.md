## ADDED Requirements

### Requirement: GameTime type

`Util/GameTime.elm` SHALL provide a transparent type alias `GameTime = Float` representing seconds since Monday 00:00, with constructor and decomposition functions.

#### Scenario: Construction from day, hour, minute

- **WHEN** `fromDayHourMinute 0 6 30` is called
- **THEN** it returns `23400.0` (0×86400 + 6×3600 + 30×60)

#### Scenario: Construction from hour and minute only

- **WHEN** `fromHourMinute 6 30` is called
- **THEN** it returns `23400.0` (6×3600 + 30×60)

#### Scenario: Decompose to day, hour, minute

- **WHEN** `toDayHourMinute 23400.0` is called
- **THEN** it returns `(0, 6, 30)`

#### Scenario: Decompose wraps at day boundaries

- **WHEN** `toDayHourMinute 90060.0` is called (1×86400 + 1×3600 + 1×60)
- **THEN** it returns `(1, 1, 1)`

### Requirement: GameTime formatting

`Util/GameTime.elm` SHALL provide formatting functions that convert a `GameTime` value to human-readable time strings with day names for the game week (Mon–Fri).

#### Scenario: Format as HH:MM

- **WHEN** `formatTime 23400.0` is called
- **THEN** it returns `"06:30"`

#### Scenario: Format with day name

- **WHEN** `formatDayTime 23400.0` is called
- **THEN** it returns `"Mon 06:30"`

#### Scenario: Day names for game week

- **WHEN** formatting times on days 0 through 4
- **THEN** day names are `"Mon"`, `"Tue"`, `"Wed"`, `"Thu"`, `"Fri"`

### Requirement: GameTime comparison

Because `GameTime` is a transparent `Float` alias, standard comparison operators SHALL work directly without wrapper functions.

#### Scenario: Direct Float comparison

- **WHEN** comparing two `GameTime` values
- **THEN** standard `>=`, `<=`, `compare` operators work because `GameTime` is a transparent `Float` alias

## REMOVED Requirements

### Requirement: DepartureTime type

The `DepartureTime` record type `{ day, hour, minute }` SHALL be removed from `Planning/Types.elm`. All usages replaced by `GameTime`.
